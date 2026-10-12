import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'database_key_manager.dart';
import 'database_physical_inspector.dart';

/// Excepciones específicas del servicio de migración y recuperación.
abstract class DatabaseMigrationException implements Exception {
  final String message;
  final Object? cause;
  const DatabaseMigrationException(this.message, [this.cause]);

  @override
  String toString() => 'DatabaseMigrationException: $message ${cause != null ? "(cause: $cause)" : ""}';
}

class DatabaseMigrationValidationException extends DatabaseMigrationException {
  const DatabaseMigrationValidationException(super.message, [super.cause]);
}

class DatabaseMigrationConflictException extends DatabaseMigrationException {
  const DatabaseMigrationConflictException(super.message, [super.cause]);
}

class DatabaseMigrationRecoveryConflictException extends DatabaseMigrationException {
  const DatabaseMigrationRecoveryConflictException(super.message, [super.cause]);
}

class DatabaseMigrationRecoveryAmbiguityException extends DatabaseMigrationException {
  const DatabaseMigrationRecoveryAmbiguityException(super.message, [super.cause]);
}

class DatabaseMigrationIntegrityException extends DatabaseMigrationException {
  const DatabaseMigrationIntegrityException(super.message, [super.cause]);
}

/// Convención oficial de rutas y nombres de artefactos para el proceso de migración.
class MigrationPaths {
  final String sourcePath;
  final String markerPath;
  final String stagingPath;
  final String fallbackPath;

  MigrationPaths({
    required this.sourcePath,
    String? markerPath,
    String? stagingPath,
    String? fallbackPath,
  })  : markerPath = markerPath ??
            p.join(p.dirname(sourcePath), 'gestor_gastos.migration.pending'),
        stagingPath = stagingPath ??
            p.join(p.dirname(sourcePath), 'gestor_gastos.db.staging'),
        fallbackPath = fallbackPath ??
            p.join(p.dirname(sourcePath), 'gestor_gastos.db.pre_cipher_backup');
}

/// Etapas persistentes del ciclo de migración registradas en el marcador.
class MigrationStage {
  static const String exportPending = 'EXPORT_PENDING';
  static const String readyToSwap = 'READY_TO_SWAP';
  static const String cleanupPending = 'CLEANUP_PENDING';
}

/// Contrato para la ejecución de comandos SQLCipher durante la migración.
///
/// Permite desacoplar las operaciones nativas de SQLCipher para facilitar
/// pruebas automatizadas en entornos donde las bibliotecas compartidas varían.
abstract class MigrationDatabaseExecutor {
  Future<void> exportToEncryptedStaging({
    required String sourcePath,
    required String stagingPath,
    required String encryptionKey,
  });

  Future<void> setUserVersion({
    required String dbPath,
    required String encryptionKey,
    required int version,
  });

  Future<Map<String, int>> collectControlCounts({
    required String dbPath,
    required String encryptionKey,
  });

  Future<Map<String, int>> collectSourceControlCounts({
    required String dbPath,
  });
}

/// Ejecutor de producción basado en la API nativa de [sqflite_sqlcipher].
class SqlCipherMigrationDatabaseExecutor implements MigrationDatabaseExecutor {
  @override
  Future<void> exportToEncryptedStaging({
    required String sourcePath,
    required String stagingPath,
    required String encryptionKey,
  }) async {
    // Abre la base origen con el motor SQLCipher (sin contraseña para leer SQLite plana)
    final db = await sqlcipher.openDatabase(sourcePath, singleInstance: false);
    try {
      // 1. Si la base origen está en modo WAL, verificar y vaciar el WAL mediante checkpoint
      final journalModeRes = await db.rawQuery('PRAGMA journal_mode;');
      final journalMode = journalModeRes.isNotEmpty
          ? journalModeRes.first.values.first?.toString().toLowerCase()
          : 'delete';
      if (journalMode == 'wal') {
        final cpRes = await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
        if (cpRes.isNotEmpty) {
          final busy = cpRes.first['busy'] as int? ?? 0;
          if (busy != 0) {
            throw const DatabaseMigrationIntegrityException(
              'No se pudo completar wal_checkpoint(TRUNCATE) en la base origen: recurso ocupado.',
            );
          }
        }
      }

      await db.execute('ATTACH DATABASE ? AS encrypted KEY ?', [
        stagingPath,
        encryptionKey,
      ]);
      await db.rawQuery("SELECT sqlcipher_export('encrypted');");
      await db.execute('DETACH DATABASE encrypted;');
    } finally {
      await db.close();
    }
  }

  @override
  Future<void> setUserVersion({
    required String dbPath,
    required String encryptionKey,
    required int version,
  }) async {
    final db = await sqlcipher.openDatabase(
      dbPath,
      password: encryptionKey,
      singleInstance: false,
    );
    try {
      await db.execute('PRAGMA user_version = $version;');
      final journalModeRes = await db.rawQuery('PRAGMA journal_mode;');
      final mode = journalModeRes.isNotEmpty
          ? journalModeRes.first.values.first?.toString().toLowerCase()
          : 'delete';
      if (mode == 'wal') {
        final cpRes = await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE);');
        if (cpRes.isNotEmpty) {
          final busy = cpRes.first['busy'] as int? ?? 0;
          if (busy != 0) {
            throw const DatabaseMigrationIntegrityException(
              'No se pudo completar wal_checkpoint(TRUNCATE) en la base staging cifrada: recurso ocupado.',
            );
          }
        }
      }
    } finally {
      await db.close();
    }
  }

  @override
  Future<Map<String, int>> collectControlCounts({
    required String dbPath,
    required String encryptionKey,
  }) async {
    final db = await sqlcipher.openDatabase(
      dbPath,
      password: encryptionKey,
      readOnly: true,
      singleInstance: false,
    );
    try {
      final check = await db.rawQuery('PRAGMA quick_check;');
      if (check.isEmpty || check.first.values.first?.toString().toLowerCase() != 'ok') {
        throw const DatabaseMigrationIntegrityException(
          'PRAGMA quick_check falló en base SQLCipher cifrada.',
        );
      }
      return await _countTables(db);
    } finally {
      await db.close();
    }
  }

  @override
  Future<Map<String, int>> collectSourceControlCounts({
    required String dbPath,
  }) async {
    final db = await sqflite.openDatabase(
      dbPath,
      readOnly: true,
      singleInstance: false,
    );
    try {
      return await _countTables(db);
    } finally {
      await db.close();
    }
  }

  Future<Map<String, int>> _countTables(dynamic db) async {
    final counts = <String, int>{};
    for (final table in DatabasePhysicalInspector.requiredTables) {
      final res = await db.rawQuery('SELECT COUNT(*) FROM $table;');
      final count = res.isNotEmpty ? (res.first.values.first as int? ?? 0) : 0;
      counts[table] = count;
    }
    return counts;
  }
}

/// Resultado de una operación de migración a SQLCipher.
class DatabaseMigrationResult {
  final bool isSuccess;
  final String dbPath;
  final String? fallbackPath;
  final Map<String, int> migratedCounts;
  final Duration elapsed;
  final String? errorMessage;

  const DatabaseMigrationResult({
    required this.isSuccess,
    required this.dbPath,
    this.fallbackPath,
    this.migratedCounts = const {},
    required this.elapsed,
    this.errorMessage,
  });

  @override
  String toString() =>
      'DatabaseMigrationResult(success: $isSuccess, path: $dbPath, counts: $migratedCounts, elapsed: ${elapsed.inMilliseconds}ms)';
}

/// Acción adoptada durante la resolución de recuperación ante fallos.
enum RecoveryActionTaken {
  noActionNeeded,
  abortedAndCleanedUp,
  rolledBackToUnencrypted,
  migrationConfirmedAndCompleted,
}

/// Informe de resolución de recuperación ante interrupciones (process-death).
class MigrationRecoveryResult {
  final RecoveryActionTaken action;
  final String dbPath;
  final String? details;

  const MigrationRecoveryResult({
    required this.action,
    required this.dbPath,
    this.details,
  });

  @override
  String toString() =>
      'MigrationRecoveryResult(action: $action, path: $dbPath, details: $details)';
}

/// Servicio independiente y aislado para ejecutar la migración de SQLite v24 a SQLCipher
/// con respaldo atómico, validación previa no destructiva y protocolo anti-interrupciones.
class DatabaseEncryptionMigrationService {
  final DatabasePhysicalInspector _inspector;
  final DatabaseKeyManager _keyManager;
  final MigrationDatabaseExecutor _executor;

  DatabaseEncryptionMigrationService({
    DatabasePhysicalInspector? inspector,
    DatabaseKeyManager? keyManager,
    MigrationDatabaseExecutor? executor,
  })  : _inspector = inspector ?? const DatabasePhysicalInspector(),
        _keyManager = keyManager ?? DatabaseKeyManagerImpl(),
        _executor = executor ?? SqlCipherMigrationDatabaseExecutor();

  static const List<String> _sidecarExtensions = ['-wal', '-shm', '-journal'];

  /// Renombra un archivo de base de datos junto con cualquier archivo auxiliar (-wal, -shm, -journal).
  Future<void> _renameWithSidecars(String fromPath, String toPath) async {
    final fromFile = File(fromPath);
    if (await fromFile.exists()) {
      final toFile = File(toPath);
      if (await toFile.exists()) {
        await toFile.delete();
      }
      await fromFile.rename(toPath);
    }
    for (final ext in _sidecarExtensions) {
      final fromSidecar = File('$fromPath$ext');
      if (await fromSidecar.exists()) {
        final toSidecar = File('$toPath$ext');
        if (await toSidecar.exists()) {
          await toSidecar.delete();
        }
        await fromSidecar.rename(toSidecar.path);
      }
    }
  }

  /// Elimina un archivo de base de datos junto con cualquier archivo auxiliar (-wal, -shm, -journal).
  Future<void> _deleteWithSidecars(String basePath) async {
    final baseFile = File(basePath);
    if (await baseFile.exists()) {
      await baseFile.delete();
    }
    for (final ext in _sidecarExtensions) {
      final sidecar = File('$basePath$ext');
      if (await sidecar.exists()) {
        await sidecar.delete();
      }
    }
  }

  /// Ejecuta la migración segura in-place de la base SQLite indicada por [paths].
  ///
  /// Si [testKey] se proporciona, se utiliza directamente; de lo contrario, se solicita
  /// a [DatabaseKeyManager] mediante una [MigrationPhysicalProof] vinculada al archivo.
  Future<DatabaseMigrationResult> migrate({
    required MigrationPaths paths,
    String? testKey,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Coordinación de seguridad: Rechazar si hay restauración pendiente
    await _assertNoRestoreConflict(paths.sourcePath);

    // 2. Inspección física no destructiva del origen
    final report = await _inspector.inspect(dbPath: paths.sourcePath);
    if (!report.isMigratableV24) {
      throw DatabaseMigrationValidationException(
        'El archivo origen no califica para migración: estado = ${report.status}. Causa: ${report.failureReason}',
      );
    }

    // 3. Autorización de clave vinculada al archivo físico
    final String key;
    if (testKey != null && testKey.isNotEmpty) {
      key = testKey;
    } else {
      final existingKey = await _keyManager.getExistingKey();
      if (existingKey != null && existingKey.isNotEmpty) {
        key = existingKey;
      } else {
        final proof = report.toMigrationProof();
        key = await _keyManager.createKeyForMigration(proof: proof);
      }
    }

    // 4. Verificación de estabilidad del archivo origen antes de iniciar exportación
    final sourceFile = File(paths.sourcePath);
    if (!await sourceFile.exists()) {
      throw const DatabaseMigrationValidationException(
        'El archivo origen dejó de existir antes de preparar el staging.',
      );
    }

    // 5. Colecta de conteos de control del origen
    final sourceCounts = await _executor.collectSourceControlCounts(
      dbPath: paths.sourcePath,
    );

    // 6. Preparación atómica del marcador persistente de migración
    final markerFile = File(paths.markerPath);
    await _deleteWithSidecars(paths.stagingPath);

    await _writeMarker(
      markerFile: markerFile,
      stage: MigrationStage.exportPending,
      paths: paths,
      counts: sourceCounts,
    );

    try {
      // 7. Exportación cifrada mediante sqlcipher_export
      await _executor.exportToEncryptedStaging(
        sourcePath: paths.sourcePath,
        stagingPath: paths.stagingPath,
        encryptionKey: key,
      );

      // 8. Asignación explícita de user_version = 24 en staging
      await _executor.setUserVersion(
        dbPath: paths.stagingPath,
        encryptionKey: key,
        version: DatabasePhysicalInspector.expectedUserVersion,
      );

      // 9. Validación de integridad y estructura en staging
      final stagingReport = await _inspector.inspect(
        dbPath: paths.stagingPath,
        encryptionKey: key,
        ignoreMigrationMarkers: true,
      );
      if (stagingReport.status != DatabasePhysicalStatus.validEncryptedSqlCipher) {
        throw DatabaseMigrationIntegrityException(
          'El archivo staging cifrado falló la inspección: ${stagingReport.failureReason}',
        );
      }

      // 10. Validación de conteos de control en staging
      final stagingCounts = await _executor.collectControlCounts(
        dbPath: paths.stagingPath,
        encryptionKey: key,
      );

      for (final table in sourceCounts.keys) {
        if (sourceCounts[table] != stagingCounts[table]) {
          throw DatabaseMigrationIntegrityException(
            'Discrepancia en conteo de tabla $table: origen=${sourceCounts[table]}, cifrado=${stagingCounts[table]}',
          );
        }
      }

      // 11. Actualización del marcador: listos para intercambio atómico
      await _writeMarker(
        markerFile: markerFile,
        stage: MigrationStage.readyToSwap,
        paths: paths,
        counts: sourceCounts,
      );

      // 12. Intercambio seguro en 2 pasos con sidecars:
      // Paso A: Preservar origen como fallback
      await _renameWithSidecars(paths.sourcePath, paths.fallbackPath);

      // Paso B: Promover staging a la ruta definitiva de producción
      await _renameWithSidecars(paths.stagingPath, paths.sourcePath);

      // 13. Reinspección y verificación final del destino en producción post-swap
      final finalReport = await _inspector.inspect(
        dbPath: paths.sourcePath,
        encryptionKey: key,
        ignoreMigrationMarkers: true,
      );
      if (finalReport.status != DatabasePhysicalStatus.validEncryptedSqlCipher) {
        throw DatabaseMigrationIntegrityException(
          'La base de datos en destino falló la validación final post-swap: ${finalReport.failureReason}',
        );
      }

      // 14. Verificación de conteos de control directamente en la base destino promovida
      final targetCounts = await _executor.collectControlCounts(
        dbPath: paths.sourcePath,
        encryptionKey: key,
      );
      for (final table in sourceCounts.keys) {
        if (sourceCounts[table] != targetCounts[table]) {
          throw DatabaseMigrationIntegrityException(
            'Discrepancia en conteo post-swap en tabla $table: origen=${sourceCounts[table]}, destino=${targetCounts[table]}',
          );
        }
      }

      // 15. Registro de CLEANUP_PENDING en el marcador persistente
      // La base cifrada ha sido confirmada; se autoriza la limpieza de artefactos temporales
      await _writeMarker(
        markerFile: markerFile,
        stage: MigrationStage.cleanupPending,
        paths: paths,
        counts: sourceCounts,
      );

      // 16. Limpieza del fallback no cifrado y staging residual con sidecars
      await _deleteWithSidecars(paths.fallbackPath);
      await _deleteWithSidecars(paths.stagingPath);

      // 17. Limpieza final del marcador persistente
      if (await markerFile.exists()) {
        await markerFile.delete();
      }

      stopwatch.stop();
      return DatabaseMigrationResult(
        isSuccess: true,
        dbPath: paths.sourcePath,
        fallbackPath: null,
        migratedCounts: targetCounts,
        elapsed: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      // En caso de fallo antes del swap completo, asegurar el estado
      if (await markerFile.exists()) {
        try {
          await recover(paths: paths, encryptionKey: key);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Protocolo de recuperación de fallos e interrupciones (process-death).
  ///
  /// Es estrictamente idempotente y preserva los datos ante cualquier incertidumbre.
  Future<MigrationRecoveryResult> recover({
    required MigrationPaths paths,
    String? encryptionKey,
  }) async {
    // REGLA CRÍTICA: Conflicto con RESTORE pendiente -> STOP Y PRESERVACIÓN
    await _assertNoRestoreConflict(paths.sourcePath);

    final markerFile = File(paths.markerPath);
    final fallbackFile = File(paths.fallbackPath);
    final sourceFile = File(paths.sourcePath);

    // Si no existe marcador, no hay migración inconclusa
    if (!await markerFile.exists()) {
      return MigrationRecoveryResult(
        action: RecoveryActionTaken.noActionNeeded,
        dbPath: paths.sourcePath,
        details: 'No existe marcador de migración pendiente.',
      );
    }

    Map<String, dynamic> markerData = {};
    try {
      final markerContent = await markerFile.readAsString();
      markerData = jsonDecode(markerContent) as Map<String, dynamic>;
    } catch (_) {}

    final stage = markerData['stage'] as String?;
    final hasFallback = await fallbackFile.exists();
    final hasSource = await sourceFile.exists();

    // ESCENARIO 1: Marcador en CLEANUP_PENDING
    // La base cifrada ya fue promovida y verificada antes de la interrupción
    if (stage == MigrationStage.cleanupPending) {
      if (encryptionKey == null || encryptionKey.isEmpty) {
        throw const DatabaseMigrationRecoveryAmbiguityException(
          'Marcador en CLEANUP_PENDING pero no hay clave disponible para verificar la base cifrada. Ante incertidumbre, se detiene la operación y se preservan todos los archivos.',
        );
      }

      final inspection = await _inspector.inspect(
        dbPath: paths.sourcePath,
        encryptionKey: encryptionKey,
        ignoreMigrationMarkers: true,
      );

      if (inspection.status == DatabasePhysicalStatus.validEncryptedSqlCipher) {
        // Base cifrada confirmada íntegra: completar limpieza pendiente
        await _deleteWithSidecars(paths.fallbackPath);
        await _deleteWithSidecars(paths.stagingPath);
        await markerFile.delete();
        return MigrationRecoveryResult(
          action: RecoveryActionTaken.migrationConfirmedAndCompleted,
          dbPath: paths.sourcePath,
          details: 'Recuperación de CLEANUP_PENDING exitosa: base cifrada íntegra, fallback eliminado y marcador resuelto.',
        );
      } else {
        // La base cifrada está corrupta o incompleta
        if (hasFallback) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          await _renameWithSidecars(paths.sourcePath, '${paths.sourcePath}.corrupt_$timestamp');
          await _renameWithSidecars(paths.fallbackPath, paths.sourcePath);
          await _deleteWithSidecars(paths.stagingPath);
          await markerFile.delete();
          return MigrationRecoveryResult(
            action: RecoveryActionTaken.rolledBackToUnencrypted,
            dbPath: paths.sourcePath,
            details: 'Base cifrada inválida durante CLEANUP_PENDING. Rollback ejecutado restaurando origen plano desde fallback.',
          );
        } else {
          throw const DatabaseMigrationRecoveryAmbiguityException(
            'ERROR CRÍTICO: Base cifrada inválida durante CLEANUP_PENDING y el fallback ya fue eliminado. Se detiene la operación preservando el directorio.',
          );
        }
      }
    }

    // ESCENARIO 2: Fallback no existe
    // El swap jamás ocurrió (interrupción durante exportación o antes del primer rename).
    if (!hasFallback) {
      if (hasSource) {
        await _deleteWithSidecars(paths.stagingPath);
        await markerFile.delete();
        return MigrationRecoveryResult(
          action: RecoveryActionTaken.abortedAndCleanedUp,
          dbPath: paths.sourcePath,
          details: 'Migración abortada antes del swap. Origen plano intacto; staging eliminado.',
        );
      } else {
        // Ni fallback ni source existen: Ambivalencia crítica
        throw const DatabaseMigrationRecoveryAmbiguityException(
          'ERROR CRÍTICO: Marcador presente pero no existen ni el origen ni el fallback. Se preservan todos los archivos.',
        );
      }
    }

    // ESCENARIO 3: Fallback existe, pero source NO existe
    // Interrupción entre el rename A (source -> fallback) y el rename B (staging -> source).
    if (hasFallback && !hasSource) {
      await _renameWithSidecars(paths.fallbackPath, paths.sourcePath);
      await _deleteWithSidecars(paths.stagingPath);
      await markerFile.delete();
      return MigrationRecoveryResult(
        action: RecoveryActionTaken.rolledBackToUnencrypted,
        dbPath: paths.sourcePath,
        details: 'Interrupción durante el renombrado. Se restauró el origen plano desde el fallback.',
      );
    }

    // ESCENARIO 4: Ambos existen (fallback y source) y stage es anterior a CLEANUP_PENDING
    if (hasFallback && hasSource) {
      if (encryptionKey == null || encryptionKey.isEmpty) {
        throw const DatabaseMigrationRecoveryAmbiguityException(
          'Marcador activo con ambos archivos presentes pero sin clave de descifrado disponible. Ante ambigüedad, se detiene la operación y se preservan todos los archivos.',
        );
      }

      final inspection = await _inspector.inspect(
        dbPath: paths.sourcePath,
        encryptionKey: encryptionKey,
        ignoreMigrationMarkers: true,
      );

      if (inspection.status == DatabasePhysicalStatus.validEncryptedSqlCipher) {
        // La base promovida es SQLCipher válida: confirmar y limpiar fallback
        await _deleteWithSidecars(paths.fallbackPath);
        await _deleteWithSidecars(paths.stagingPath);
        await markerFile.delete();
        return MigrationRecoveryResult(
          action: RecoveryActionTaken.migrationConfirmedAndCompleted,
          dbPath: paths.sourcePath,
          details: 'La base cifrada es válida e íntegra. Migración confirmada, fallback eliminado y marcador resuelto.',
        );
      } else {
        // La base promovida está corrupta o ilegible: Rollback al fallback intacto
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await _renameWithSidecars(paths.sourcePath, '${paths.sourcePath}.corrupt_$timestamp');
        await _renameWithSidecars(paths.fallbackPath, paths.sourcePath);
        await _deleteWithSidecars(paths.stagingPath);
        await markerFile.delete();
        return MigrationRecoveryResult(
          action: RecoveryActionTaken.rolledBackToUnencrypted,
          dbPath: paths.sourcePath,
          details: 'El archivo destino no pudo confirmarse como SQLCipher válido. Rollback ejecutado al fallback no cifrado.',
        );
      }
    }

    throw const DatabaseMigrationRecoveryAmbiguityException(
      'Estado de recuperación ambiguo e irresoluble. Se detiene la operación preservando el directorio.',
    );
  }

  /// Verifica que no exista simultáneamente un proceso de restauración pendiente.
  Future<void> _assertNoRestoreConflict(String dbPath) async {
    final dir = p.dirname(dbPath);
    final restoreMarker = File(p.join(dir, 'gestor_gastos.restore.pending'));
    final restoreFallback = File(p.join(dir, 'gestor_gastos.db.fallback'));

    if (await restoreMarker.exists() || await restoreFallback.exists()) {
      throw const DatabaseMigrationRecoveryConflictException(
        'ALERTA CRÍTICA: Conflicto de operaciones concurrentes. Se detectó un marcador o fallback de restauración activa. Operación detenida para preservar integridad.',
      );
    }
  }

  /// Escribe el marcador persistente en formato JSON asegurando sincronización con disco.
  Future<void> _writeMarker({
    required File markerFile,
    required String stage,
    required MigrationPaths paths,
    Map<String, int>? counts,
  }) async {
    final payload = jsonEncode({
      'version': 1,
      'stage': stage,
      'timestamp': DateTime.now().toIso8601String(),
      'sourcePath': paths.sourcePath,
      'stagingPath': paths.stagingPath,
      'fallbackPath': paths.fallbackPath,
      if (counts != null) 'counts': counts,
    });
    await markerFile.writeAsString(payload, flush: true);
  }
}
