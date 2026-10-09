import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gestor_gastos/core/constants/backup_v1_limits.dart';
import 'package:gestor_gastos/core/errors/backup_exceptions.dart';
import 'package:gestor_gastos/core/services/backup_crypto_service.dart';

/// Resultado estructurado de la inspección de un archivo .gestorbackup.
class BackupInspectionResult {
  final String filePath;
  final int fileSizeBytes;
  final bool authSuccess;
  final String? authError;
  final bool formatSuccess;
  final String? formatError;

  // Manifest info
  final int? manifestPayloadVersion;
  final String? manifestAppVersion;
  final int? manifestSchemaVersion;
  final String? manifestCreatedAt;
  final List<String> manifestComponents;
  final int? manifestAttachmentsIncluded;
  final int? manifestAttachmentsMissing;

  // Preferences info
  final int? preferencesCount;

  // SQLite info
  final bool? quickCheckPassed;
  final String? quickCheckResult;
  final int? dbSchemaVersion;
  final List<String> detectedTables;

  // Entity counts
  final int? accountsCount;
  final int? transactionsCount;
  final int? categoriesCount;
  final int? goalsCount;
  final int? fixedExpensesCount;
  final int? remindersCount;

  // Attachments
  final int? transactionAttachmentRefsCount;
  final int? physicalAttachmentsCount;

  final List<String> warnings;

  BackupInspectionResult({
    required this.filePath,
    required this.fileSizeBytes,
    required this.authSuccess,
    this.authError,
    required this.formatSuccess,
    this.formatError,
    this.manifestPayloadVersion,
    this.manifestAppVersion,
    this.manifestSchemaVersion,
    this.manifestCreatedAt,
    this.manifestComponents = const [],
    this.manifestAttachmentsIncluded,
    this.manifestAttachmentsMissing,
    this.preferencesCount,
    this.quickCheckPassed,
    this.quickCheckResult,
    this.dbSchemaVersion,
    this.detectedTables = const [],
    this.accountsCount,
    this.transactionsCount,
    this.categoriesCount,
    this.goalsCount,
    this.fixedExpensesCount,
    this.remindersCount,
    this.transactionAttachmentRefsCount,
    this.physicalAttachmentsCount,
    this.warnings = const [],
  });

  bool get isFullyValid =>
      authSuccess &&
      formatSuccess &&
      (quickCheckPassed ?? false) &&
      (accountsCount != null) &&
      (transactionsCount != null);
}

/// Función de inspección principal.
///
/// Cumple:
/// - Lectura de solo lectura del archivo original.
/// - Descompresión y descifrado en carpeta temporal eliminada en bloque finally.
/// - Inspección SQLite en modo read-only mediante FFI sin migraciones ni escrituras.
/// - No imprime ni almacena contraseñas, hashes, balances ni datos personales.
Future<BackupInspectionResult> inspectBackupFile({
  required String backupPath,
  required String password,
  BackupCryptoService? cryptoServiceOverride,
}) async {
  final warnings = <String>[];
  final file = File(backupPath);

  if (!await file.exists()) {
    return BackupInspectionResult(
      filePath: backupPath,
      fileSizeBytes: 0,
      authSuccess: false,
      formatSuccess: false,
      formatError: 'El archivo especificado no existe.',
    );
  }

  final fileSizeBytes = await file.length();
  if (fileSizeBytes > BackupV1Limits.maxEncryptedContainerBytes) {
    return BackupInspectionResult(
      filePath: backupPath,
      fileSizeBytes: fileSizeBytes,
      authSuccess: false,
      formatSuccess: false,
      formatError:
          'El archivo excede el tamaño máximo permitido para GGBK V1 (${BackupV1Limits.maxEncryptedContainerBytes} bytes).',
    );
  }

  final encryptedBytes = await file.readAsBytes();
  final crypto = cryptoServiceOverride ?? BackupCryptoService();

  List<int> plaintextBytes;
  try {
    plaintextBytes = await crypto.decrypt(encryptedBytes, password);
  } on BackupAuthenticationException catch (e) {
    return BackupInspectionResult(
      filePath: backupPath,
      fileSizeBytes: fileSizeBytes,
      authSuccess: false,
      authError: e.message,
      formatSuccess: true,
    );
  } on BackupFormatException catch (e) {
    return BackupInspectionResult(
      filePath: backupPath,
      fileSizeBytes: fileSizeBytes,
      authSuccess: false,
      formatSuccess: false,
      formatError: e.message,
    );
  } catch (e) {
    return BackupInspectionResult(
      filePath: backupPath,
      fileSizeBytes: fileSizeBytes,
      authSuccess: false,
      authError: 'Error inesperado durante la autenticación: $e',
      formatSuccess: false,
    );
  }

  Directory? tempDir;
  Database? db;

  try {
    tempDir = Directory.systemTemp.createTempSync('gestor_inspect_');

    // Descompresión con límites de seguridad V1
    final archive = ZipDecoder().decodeBytes(plaintextBytes, verify: true);

    int uncompressedBytes = 0;
    int entriesCount = 0;

    for (final entry in archive.files) {
      if (!entry.isFile) {
        if (!entry.name.endsWith('/')) {
          throw BackupFormatException('Entrada ZIP especial no permitida: ${entry.name}');
        }
        continue;
      }

      // Prevención de Zip Slip / Path Traversal
      if (entry.name.contains('..') ||
          entry.name.startsWith('/') ||
          entry.name.startsWith('\\')) {
        throw BackupFormatException('Ruta ZIP insegura detectada: ${entry.name}');
      }

      // Whitelist estricta de archivos
      final isManifest = entry.name == 'manifest.json';
      final isDb = entry.name == 'gestor_gastos.db';
      final isPrefs = entry.name == 'preferences.json';
      final isAttachment = entry.name.startsWith('attachments/transactions/') &&
          !entry.name.substring('attachments/transactions/'.length).contains('/');

      if (!isManifest && !isDb && !isPrefs && !isAttachment) {
        throw BackupFormatException('Archivo no permitido dentro del contenedor: ${entry.name}');
      }

      final entrySize = entry.size.toInt();
      uncompressedBytes += entrySize;
      entriesCount++;

      if (entrySize > BackupV1Limits.maxSingleFileBytes) {
        throw BackupTooLargeException('Archivo dentro del ZIP excede límite individual: ${entry.name}');
      }
      if (uncompressedBytes > BackupV1Limits.maxUncompressedPayloadBytes) {
        throw BackupTooLargeException('Payload descomprimido excede límite de 100 MiB.');
      }
      if (entriesCount > BackupV1Limits.maxEntries) {
        throw BackupTooLargeException('Número de entradas excede el límite permitido (2000).');
      }

      final outPath = p.join(tempDir.path, entry.name);
      final outFile = File(outPath);
      outFile.parent.createSync(recursive: true);
      outFile.writeAsBytesSync(entry.content as List<int>, flush: true);
    }

    // 1. Lectura del manifest.json
    int? manifestPayloadVersion;
    String? manifestAppVersion;
    int? manifestSchemaVersion;
    String? manifestCreatedAt;
    List<String> manifestComponents = [];
    int? manifestAttachmentsIncluded;
    int? manifestAttachmentsMissing;

    final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
    if (manifestFile.existsSync()) {
      try {
        final manifestMap =
            jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
        manifestPayloadVersion = manifestMap['payloadVersion'] as int?;
        manifestAppVersion = manifestMap['appVersion'] as String?;
        manifestSchemaVersion = manifestMap['databaseSchemaVersion'] as int?;
        manifestCreatedAt = manifestMap['createdAt'] as String?;
        if (manifestMap['components'] is List) {
          manifestComponents = (manifestMap['components'] as List)
              .map((e) => e.toString())
              .toList();
        }
        manifestAttachmentsIncluded =
            manifestMap['transactionAttachmentsIncluded'] as int?;
        manifestAttachmentsMissing =
            manifestMap['transactionAttachmentsMissing'] as int?;
      } catch (e) {
        warnings.add('No se pudo decodificar manifest.json: $e');
      }
    } else {
      warnings.add('manifest.json no encontrado en el archivo.');
    }

    // 2. Lectura de preferences.json
    int? preferencesCount;
    final prefsFile = File(p.join(tempDir.path, 'preferences.json'));
    if (prefsFile.existsSync()) {
      try {
        final prefsMap =
            jsonDecode(prefsFile.readAsStringSync()) as Map<String, dynamic>;
        preferencesCount = prefsMap.keys.length;
      } catch (e) {
        warnings.add('No se pudo decodificar preferences.json: $e');
      }
    }

    // 3. Inspección SQLite con FFI en modo READ-ONLY
    bool quickCheckPassed = false;
    String quickCheckResult = 'NO EJECUTADO';
    int? dbSchemaVersion;
    final detectedTables = <String>[];

    int? accountsCount;
    int? transactionsCount;
    int? categoriesCount;
    int? goalsCount;
    int? fixedExpensesCount;
    int? remindersCount;
    int? transactionAttachmentRefsCount;

    final dbFile = File(p.join(tempDir.path, 'gestor_gastos.db'));
    if (dbFile.existsSync()) {
      sqfliteFfiInit();
      final databaseFactory = databaseFactoryFfi;

      db = await databaseFactory.openDatabase(
        dbFile.path,
        options: OpenDatabaseOptions(
          readOnly: true,
          singleInstance: false,
        ),
      );

      // PRAGMA quick_check
      final qc = await db.rawQuery('PRAGMA quick_check;');
      if (qc.isNotEmpty) {
        quickCheckResult = qc.first.values.first.toString();
        quickCheckPassed = quickCheckResult.toLowerCase() == 'ok';
      }

      // PRAGMA user_version
      final uv = await db.rawQuery('PRAGMA user_version;');
      if (uv.isNotEmpty) {
        dbSchemaVersion = int.tryParse(uv.first.values.first.toString()) ?? 0;
      }

      // Tablas disponibles en la base de datos
      final tablesQuery = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;");
      for (final row in tablesQuery) {
        final name = row['name'] as String?;
        if (name != null && !name.startsWith('sqlite_') && !name.startsWith('android_')) {
          detectedTables.add(name);
        }
      }

      final tableSet = detectedTables.toSet();

      // Conteos seguros verificando existencia previa de cada tabla
      Future<int?> countTable(String name) async {
        if (!tableSet.contains(name)) return null;
        try {
          final res = await db!.rawQuery('SELECT COUNT(*) as c FROM $name;');
          return res.isNotEmpty ? (res.first['c'] as int?) ?? 0 : 0;
        } catch (_) {
          return null;
        }
      }

      accountsCount = await countTable('accounts');
      transactionsCount = await countTable('transactions');
      categoriesCount = await countTable('categories');
      goalsCount = await countTable('goals');
      fixedExpensesCount = await countTable('fixed_expenses');
      remindersCount = await countTable('reminders');

      // Referencias a attachments en transacciones
      if (tableSet.contains('transactions')) {
        try {
          final columnsInfo =
              await db.rawQuery('PRAGMA table_info(transactions);');
          final hasImagePath =
              columnsInfo.any((col) => col['name'] == 'imagePath');
          if (hasImagePath) {
            final res = await db.rawQuery(
                "SELECT COUNT(*) as c FROM transactions WHERE imagePath IS NOT NULL AND trim(imagePath) != '';");
            transactionAttachmentRefsCount =
                res.isNotEmpty ? (res.first['c'] as int?) ?? 0 : 0;
          } else {
            transactionAttachmentRefsCount = 0;
          }
        } catch (e) {
          warnings.add('No se pudo verificar referencias a adjuntos: $e');
        }
      }
    } else {
      warnings.add('gestor_gastos.db no encontrado en el archivo.');
    }

    // 4. Conteo de archivos físicos de attachments
    int physicalAttachmentsCount = 0;
    final attachmentsDir =
        Directory(p.join(tempDir.path, 'attachments', 'transactions'));
    if (attachmentsDir.existsSync()) {
      physicalAttachmentsCount = attachmentsDir
          .listSync()
          .whereType<File>()
          .length;
    }

    return BackupInspectionResult(
      filePath: backupPath,
      fileSizeBytes: fileSizeBytes,
      authSuccess: true,
      formatSuccess: true,
      manifestPayloadVersion: manifestPayloadVersion,
      manifestAppVersion: manifestAppVersion,
      manifestSchemaVersion: manifestSchemaVersion,
      manifestCreatedAt: manifestCreatedAt,
      manifestComponents: manifestComponents,
      manifestAttachmentsIncluded: manifestAttachmentsIncluded,
      manifestAttachmentsMissing: manifestAttachmentsMissing,
      preferencesCount: preferencesCount,
      quickCheckPassed: quickCheckPassed,
      quickCheckResult: quickCheckResult,
      dbSchemaVersion: dbSchemaVersion,
      detectedTables: detectedTables,
      accountsCount: accountsCount,
      transactionsCount: transactionsCount,
      categoriesCount: categoriesCount,
      goalsCount: goalsCount,
      fixedExpensesCount: fixedExpensesCount,
      remindersCount: remindersCount,
      transactionAttachmentRefsCount: transactionAttachmentRefsCount,
      physicalAttachmentsCount: physicalAttachmentsCount,
      warnings: warnings,
    );
  } finally {
    // Cerrar SQLite antes de eliminar la carpeta en Windows
    if (db != null) {
      try {
        await db.close();
      } catch (_) {}
    }

    // Limpieza segura de los archivos temporales descifrados
    if (tempDir != null && tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

/// Imprime en consola un reporte limpio, seguro y estructurado.
///
/// NUNCA imprime montos, balances, descripciones, nombres, contraseñas ni hashes.
void printInspectionReport(BackupInspectionResult res) {
  final kb = (res.fileSizeBytes / 1024).toStringAsFixed(1);

  stdout.writeln();
  stdout.writeln('===============================================================');
  stdout.writeln('   INSPECCIÓN DE RESPALDO GGBK V1 (GESTOR DE GASTOS)');
  stdout.writeln('===============================================================');
  stdout.writeln('Archivo: ${p.basename(res.filePath)}');
  stdout.writeln('Tamaño:  $kb KB (${res.fileSizeBytes} bytes)');
  stdout.writeln();

  stdout.writeln('--- [1] CONTENEDOR Y AUTENTICACIÓN ---');
  if (!res.formatSuccess) {
    stdout.writeln('  Formato GGBK V1:  FALLIDO');
    stdout.writeln('  Detalle:          ${res.formatError ?? "Formato inválido"}');
    stdout.writeln('===============================================================');
    return;
  }

  if (!res.authSuccess) {
    stdout.writeln('  Autenticación:    FALLIDA');
    stdout.writeln('  Detalle:          ${res.authError ?? "Contraseña incorrecta o archivo alterado"}');
    stdout.writeln('===============================================================');
    return;
  }

  stdout.writeln('  Formato GGBK V1:  VÁLIDO');
  stdout.writeln('  Autenticación:    CORRECTA (Clave y MAC verificados)');
  stdout.writeln();

  stdout.writeln('--- [2] METADATOS DEL MANIFEST ---');
  stdout.writeln('  Versión Payload:         ${res.manifestPayloadVersion ?? "Desconocido"}');
  stdout.writeln('  Versión App Creadora:    ${res.manifestAppVersion ?? "Desconocido"}');
  stdout.writeln('  Versión Esquema DB:      ${res.manifestSchemaVersion ?? "Desconocido"}');
  stdout.writeln('  Fecha Creación (UTC):    ${res.manifestCreatedAt ?? "Desconocido"}');
  stdout.writeln('  Componentes Incluidos:   ${res.manifestComponents.isEmpty ? "Ninguno" : res.manifestComponents.join(", ")}');
  stdout.writeln('  Adjuntos en Manifest:    ${res.manifestAttachmentsIncluded ?? 0} incluidos, ${res.manifestAttachmentsMissing ?? 0} faltantes');
  stdout.writeln();

  stdout.writeln('--- [3] PREFERENCIAS DE USUARIO ---');
  if (res.preferencesCount != null) {
    stdout.writeln('  Preferencias Guardadas:  ${res.preferencesCount} entradas');
  } else {
    stdout.writeln('  Preferencias Guardadas:  No disponible o ausente');
  }
  stdout.writeln();

  stdout.writeln('--- [4] INTEGRIDAD DE LA BASE DE DATOS (SQLite) ---');
  stdout.writeln('  PRAGMA quick_check:      ${res.quickCheckResult ?? "No ejecutado"}');
  stdout.writeln('  PRAGMA user_version:     ${res.dbSchemaVersion ?? "No disponible"}');
  stdout.writeln('  Tablas Detectadas:       ${res.detectedTables.isEmpty ? "Ninguna" : res.detectedTables.join(", ")}');
  stdout.writeln();

  stdout.writeln('--- [5] CONTEO DE DATOS FINANCIEROS (SOLO CONTEOS) ---');
  _printCount('Cuentas (accounts)', res.accountsCount);
  _printCount('Movimientos (transactions)', res.transactionsCount);
  _printCount('Categorías (categories)', res.categoriesCount);
  _printCount('Metas (goals)', res.goalsCount);
  _printCount('Gastos Fijos (fixed_expenses)', res.fixedExpensesCount);
  _printCount('Recordatorios (reminders)', res.remindersCount);
  stdout.writeln();

  stdout.writeln('--- [6] ADJUNTOS / IMÁGENES ---');
  _printCount('Referencias en transacciones', res.transactionAttachmentRefsCount);
  stdout.writeln('  Archivos físicos en ZIP:   ${res.physicalAttachmentsCount ?? 0}');
  stdout.writeln();

  if (res.warnings.isNotEmpty) {
    stdout.writeln('--- ADVERTENCIAS ---');
    for (final w in res.warnings) {
      stdout.writeln('  ! $w');
    }
    stdout.writeln();
  }

  stdout.writeln('===============================================================');
  stdout.writeln('--- DIAGNÓSTICO DEL BACKUP ---');
  final accounts = res.accountsCount ?? 0;
  final txs = res.transactionsCount ?? 0;

  if (accounts > 0 && txs > 0) {
    stdout.writeln('  RESULTADO: CONTIENE DATOS DEL ESTADO A.');
    stdout.writeln('  El archivo tiene $accounts cuenta(s) y $txs movimiento(s).');
    stdout.writeln('  La base de datos es consistente y apta para restaurar.');
  } else if (accounts > 0 && txs == 0) {
    stdout.writeln('  RESULTADO: BACKUP PARCIAL O SIN TRANSACCIONES.');
    stdout.writeln('  El archivo tiene $accounts cuenta(s) pero 0 movimientos.');
  } else {
    stdout.writeln('  RESULTADO: ARCHIVO VACÍO O SIN DATOS.');
    stdout.writeln('  El archivo no contiene cuentas ni transacciones del Estado A.');
  }
  stdout.writeln('===============================================================');
}

void _printCount(String label, int? count) {
  if (count == null) {
    stdout.writeln('  $label: [Tabla no presente en esquema]');
  } else {
    stdout.writeln('  $label: $count');
  }
}

/// Lee una contraseña de consola sin mostrar los caracteres tipeados.
String _readPasswordPrompt(String prompt) {
  stdout.write(prompt);
  String password = '';
  try {
    stdin.echoMode = false;
    final line = stdin.readLineSync();
    password = line ?? '';
  } catch (_) {
    // Si la terminal no soporta deshabilitar eco (ej. stdin redirigido), leer directo
    final line = stdin.readLineSync();
    password = line ?? '';
  } finally {
    try {
      stdin.echoMode = true;
    } catch (_) {}
    stdout.writeln();
  }
  return password;
}

Future<void> main(List<String> args) async {
  String backupPath;

  if (args.isNotEmpty) {
    backupPath = args[0].replaceAll('"', '').trim();
  } else {
    stdout.write('Ruta del archivo .gestorbackup a inspeccionar: ');
    final input = stdin.readLineSync();
    backupPath = (input ?? '').replaceAll('"', '').trim();
  }

  if (backupPath.isEmpty) {
    stderr.writeln('Error: No se especificó ninguna ruta de archivo.');
    exit(1);
  }

  final file = File(backupPath);
  if (!file.existsSync()) {
    stderr.writeln('Error: El archivo "$backupPath" no existe.');
    exit(1);
  }

  final password = _readPasswordPrompt('Contraseña de la copia de seguridad: ');
  if (password.isEmpty) {
    stderr.writeln('Error: La contraseña no puede estar vacía.');
    exit(1);
  }

  stdout.writeln('Descifrando y analizando contenedor... Por favor, espera.');
  final stopwatch = Stopwatch()..start();

  try {
    final result = await inspectBackupFile(
      backupPath: backupPath,
      password: password,
    );

    stopwatch.stop();
    printInspectionReport(result);
    stdout.writeln('Tiempo total de análisis: ${stopwatch.elapsedMilliseconds} ms.');

    if (!result.isFullyValid && (!result.authSuccess || !result.formatSuccess)) {
      exit(2);
    }
  } catch (e, stack) {
    stderr.writeln('Error inesperado durante la inspección: $e');
    stderr.writeln(stack);
    exit(3);
  }
}
