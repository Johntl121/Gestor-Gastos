import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/services/database_encryption_migration_service.dart';
import 'package:gestor_gastos/core/services/database_physical_inspector.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Test double de [MigrationDatabaseExecutor] para pruebas controladas en VM
class TestMigrationDatabaseExecutor implements MigrationDatabaseExecutor {
  final DatabaseFactory databaseFactory;
  bool shouldFailExport = false;
  bool shouldFailIntegrity = false;

  TestMigrationDatabaseExecutor({required this.databaseFactory});

  @override
  Future<void> exportToEncryptedStaging({
    required String sourcePath,
    required String stagingPath,
    required String encryptionKey,
  }) async {
    if (shouldFailExport) {
      throw Exception('Simulated export failure');
    }
    // Para pruebas de lógica aislada en Windows, copiamos la estructura y datos sintéticos
    final sourceFile = File(sourcePath);
    await sourceFile.copy(stagingPath);
  }

  @override
  Future<void> setUserVersion({
    required String dbPath,
    required String encryptionKey,
    required int version,
  }) async {
    final db = await databaseFactory.openDatabase(dbPath);
    await db.execute('PRAGMA user_version = $version;');
    await db.close();
  }

  @override
  Future<Map<String, int>> collectControlCounts({
    required String dbPath,
    required String encryptionKey,
  }) async {
    if (shouldFailIntegrity) {
      throw const DatabaseMigrationIntegrityException('Simulated integrity failure');
    }
    return await collectSourceControlCounts(dbPath: dbPath);
  }

  @override
  Future<Map<String, int>> collectSourceControlCounts({
    required String dbPath,
  }) async {
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(readOnly: true),
    );
    try {
      final counts = <String, int>{};
      for (final table in DatabasePhysicalInspector.requiredTables) {
        final res = await db.rawQuery('SELECT COUNT(*) FROM $table;');
        counts[table] = res.isNotEmpty ? (res.first.values.first as int? ?? 0) : 0;
      }
      return counts;
    } finally {
      await db.close();
    }
  }
}

/// Fake inspector que permite simular estado cifrado en pruebas en VM
class TestDatabasePhysicalInspector extends DatabasePhysicalInspector {
  final DatabasePhysicalInspector _realInspector;
  bool simulateEncryptedSuccessOnKey = true;

  TestDatabasePhysicalInspector(this._realInspector);

  @override
  Future<DatabaseInspectionReport> inspect({
    required String dbPath,
    String? encryptionKey,
    bool ignoreMigrationMarkers = false,
  }) async {
    final realReport = await _realInspector.inspect(
      dbPath: dbPath,
      encryptionKey: encryptionKey,
      ignoreMigrationMarkers: ignoreMigrationMarkers,
    );

    // Si tiene clave y el archivo existe, simular validEncryptedSqlCipher para pruebas en VM
    if (encryptionKey != null &&
        encryptionKey.isNotEmpty &&
        await File(dbPath).exists() &&
        simulateEncryptedSuccessOnKey) {
      return DatabaseInspectionReport(
        status: DatabasePhysicalStatus.validEncryptedSqlCipher,
        dbPath: dbPath,
        fileSizeBytes: await File(dbPath).length(),
        lastModified: await File(dbPath).lastModified(),
        userVersion: 24,
        hasSqliteHeader: false,
        detectedTables: DatabasePhysicalInspector.requiredTables,
      );
    }

    return realReport;
  }
}

void main() {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late TestDatabasePhysicalInspector inspector;
  late TestMigrationDatabaseExecutor executor;
  late DatabaseEncryptionMigrationService migrationService;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('migration_test_');
    final realInspector = DatabasePhysicalInspector(
      unencryptedDbOpener: (path, {readOnly, singleInstance}) =>
          databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: readOnly ?? false),
      ),
    );
    inspector = TestDatabasePhysicalInspector(realInspector);
    executor = TestMigrationDatabaseExecutor(databaseFactory: databaseFactory);

    migrationService = DatabaseEncryptionMigrationService(
      inspector: inspector,
      executor: executor,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<String> createSyntheticV24Database(String fileName) async {
    final dbPath = p.join(tempDir.path, fileName);
    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 24,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE accounts (id INTEGER PRIMARY KEY, name TEXT);');
          await db.execute('CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT);');
          await db.execute('CREATE TABLE transactions (id INTEGER PRIMARY KEY, amount REAL);');
          await db.execute('CREATE TABLE fixed_expenses (id TEXT PRIMARY KEY, name TEXT);');
          await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY, name TEXT);');
          await db.execute('CREATE TABLE reminders (id TEXT PRIMARY KEY, title TEXT);');

          // Insertar datos sintéticos de prueba
          await db.insert('accounts', {'id': 1, 'name': 'Cuenta Principal'});
          await db.insert('categories', {'id': 1, 'name': 'Comida'});
          await db.insert('transactions', {'id': 1, 'amount': 150.50});
          await db.insert('fixed_expenses', {'id': 'FE1', 'name': 'Internet'});
          await db.insert('goals', {'id': 'G1', 'name': 'Ahorro Auto'});
          await db.insert('reminders', {'id': 'R1', 'title': 'Pagar Tarjeta'});
        },
      ),
    );
    await db.close();
    return dbPath;
  }

  group('DatabaseEncryptionMigrationService — Ciclo de Migración y Recuperación (13B-05)', () {
    test('1. Flujo completo exitoso: exportación, validación, swap atómico, commit, cleanup de fallback y marker', () async {
      final sourcePath = await createSyntheticV24Database('gestor_gastos_source.db');
      final paths = MigrationPaths(
        sourcePath: sourcePath,
        markerPath: p.join(tempDir.path, 'gestor_gastos.migration.pending'),
        stagingPath: p.join(tempDir.path, 'gestor_gastos.db.staging'),
        fallbackPath: p.join(tempDir.path, 'gestor_gastos.db.pre_cipher_backup'),
      );

      const testKey = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      final result = await migrationService.migrate(
        paths: paths,
        testKey: testKey,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dbPath, equals(sourcePath));
      expect(result.fallbackPath, isNull);
      expect(result.migratedCounts['accounts'], equals(1));
      expect(result.migratedCounts['transactions'], equals(1));
      expect(result.migratedCounts['categories'], equals(1));

      // Verificación de archivos resultantes:
      expect(await File(paths.sourcePath).exists(), isTrue); // Destino promovido
      expect(await File(paths.fallbackPath).exists(), isFalse); // Fallback eliminado tras commit
      expect(await File(paths.stagingPath).exists(), isFalse); // Staging eliminado
      expect(await File(paths.markerPath).exists(), isFalse); // Marcador eliminado
    });

    test('2. Recuperación CASO A: Fallo antes del swap (fallback no existe) -> aborta y limpia staging', () async {
      final sourcePath = await createSyntheticV24Database('test_case_a.db');
      final paths = MigrationPaths(
        sourcePath: sourcePath,
        markerPath: p.join(tempDir.path, 'case_a.migration.pending'),
        stagingPath: p.join(tempDir.path, 'case_a.staging'),
        fallbackPath: p.join(tempDir.path, 'case_a.pre_cipher_backup'),
      );

      // Simular crash antes del swap: crear staging y marcador
      await File(paths.markerPath).writeAsString('{"stage":"${MigrationStage.exportPending}"}');
      await File(paths.stagingPath).writeAsString('staging_incompleto');

      final recovery = await migrationService.recover(paths: paths);

      expect(recovery.action, equals(RecoveryActionTaken.abortedAndCleanedUp));
      expect(await File(paths.sourcePath).exists(), isTrue);
      expect(await File(paths.stagingPath).exists(), isFalse); // Staging eliminado
      expect(await File(paths.markerPath).exists(), isFalse); // Marcador eliminado
    });

    test('3. Recuperación CASO B: Fallo durante swap (fallback existe, source no) -> rollback al fallback', () async {
      final sourcePath = p.join(tempDir.path, 'test_case_b.db');
      final fallbackPath = p.join(tempDir.path, 'case_b.pre_cipher_backup');
      final stagingPath = p.join(tempDir.path, 'case_b.staging');
      final markerPath = p.join(tempDir.path, 'case_b.migration.pending');

      final paths = MigrationPaths(
        sourcePath: sourcePath,
        markerPath: markerPath,
        stagingPath: stagingPath,
        fallbackPath: fallbackPath,
      );

      // Simular estado de crash: source no existe, fallback sí existe con la DB original
      await createSyntheticV24Database('case_b.pre_cipher_backup');
      await File(stagingPath).writeAsString('staging_residual');
      await File(markerPath).writeAsString('{"stage":"${MigrationStage.readyToSwap}"}');

      final recovery = await migrationService.recover(paths: paths);

      expect(recovery.action, equals(RecoveryActionTaken.rolledBackToUnencrypted));
      expect(await File(sourcePath).exists(), isTrue); // Restaurado
      expect(await File(fallbackPath).exists(), isFalse);
      expect(await File(stagingPath).exists(), isFalse);
      expect(await File(markerPath).exists(), isFalse);
    });

    test('4. Recuperación CASO C: Ambos existen y source es válido -> confirma migración y limpia fallback', () async {
      final sourcePath = await createSyntheticV24Database('test_case_c.db');
      final fallbackPath = p.join(tempDir.path, 'case_c.pre_cipher_backup');
      final markerPath = p.join(tempDir.path, 'case_c.migration.pending');

      final paths = MigrationPaths(
        sourcePath: sourcePath,
        markerPath: markerPath,
        fallbackPath: fallbackPath,
      );

      await File(fallbackPath).writeAsString('backup_original');
      await File(markerPath).writeAsString('{"stage":"${MigrationStage.readyToSwap}"}');

      const key = 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

      final recovery = await migrationService.recover(
        paths: paths,
        encryptionKey: key,
      );

      expect(recovery.action, equals(RecoveryActionTaken.migrationConfirmedAndCompleted));
      expect(await File(sourcePath).exists(), isTrue);
      expect(await File(fallbackPath).exists(), isFalse); // Fallback limpiado tras confirmar
      expect(await File(markerPath).exists(), isFalse);
    });

    test('5. Recuperación CASO C con source corrupto: rollback al fallback y cuarentena', () async {
      final sourcePath = p.join(tempDir.path, 'test_case_c_corrupt.db');
      final fallbackPath = p.join(tempDir.path, 'case_c_corrupt.pre_cipher_backup');
      final markerPath = p.join(tempDir.path, 'case_c_corrupt.migration.pending');

      final paths = MigrationPaths(
        sourcePath: sourcePath,
        markerPath: markerPath,
        fallbackPath: fallbackPath,
      );

      // Fallback con base válida
      await createSyntheticV24Database('case_c_corrupt.pre_cipher_backup');
      // Source con datos corruptos
      await File(sourcePath).writeAsString('corrupted_garbage_db');
      await File(markerPath).writeAsString('{"stage":"${MigrationStage.readyToSwap}"}');

      inspector.simulateEncryptedSuccessOnKey = false; // Simular que la inspección rechaza el source corrupto

      final recovery = await migrationService.recover(
        paths: paths,
        encryptionKey: 'valid_key_123',
      );

      expect(recovery.action, equals(RecoveryActionTaken.rolledBackToUnencrypted));
      expect(await File(sourcePath).exists(), isTrue); // Restaurado desde fallback
      expect(await File(markerPath).exists(), isFalse);

      inspector.simulateEncryptedSuccessOnKey = true; // Restaurar estado
    });

    test('6. Marcador activo con clave no disponible: STOP y preservación de ambos archivos', () async {
      final sourcePath = await createSyntheticV24Database('test_no_key.db');
      final fallbackPath = p.join(tempDir.path, 'test_no_key.pre_cipher_backup');
      final markerPath = p.join(tempDir.path, 'test_no_key.migration.pending');

      final paths = MigrationPaths(
        sourcePath: sourcePath,
        markerPath: markerPath,
        fallbackPath: fallbackPath,
      );

      await File(fallbackPath).writeAsString('fallback_data');
      await File(markerPath).writeAsString('{"stage":"${MigrationStage.readyToSwap}"}');

      // Sin clave provista: debe lanzar AmbiguityException y PRESERVAR todo
      expect(
        () => migrationService.recover(paths: paths, encryptionKey: null),
        throwsA(isA<DatabaseMigrationRecoveryAmbiguityException>()),
      );

      expect(await File(sourcePath).exists(), isTrue);
      expect(await File(fallbackPath).exists(), isTrue);
      expect(await File(markerPath).exists(), isTrue); // Marcador intacto
    });

    test('7. Interrupción durante CLEANUP_PENDING: resuelve con clave o detiene sin clave', () async {
      final sourcePath = await createSyntheticV24Database('test_cleanup_pending.db');
      final fallbackPath = p.join(tempDir.path, 'test_cleanup_pending.pre_cipher_backup');
      final markerPath = p.join(tempDir.path, 'test_cleanup_pending.migration.pending');

      final paths = MigrationPaths(
        sourcePath: sourcePath,
        markerPath: markerPath,
        fallbackPath: fallbackPath,
      );

      await File(fallbackPath).writeAsString('fallback_to_clean');
      await File(markerPath).writeAsString('{"stage":"${MigrationStage.cleanupPending}"}');

      // Subcaso A: Sin clave -> STOP y preserva
      expect(
        () => migrationService.recover(paths: paths, encryptionKey: null),
        throwsA(isA<DatabaseMigrationRecoveryAmbiguityException>()),
      );
      expect(await File(fallbackPath).exists(), isTrue);

      // Subcaso B: Con clave -> finaliza limpieza
      const key = 'test_key_cleanup_123';
      final recovery = await migrationService.recover(paths: paths, encryptionKey: key);

      expect(recovery.action, equals(RecoveryActionTaken.migrationConfirmedAndCompleted));
      expect(await File(sourcePath).exists(), isTrue);
      expect(await File(fallbackPath).exists(), isFalse); // Fallback finalmente eliminado
      expect(await File(markerPath).exists(), isFalse); // Marcador resuelto
    });

    test('8. Coordinación con RESTORE: Marcador de RESTORE activo detiene migración y recovery (STOP)', () async {
      final sourcePath = await createSyntheticV24Database('test_conflict.db');
      final paths = MigrationPaths(sourcePath: sourcePath);

      final restoreMarker = File(p.join(tempDir.path, 'gestor_gastos.restore.pending'));
      await restoreMarker.writeAsString('restore_in_progress');

      expect(
        () => migrationService.migrate(paths: paths, testKey: 'key_123'),
        throwsA(isA<DatabaseMigrationRecoveryConflictException>()),
      );

      expect(
        () => migrationService.recover(paths: paths),
        throwsA(isA<DatabaseMigrationRecoveryConflictException>()),
      );
    });

    test('9. Marcadores concurrentes RESTORE y migración simultáneos detiene inmediatamente (STOP)', () async {
      final sourcePath = await createSyntheticV24Database('test_dual_markers.db');
      final paths = MigrationPaths(sourcePath: sourcePath);

      await File(paths.markerPath).writeAsString('{"stage":"${MigrationStage.exportPending}"}');
      await File(p.join(tempDir.path, 'gestor_gastos.restore.pending')).writeAsString('restore');

      expect(
        () => migrationService.recover(paths: paths),
        throwsA(isA<DatabaseMigrationRecoveryConflictException>()),
      );
      // Ningún archivo debe ser alterado
      expect(await File(paths.markerPath).exists(), isTrue);
    });

    test('10. Gestión de archivos auxiliares SQLite sidecars (-wal, -shm, -journal)', () async {
      final sourcePath = await createSyntheticV24Database('test_sidecars.db');
      final paths = MigrationPaths(sourcePath: sourcePath);

      // Preparamos sidecars preexistentes en la ruta de fallback para verificar limpieza profunda
      await File('${paths.fallbackPath}-wal').writeAsString('wal_old');
      await File('${paths.fallbackPath}-shm').writeAsString('shm_old');
      await File('${paths.fallbackPath}-journal').writeAsString('journal_old');

      const testKey = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      final result = await migrationService.migrate(
        paths: paths,
        testKey: testKey,
      );

      expect(result.isSuccess, isTrue);
      // Todos los sidecars del fallback deben haber sido eliminados durante la fase CLEANUP_PENDING
      expect(await File('${paths.fallbackPath}-wal').exists(), isFalse);
      expect(await File('${paths.fallbackPath}-shm').exists(), isFalse);
      expect(await File('${paths.fallbackPath}-journal').exists(), isFalse);
      expect(await File(paths.fallbackPath).exists(), isFalse);
    });

    test('11. Ambigüedad irresoluble: Marcador existe pero ni source ni fallback existen -> STOP y preserva', () async {
      final paths = MigrationPaths(
        sourcePath: p.join(tempDir.path, 'missing_source.db'),
        fallbackPath: p.join(tempDir.path, 'missing_fallback.db'),
        markerPath: p.join(tempDir.path, 'ambiguous.pending'),
      );

      await File(paths.markerPath).writeAsString('{"stage":"unknown"}');

      expect(
        () => migrationService.recover(paths: paths),
        throwsA(isA<DatabaseMigrationRecoveryAmbiguityException>()),
      );

      expect(await File(paths.markerPath).exists(), isTrue);
    });

    test('12. Idempotencia: recover() cuando no hay marcador devuelve noActionNeeded', () async {
      final paths = MigrationPaths(sourcePath: p.join(tempDir.path, 'normal.db'));

      final recovery = await migrationService.recover(paths: paths);

      expect(recovery.action, equals(RecoveryActionTaken.noActionNeeded));
    });
  });
}
