import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:gestor_gastos/core/services/database_helper.dart';
import 'package:gestor_gastos/core/services/restore_service.dart';
import 'package:gestor_gastos/core/errors/backup_exceptions.dart';

void main() {
  late LocalDatabase localDatabase;
  late RestoreService restoreService;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final databasesPath = await getDatabasesPath();
    dbPath = p.join(databasesPath, 'gestor_gastos.db');

    // Limpiar todos los archivos posibles
    final filesToClean = [
      dbPath, '$dbPath.restore', '$dbPath.fallback', 
      '$dbPath-journal', '$dbPath-wal', '$dbPath-shm',
      p.join(databasesPath, 'gestor_gastos.restore.pending')
    ];
    for (var f in filesToClean) {
      if (await File(f).exists()) await File(f).delete();
    }

    localDatabase = LocalDatabase();
    restoreService = RestoreService(localDatabase: localDatabase);
  });

  tearDown(() async {
    await localDatabase.closeAndRelease();
  });

  Future<String> createValidMockDatabase({int version = 24}) async {
    final path = p.join(await getDatabasesPath(), 'mock_candidate.db');
    if (await File(path).exists()) await File(path).delete();

    final db = await openDatabase(path, version: version, onCreate: (db, v) async {
      await db.execute('CREATE TABLE accounts(id INTEGER PRIMARY KEY);');
      await db.execute('CREATE TABLE categories(id INTEGER PRIMARY KEY);');
      await db.execute('CREATE TABLE transactions(id INTEGER PRIMARY KEY);');
    });
    await db.close();
    return path;
  }

  test('DB misma versión -> restore', () async {
    // Inicializar db productiva primero
    await localDatabase.database;
    final candidatePath = await createValidMockDatabase();

    await restoreService.restoreDatabase(candidatePath);

    // Marker y fallback deben haber sido eliminados
    expect(await File('$dbPath.fallback').exists(), isFalse);
    expect(await File(p.join(await getDatabasesPath(), 'gestor_gastos.restore.pending')).exists(), isFalse);
    
    // Y la base debe estar utilizable
    final db = await localDatabase.database;
    final accounts = await db.query('accounts');
    expect(accounts, isList);
  });

  test('DB corrupta -> rechazo (InvalidDatabaseException)', () async {
    await localDatabase.database;
    final candidatePath = p.join(await getDatabasesPath(), 'mock_corrupt.db');
    await File(candidatePath).writeAsString('esto no es sqlite');

    expect(
      () => restoreService.restoreDatabase(candidatePath),
      throwsA(isA<InvalidDatabaseException>()),
    );
    expect(await File(dbPath).exists(), isTrue); // Producción sigue viva
  });

  test('DB futura -> rechazo (IncompatibleSchemaException)', () async {
    await localDatabase.database;
    final candidatePath = await createValidMockDatabase(version: 999);

    expect(
      () => restoreService.restoreDatabase(candidatePath),
      throwsA(isA<IncompatibleSchemaException>()),
    );
  });

  test('SQLite ajena (sin tabla accounts) -> rechazo', () async {
    await localDatabase.database;
    final candidatePath = p.join(await getDatabasesPath(), 'mock_other.db');
    if (await File(candidatePath).exists()) await File(candidatePath).delete();
    final db = await openDatabase(candidatePath, version: 1, onCreate: (db, v) async {
      await db.execute('CREATE TABLE random(id INTEGER);');
    });
    await db.close();

    expect(
      () => restoreService.restoreDatabase(candidatePath),
      throwsA(isA<InvalidDatabaseException>().having((e) => e.message, 'msg', contains('Tablas principales ausentes'))),
    );
  });

  test('Process-death: marker + fallback + production ausente -> recovery', () async {
    await localDatabase.database; // Inicializa y crea el real
    await localDatabase.closeAndRelease(); // Simular fin

    // Escenario: Se movió productiva a fallback y murió
    await File(dbPath).rename('$dbPath.fallback');
    await File(p.join(await getDatabasesPath(), 'gestor_gastos.restore.pending')).writeAsString('pending');

    expect(await File(dbPath).exists(), isFalse);
    
    // Esto disparará la recuperación en el inicio
    final db = await localDatabase.database;
    
    expect(await File(dbPath).exists(), isTrue);
    expect(await File('$dbPath.fallback').exists(), isFalse); // Fallback consumido
    expect(await File(p.join(await getDatabasesPath(), 'gestor_gastos.restore.pending')).exists(), isFalse); // marker borrado
    
    final res = await db.rawQuery('PRAGMA user_version;');
    expect(res.first.values.first, 24);
  });

  test('Process-death: marker + fallback + production existente -> rollback', () async {
    await localDatabase.database; 
    await localDatabase.closeAndRelease();

    // Escenario: El swap completó pero no se eliminó fallback ni marker
    // Significa que pudo estar corrupto
    await File(dbPath).copy('$dbPath.fallback');
    await File(p.join(await getDatabasesPath(), 'gestor_gastos.restore.pending')).writeAsString('pending');

    // Alterar producción
    final badDb = await openDatabase(dbPath, singleInstance: false);
    await badDb.execute('DROP TABLE accounts');
    await badDb.close();

    // Iniciar DB -> debe detectar y hacer rollback
    final db = await localDatabase.database;
    
    // Accounts debe volver a existir tras el rollback automático del crash recovery
    final tablesQuery = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
    final tables = tablesQuery.map((row) => row['name'] as String).toList();
    expect(tables, contains('accounts'));
  });



  test('A. Restore exitoso limpia todos los artefactos', () async {
    await localDatabase.database;
    final candidatePath = await createValidMockDatabase();

    await restoreService.restoreDatabase(candidatePath);

    expect(await File(dbPath).exists(), isTrue);
    expect(await File('$dbPath.fallback').exists(), isFalse);
    expect(await File('$dbPath.restore').exists(), isFalse);
    expect(await File(p.join(await getDatabasesPath(), 'gestor_gastos.restore.pending')).exists(), isFalse);
  });

  test('B y C. Fallo al reabrir la DB restaurada -> rollback', () async {
    final mockDb = _MockTestLocalDatabase();
    await mockDb.database;
    final restoreSvc = RestoreService(localDatabase: mockDb);
    
    final candidatePath = await createValidMockDatabase();
    mockDb.failReopen = true;

    expect(
      () => restoreSvc.restoreDatabase(candidatePath),
      throwsA(isA<RestoreFailedException>()),
    );

    // Debe existir la productiva intacta
    expect(await File(dbPath).exists(), isTrue);
    // El fallback debió volver a su lugar
    expect(await File('$dbPath.fallback').exists(), isFalse);
    
    await mockDb.closeAndRelease();
  });

  test('D. Fallo durante migración de backup antiguo -> rollback', () async {
    final mockDb = _MockTestLocalDatabase();
    await mockDb.database;
    final restoreSvc = RestoreService(localDatabase: mockDb);
    
    final candidatePath = await createValidMockDatabase(version: 22);
    // Simulamos que al abrir para migrar, sqflite lanza un error de migracion
    mockDb.failReopen = true;

    expect(
      () => restoreSvc.restoreDatabase(candidatePath),
      throwsA(isA<RestoreFailedException>()),
    );

    expect(await File(dbPath).exists(), isTrue);
    expect(await File('$dbPath.fallback').exists(), isFalse);
    
    await mockDb.closeAndRelease();
  });

  test('E. Health check post-restore falla -> rollback', () async {
    final mockDb = _MockTestLocalDatabase();
    await mockDb.database;
    final restoreSvc = RestoreService(localDatabase: mockDb);
    
    final candidatePath = await createValidMockDatabase();
    mockDb.failHealthCheck = true; // Forzará user_version = 0 post-swap

    expect(
      () => restoreSvc.restoreDatabase(candidatePath),
      throwsA(isA<RestoreFailedException>()),
    );

    expect(await File(dbPath).exists(), isTrue);
    expect(await File('$dbPath.fallback').exists(), isFalse);
    
    await mockDb.closeAndRelease();
  });

  test('F. RollbackFailedException', () async {
    final mockDb = _MockTestLocalDatabase();
    await mockDb.database;
    final restoreSvc = RestoreService(localDatabase: mockDb);
    
    final candidatePath = await createValidMockDatabase();
    mockDb.failReopen = true; // Fallamos en swap
    mockDb.lockFallback = true; // Bloqueamos el fallback para evitar rename

    try {
      await restoreSvc.restoreDatabase(candidatePath);
      fail('Debió lanzar RollbackFailedException');
    } catch (e) {
      expect(e, isA<RollbackFailedException>());
    }

    await mockDb.unlock();
    await mockDb.closeAndRelease();
  });

  test('G. Restore concurrente rechaza con excepción', () async {
    await localDatabase.database;
    final candidatePath = await createValidMockDatabase();
    final candidatePath2 = await createValidMockDatabase();

    // Lanzar dos simultaneamente
    final future1 = restoreService.restoreDatabase(candidatePath);
    final future2 = restoreService.restoreDatabase(candidatePath2);

    try {
      await Future.wait([future1, future2]);
      fail('Debió rechazar la concurrencia');
    } catch (e) {
      expect(e, isA<RestoreFailedException>().having((e) => e.message, 'msg', contains('Ya hay una restauración en progreso.')));
    }

    expect(await File(dbPath).exists(), isTrue);
  });

  test('H. Backup antiguo exitoso', () async {
    await localDatabase.database;
    // v22 valida sin tabla reminders
    final candidatePath = await createValidMockDatabase(version: 22);

    await restoreService.restoreDatabase(candidatePath);

    final db = await localDatabase.database;
    final res = await db.rawQuery('PRAGMA user_version;');
    expect(res.first.values.first, 24);
  });

  test('I. Limpieza de auxiliares', () async {
    await localDatabase.database;
    await localDatabase.closeAndRelease();

    await File('$dbPath-journal').writeAsString('fake');
    await File('$dbPath-wal').writeAsString('fake');
    await File('$dbPath-shm').writeAsString('fake');

    await File(dbPath).rename('$dbPath.fallback');
    await File(p.join(await getDatabasesPath(), 'gestor_gastos.restore.pending')).writeAsString('pending');

    await localDatabase.database; // Dispara recovery

    expect(await File('$dbPath-journal').exists(), isFalse);
    expect(await File('$dbPath-wal').exists(), isFalse);
    expect(await File('$dbPath-shm').exists(), isFalse);
  });

  test('J. .restore residual se limpia', () async {
    await localDatabase.database;
    final candidatePath = await createValidMockDatabase();
    
    await File('$dbPath.restore').writeAsString('basura');

    await restoreService.restoreDatabase(candidatePath);

    expect(await File('$dbPath.restore').exists(), isFalse);
  });

  test('REGRESIÓN: restoreDatabase instala y commitea datos reales (sentinel OLD -> NEW) sin rollback prematuro', () async {
    final activeDb = await localDatabase.database;
    await activeDb.execute(
      "INSERT INTO accounts(name, type, balance) VALUES('SENTINEL_OLD', 'CASH', 100.0);",
    );
    final activeRowsBefore = await activeDb.query('accounts');
    expect(activeRowsBefore.any((r) => r['name'] == 'SENTINEL_OLD'), isTrue);

    final candidatePath = p.join(await getDatabasesPath(), 'candidate_sentinel.db');
    if (await File(candidatePath).exists()) await File(candidatePath).delete();
    final candDb = await openDatabase(
      candidatePath,
      version: 24,
      onCreate: (db, v) async {
        await db.execute('CREATE TABLE accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, type TEXT NOT NULL, balance REAL DEFAULT 0.0, color INTEGER, currencySymbol TEXT, iconCode INTEGER, includeInTotal INTEGER);');
        await db.execute('CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, icon TEXT NOT NULL, color INTEGER NOT NULL, type TEXT NOT NULL);');
        await db.execute('CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL NOT NULL, date INTEGER NOT NULL, categoryId INTEGER NOT NULL, type TEXT NOT NULL, accountId INTEGER NOT NULL, destinationAccountId INTEGER, description TEXT, imagePath TEXT, subscriptionId TEXT, isPaid INTEGER DEFAULT 1);');
        await db.execute(
          "INSERT INTO accounts(name, type, balance) VALUES('SENTINEL_NEW', 'CASH', 777.0);",
        );
      },
    );
    await candDb.close();

    await restoreService.restoreDatabase(candidatePath);

    expect(await File('$dbPath.fallback').exists(), isFalse);
    expect(await File(p.join(await getDatabasesPath(), 'gestor_gastos.restore.pending')).exists(), isFalse);

    final activeDbAfter = await localDatabase.database;
    final activeRowsAfter = await activeDbAfter.query('accounts');
    expect(activeRowsAfter.any((r) => r['name'] == 'SENTINEL_NEW'), isTrue);
    expect(activeRowsAfter.any((r) => r['name'] == 'SENTINEL_OLD'), isFalse);
    final restoredAccount = activeRowsAfter.firstWhere((r) => r['name'] == 'SENTINEL_NEW');
    expect(restoredAccount['balance'], 777.0);
  });

  test('Process-death: marker + no fallback + producción sana -> producción se conserva y marker se resuelve', () async {
    final dbInit = await localDatabase.database;
    await dbInit.execute(
      "INSERT INTO accounts(name, type, balance) VALUES('PRODUCTION_HEALTHY', 'CASH', 300.0);",
    );
    await localDatabase.closeAndRelease();

    await File(p.join(await getDatabasesPath(), 'gestor_gastos.restore.pending')).writeAsString('pending');
    expect(await File('$dbPath.fallback').exists(), isFalse);

    final db = await localDatabase.database;

    expect(await File(p.join(await getDatabasesPath(), 'gestor_gastos.restore.pending')).exists(), isFalse);
    final rows = await db.query('accounts');
    expect(rows.any((r) => r['name'] == 'PRODUCTION_HEALTHY'), isTrue);
  });

  test('Defensa: forceOpenPendingRestore sin marker activo lanza StateError', () async {
    expect(
      () => localDatabase.forceOpenPendingRestore(),
      throwsStateError,
    );
  });
}


class _MockTestLocalDatabase implements LocalDatabase {
  final LocalDatabase real = LocalDatabase();
  bool failReopen = false;
  bool failHealthCheck = false;
  bool lockFallback = false;
  RandomAccessFile? _lockedRaf;

  @override
  Future<Database> get database => real.database;

  @override
  Future<void> clearAllTables() => real.clearAllTables();

  @override
  Future<void> closeAndRelease() => real.closeAndRelease();

  @override
  Future<T> executeMaintenance<T>(Future<T> Function() operation) => real.executeMaintenance(operation);

  @override
  Future<Database> forceOpen() => real.forceOpen();

  @override
  Future<Database> forceOpenPendingRestore() async {
    if (lockFallback) {
      final fallbackFile = File(p.join(await getDatabasesPath(), 'gestor_gastos.db.fallback'));
      if (await fallbackFile.exists()) {
        _lockedRaf = await fallbackFile.open(mode: FileMode.write);
        await _lockedRaf!.lock();
      }
    }

    if (failReopen) throw Exception('Simulated reopen failure');
    final db = await real.forceOpenPendingRestore();
    if (failHealthCheck) {
      await db.rawQuery('PRAGMA user_version = 0;');
    }
    return db;
  }

  Future<void> unlock() async {
    if (_lockedRaf != null) {
      await _lockedRaf!.unlock();
      await _lockedRaf!.close();
      _lockedRaf = null;
    }
  }
}
