import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'database_key_manager.dart';

/// Estado físico clasificado de un archivo de base de datos en almacenamiento local.
enum DatabasePhysicalStatus {
  /// El archivo especificado no existe físicamente en disco.
  fileNotFound,

  /// Base de datos SQLite estándar v24 íntegra (cabecera SQLite 3, quick_check OK, tablas v24).
  validUnencryptedV24,

  /// Base de datos SQLCipher válida y accesible con la clave proporcionada.
  validEncryptedSqlCipher,

  /// Archivo no plano (potencial SQLCipher) para el cual no se proveyó clave o la clave es nula/vacía.
  encryptedKeyRequired,

  /// Archivo existente pero no reconocido, truncado, con fallo de integridad o error de descifrado.
  corruptedOrUnrecognized,

  /// Se detectó un marcador o residuo de migración pendiente o incompleta en el directorio.
  incompleteMigration,

  /// Base SQLite estándar pero con una versión de esquema distinta de 24.
  incompatibleSchemaVersion,
}

/// Informe detallado resultante de la inspección física de un archivo de base de datos.
class DatabaseInspectionReport {
  final DatabasePhysicalStatus status;
  final String dbPath;
  final int? fileSizeBytes;
  final DateTime? lastModified;
  final int? userVersion;
  final bool hasSqliteHeader;
  final String? failureReason;
  final List<String> detectedTables;
  final String? sha256Fingerprint;

  const DatabaseInspectionReport({
    required this.status,
    required this.dbPath,
    this.fileSizeBytes,
    this.lastModified,
    this.userVersion,
    this.hasSqliteHeader = false,
    this.failureReason,
    this.detectedTables = const [],
    this.sha256Fingerprint,
  });

  /// Determina si la base de datos es una SQLite v24 válida lista para migración a SQLCipher.
  bool get isMigratableV24 =>
      status == DatabasePhysicalStatus.validUnencryptedV24;

  /// Emite una evidencia física vinculante para [DatabaseKeyManager].
  ///
  /// Lanza [StateError] si la inspección no certificó una SQLite v24 válida.
  MigrationPhysicalProof toMigrationProof() {
    if (!isMigratableV24) {
      throw StateError(
        'No se puede emitir una prueba física de migración porque el estado es $status.',
      );
    }
    return MigrationPhysicalProof(
      dbPath: dbPath,
      fileSizeBytes: fileSizeBytes!,
      lastModified: lastModified!,
      validationTimestamp: DateTime.now(),
      userVersion: userVersion ?? 24,
      sha256Fingerprint: sha256Fingerprint!,
    );
  }

  @override
  String toString() {
    return 'DatabaseInspectionReport(status: $status, path: $dbPath, size: $fileSizeBytes, version: $userVersion, header: $hasSqliteHeader)';
  }
}

/// Inspector físico independiente para validar bases de datos en disco antes de migrar.
class DatabasePhysicalInspector {
  static const int expectedUserVersion = 24;

  /// Primeros 16 bytes del formato SQLite 3: "SQLite format 3\0"
  static final Uint8List sqlite3HeaderBytes = Uint8List.fromList([
    0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66,
    0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00,
  ]);

  /// Tablas estructurales requeridas del esquema v24 de Gestor de Gastos.
  static const List<String> requiredTables = [
    'accounts',
    'categories',
    'transactions',
    'fixed_expenses',
    'goals',
    'reminders',
  ];

  final Future<sqflite.Database> Function(String path, {bool? readOnly, bool? singleInstance})?
      _unencryptedDbOpener;
  final Future<sqlcipher.Database> Function(String path, {String? password, bool? readOnly, bool? singleInstance})?
      _encryptedDbOpener;

  const DatabasePhysicalInspector({
    Future<sqflite.Database> Function(String path, {bool? readOnly, bool? singleInstance})?
        unencryptedDbOpener,
    Future<sqlcipher.Database> Function(String path, {String? password, bool? readOnly, bool? singleInstance})?
        encryptedDbOpener,
  })  : _unencryptedDbOpener = unencryptedDbOpener,
        _encryptedDbOpener = encryptedDbOpener;

  /// Inspecciona de forma física y no destructiva un archivo de base de datos en [dbPath].
  Future<DatabaseInspectionReport> inspect({
    required String dbPath,
    String? encryptionKey,
    bool ignoreMigrationMarkers = false,
  }) async {
    final file = File(dbPath);
    final dir = p.dirname(dbPath);
    final baseName = p.basename(dbPath);

    // 1. Detección de marcadores o artefactos de migración pendiente
    final specificMarker = File(p.join(dir, '$baseName.migration.pending'));
    final officialMarker = File(p.join(dir, 'gestor_gastos.migration.pending'));
    final specificStaging = File(p.join(dir, '$baseName.staging'));
    final officialStaging = File(p.join(dir, 'gestor_gastos.db.staging'));

    final hasPendingMarker = await specificMarker.exists() || await officialMarker.exists();
    final hasStaging = await specificStaging.exists() || await officialStaging.exists();

    if (!ignoreMigrationMarkers && (hasPendingMarker || hasStaging)) {
      return DatabaseInspectionReport(
        status: DatabasePhysicalStatus.incompleteMigration,
        dbPath: dbPath,
        failureReason: 'Se detectaron marcadores o archivos de staging de migración previa pendiente.',
      );
    }

    // 2. Existencia real del archivo
    if (!await file.exists()) {
      return DatabaseInspectionReport(
        status: DatabasePhysicalStatus.fileNotFound,
        dbPath: dbPath,
        failureReason: 'El archivo no existe en el almacenamiento.',
      );
    }

    final fileSize = await file.length();
    final lastModified = await file.lastModified();

    if (fileSize < 16) {
      return DatabaseInspectionReport(
        status: DatabasePhysicalStatus.corruptedOrUnrecognized,
        dbPath: dbPath,
        fileSizeBytes: fileSize,
        lastModified: lastModified,
        failureReason: 'Archivo truncado de tamaño menor a 16 bytes ($fileSize bytes).',
      );
    }

    // 3. Verificación de cabecera binaria SQLite 3
    final headerBytes = await _readHeaderBytes(file, 16);
    final hasHeader = _matchesSqliteHeader(headerBytes);

    if (hasHeader) {
      // 4. Intento de apertura y verificación como SQLite plana
      return await _inspectUnencryptedSqlite(
        dbPath: dbPath,
        fileSize: fileSize,
        lastModified: lastModified,
      );
    } else {
      // 5. El archivo no tiene cabecera plana. Comprobar si es SQLCipher válido o corrupto
      return await _inspectEncryptedCandidate(
        dbPath: dbPath,
        fileSize: fileSize,
        lastModified: lastModified,
        encryptionKey: encryptionKey,
      );
    }
  }

  /// Lee los primeros [byteCount] bytes del archivo.
  Future<Uint8List> _readHeaderBytes(File file, int byteCount) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      return await raf.read(byteCount);
    } finally {
      await raf.close();
    }
  }

  /// Compara los bytes con la firma estándar de SQLite 3.
  bool _matchesSqliteHeader(Uint8List bytes) {
    if (bytes.length < 16) return false;
    for (int i = 0; i < 16; i++) {
      if (bytes[i] != sqlite3HeaderBytes[i]) {
        return false;
      }
    }
    return true;
  }

  /// Inspecciona una base que posee cabecera SQLite plana.
  Future<DatabaseInspectionReport> _inspectUnencryptedSqlite({
    required String dbPath,
    required int fileSize,
    required DateTime lastModified,
  }) async {
    sqflite.Database? db;
    try {
      if (_unencryptedDbOpener != null) {
        db = await _unencryptedDbOpener!(dbPath, readOnly: true, singleInstance: false);
      } else {
        db = await sqflite.openDatabase(dbPath, readOnly: true, singleInstance: false);
      }

      // Verificación de integridad PRAGMA quick_check
      final quickCheckResult = await db.rawQuery('PRAGMA quick_check;');
      if (quickCheckResult.isEmpty) {
        return DatabaseInspectionReport(
          status: DatabasePhysicalStatus.corruptedOrUnrecognized,
          dbPath: dbPath,
          fileSizeBytes: fileSize,
          lastModified: lastModified,
          hasSqliteHeader: true,
          failureReason: 'PRAGMA quick_check no retornó resultados.',
        );
      }

      final checkValue = quickCheckResult.first.values.first?.toString().toLowerCase();
      if (checkValue != 'ok') {
        return DatabaseInspectionReport(
          status: DatabasePhysicalStatus.corruptedOrUnrecognized,
          dbPath: dbPath,
          fileSizeBytes: fileSize,
          lastModified: lastModified,
          hasSqliteHeader: true,
          failureReason: 'PRAGMA quick_check reportó errores: $checkValue.',
        );
      }

      // Verificación de versión del esquema
      final versionResult = await db.rawQuery('PRAGMA user_version;');
      final userVersion = versionResult.isNotEmpty
          ? (versionResult.first.values.first as int? ?? 0)
          : 0;

      if (userVersion != expectedUserVersion) {
        return DatabaseInspectionReport(
          status: DatabasePhysicalStatus.incompatibleSchemaVersion,
          dbPath: dbPath,
          fileSizeBytes: fileSize,
          lastModified: lastModified,
          userVersion: userVersion,
          hasSqliteHeader: true,
          failureReason: 'user_version $userVersion difiere de la esperada ($expectedUserVersion).',
        );
      }

      // Verificación de tablas requeridas del esquema
      final tablesResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table';",
      );
      final detectedTables = tablesResult
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      final missingTables = requiredTables
          .where((req) => !detectedTables.contains(req))
          .toList();

      if (missingTables.isNotEmpty) {
        return DatabaseInspectionReport(
          status: DatabasePhysicalStatus.corruptedOrUnrecognized,
          dbPath: dbPath,
          fileSizeBytes: fileSize,
          lastModified: lastModified,
          userVersion: userVersion,
          hasSqliteHeader: true,
          detectedTables: detectedTables,
          failureReason: 'Faltan tablas obligatorias del esquema v24: $missingTables.',
        );
      }

      // Cálculo de huella criptográfica SHA-256 del archivo validado
      final file = File(dbPath);
      String? sha256Fingerprint;
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final hash = await Sha256().hash(bytes);
        sha256Fingerprint =
            hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      }

      return DatabaseInspectionReport(
        status: DatabasePhysicalStatus.validUnencryptedV24,
        dbPath: dbPath,
        fileSizeBytes: fileSize,
        lastModified: lastModified,
        userVersion: userVersion,
        hasSqliteHeader: true,
        detectedTables: detectedTables,
        sha256Fingerprint: sha256Fingerprint,
      );
    } catch (e) {
      return DatabaseInspectionReport(
        status: DatabasePhysicalStatus.corruptedOrUnrecognized,
        dbPath: dbPath,
        fileSizeBytes: fileSize,
        lastModified: lastModified,
        hasSqliteHeader: true,
        failureReason: 'Fallo al abrir o consultar SQLite plana: $e',
      );
    } finally {
      if (db != null) {
        try {
          await db.close();
        } catch (_) {}
      }
    }
  }

  /// Inspecciona una base que no tiene cabecera SQLite (potencial SQLCipher).
  Future<DatabaseInspectionReport> _inspectEncryptedCandidate({
    required String dbPath,
    required int fileSize,
    required DateTime lastModified,
    required String? encryptionKey,
  }) async {
    if (encryptionKey == null || encryptionKey.isEmpty) {
      return DatabaseInspectionReport(
        status: DatabasePhysicalStatus.encryptedKeyRequired,
        dbPath: dbPath,
        fileSizeBytes: fileSize,
        lastModified: lastModified,
        hasSqliteHeader: false,
        failureReason: 'El archivo no tiene cabecera SQLite estándar y no se suministró clave de descifrado.',
      );
    }

    sqlcipher.Database? cipherDb;
    try {
      if (_encryptedDbOpener != null) {
        cipherDb = await _encryptedDbOpener!(
          dbPath,
          password: encryptionKey,
          readOnly: true,
          singleInstance: false,
        );
      } else {
        cipherDb = await sqlcipher.openDatabase(
          dbPath,
          password: encryptionKey,
          readOnly: true,
          singleInstance: false,
        );
      }

      // Verificación de lectura efectiva en SQLCipher
      final checkResult = await cipherDb.rawQuery('PRAGMA quick_check;');
      final checkValue = checkResult.isNotEmpty
          ? checkResult.first.values.first?.toString().toLowerCase()
          : null;

      if (checkValue != 'ok') {
        return DatabaseInspectionReport(
          status: DatabasePhysicalStatus.corruptedOrUnrecognized,
          dbPath: dbPath,
          fileSizeBytes: fileSize,
          lastModified: lastModified,
          hasSqliteHeader: false,
          failureReason: 'PRAGMA quick_check en SQLCipher reportó error: $checkValue.',
        );
      }

      final versionResult = await cipherDb.rawQuery('PRAGMA user_version;');
      final userVersion = versionResult.isNotEmpty
          ? (versionResult.first.values.first as int? ?? 0)
          : 0;

      final tablesResult = await cipherDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table';",
      );
      final detectedTables = tablesResult
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      return DatabaseInspectionReport(
        status: DatabasePhysicalStatus.validEncryptedSqlCipher,
        dbPath: dbPath,
        fileSizeBytes: fileSize,
        lastModified: lastModified,
        userVersion: userVersion,
        hasSqliteHeader: false,
        detectedTables: detectedTables,
      );
    } catch (e) {
      return DatabaseInspectionReport(
        status: DatabasePhysicalStatus.corruptedOrUnrecognized,
        dbPath: dbPath,
        fileSizeBytes: fileSize,
        lastModified: lastModified,
        hasSqliteHeader: false,
        failureReason: 'Fallo al descifrar o verificar SQLCipher con la clave provista: $e',
      );
    } finally {
      if (cipherDb != null) {
        try {
          await cipherDb.close();
        } catch (_) {}
      }
    }
  }
}
