// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gestor_gastos/core/services/database_encryption_migration_service.dart';
import 'package:gestor_gastos/core/services/database_physical_inspector.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Running Native Migration Test...')))));

  print('===============================================================');
  print('INICIANDO VALIDACIÓN NATIVA REAL DE SQLCIPHER EN ANDROID (13B-05)');
  print('===============================================================');

  try {
    final databasesDirPath = await sqflite.getDatabasesPath();
    final uniqueTimestamp = DateTime.now().millisecondsSinceEpoch;
    final testDbPath = p.join(databasesDirPath, 'test_native_v24_$uniqueTimestamp.db');

    final paths = MigrationPaths(
      sourcePath: testDbPath,
      markerPath: p.join(databasesDirPath, 'test_native_v24_$uniqueTimestamp.db.migration.pending'),
      stagingPath: p.join(databasesDirPath, 'test_native_v24_$uniqueTimestamp.db.staging'),
      fallbackPath: p.join(databasesDirPath, 'test_native_v24_$uniqueTimestamp.db.pre_cipher_backup'),
    );

    print('[1] Creando SQLite plana estándar v24 con datos sintéticos...');
    final setupDb = await sqflite.openDatabase(
      paths.sourcePath,
      version: 24,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE accounts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL CHECK(type IN ('CASH', 'DIGITAL')),
            balance REAL DEFAULT 0.0,
            color INTEGER,
            currencySymbol TEXT DEFAULT 'S/',
            iconCode INTEGER DEFAULT 58343,
            includeInTotal INTEGER DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            icon TEXT,
            color INTEGER,
            type TEXT NOT NULL CHECK(type IN ('EXPENSE', 'INCOME')),
            is_editable INTEGER DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            accountId INTEGER NOT NULL,
            categoryId INTEGER NOT NULL,
            amount REAL NOT NULL,
            date TEXT NOT NULL,
            description TEXT,
            note TEXT,
            type TEXT DEFAULT 'EXPENSE',
            destinationAccountId INTEGER,
            receivedAmount REAL,
            imagePath TEXT,
            iconCode INTEGER,
            colorValue INTEGER,
            subscriptionId TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE fixed_expenses(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            amount REAL NOT NULL,
            paymentDate TEXT NOT NULL,
            frequency INTEGER NOT NULL,
            isPaid INTEGER DEFAULT 0,
            custom_icon TEXT,
            custom_color INTEGER,
            accountToCharge INTEGER,
            categoryId INTEGER NOT NULL,
            orderIndex INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE goals(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            targetAmount REAL NOT NULL,
            currentAmount REAL DEFAULT 0.0,
            iconCode INTEGER,
            iconName TEXT,
            colorValue INTEGER,
            isCompleted INTEGER DEFAULT 0,
            deadline TEXT,
            accountId INTEGER,
            categoryId INTEGER,
            orderIndex INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE reminders(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            type TEXT NOT NULL,
            amount REAL,
            currencyCode TEXT,
            categoryId INTEGER,
            date TEXT NOT NULL,
            hour INTEGER NOT NULL,
            minute INTEGER NOT NULL,
            recurrence TEXT NOT NULL,
            active INTEGER NOT NULL DEFAULT 1,
            completedAt TEXT,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');

        await db.insert('accounts', {'name': 'Efectivo Personal', 'type': 'CASH', 'balance': 250.75});
        await db.insert('categories', {'name': 'Alimentos', 'icon': 'fastfood', 'color': 4294198070, 'type': 'EXPENSE'});
        await db.insert('transactions', {
          'accountId': 1,
          'categoryId': 1,
          'amount': 35.0,
          'date': '2026-10-11T14:30:00Z',
          'description': 'Compra mercado',
        });
        await db.insert('fixed_expenses', {'id': 'fe_01', 'name': 'Internet', 'amount': 79.9, 'paymentDate': '2026-10-20', 'frequency': 1, 'categoryId': 1});
        await db.insert('goals', {'id': 'g_01', 'name': 'Laptop', 'targetAmount': 3500.0, 'currentAmount': 500.0});
        await db.insert('reminders', {
          'id': 'rem_01',
          'title': 'Pagar servicio',
          'type': 'BILL',
          'date': '2026-10-20',
          'hour': 10,
          'minute': 0,
          'recurrence': 'MONTHLY',
          'active': 1,
          'createdAt': '2026-10-11T12:00:00Z',
          'updatedAt': '2026-10-11T12:00:00Z',
        });
      },
    );
    await setupDb.close();
    print('[1] OK: Base origen v24 creada en: ${paths.sourcePath}');

    print('[2] Ejecutando inspección física previa...');
    const inspector = DatabasePhysicalInspector();
    final inspectionReport = await inspector.inspect(dbPath: paths.sourcePath);
    print('[2] Inspección completada: ${inspectionReport.status}');
    if (!inspectionReport.isMigratableV24) {
      throw Exception('Inspección falló: ${inspectionReport.failureReason}');
    }

    const testSecretKey = 'a1b2c3d4e5f67890123456789abcdef0a1b2c3d4e5f67890123456789abcdef0';
    print('[3] Ejecutando migración in-place vía sqlcipher_export...');
    final migrationService = DatabaseEncryptionMigrationService(
      inspector: inspector,
      executor: SqlCipherMigrationDatabaseExecutor(),
    );

    final result = await migrationService.migrate(
      paths: paths,
      testKey: testSecretKey,
    );
    print('[3] Migración completada con éxito: ${result.isSuccess} en ${result.elapsed.inMilliseconds}ms');
    print('    Conteos migrados: ${result.migratedCounts}');

    print('[4] Verificando rechazo de SQLite estándar en el archivo cifrado...');
    bool standardSqliteRejected = false;
    try {
      final stdDb = await sqflite.openDatabase(paths.sourcePath, readOnly: true);
      await stdDb.rawQuery('SELECT count(*) FROM accounts;');
      await stdDb.close();
    } catch (e) {
      standardSqliteRejected = true;
      print('    SQLite estándar rechazó correctamente el archivo cifrado: $e');
    }
    if (!standardSqliteRejected) {
      throw Exception('ERROR CRÍTICO: SQLite estándar pudo leer la base cifrada sin contraseña!');
    }

    print('[5] Verificando rechazo de SQLCipher ante clave incorrecta...');
    bool wrongKeyRejected = false;
    try {
      final wrongDb = await sqlcipher.openDatabase(
        paths.sourcePath,
        password: 'badbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbadbad',
        readOnly: true,
      );
      await wrongDb.rawQuery('SELECT count(*) FROM accounts;');
      await wrongDb.close();
    } catch (e) {
      wrongKeyRejected = true;
      print('    SQLCipher con clave incorrecta rechazó correctamente: $e');
    }
    if (!wrongKeyRejected) {
      throw Exception('ERROR CRÍTICO: SQLCipher con clave incorrecta leyó la base de datos!');
    }

    print('[6] Reabriendo con SQLCipher y clave correcta...');
    final okDb = await sqlcipher.openDatabase(
      paths.sourcePath,
      password: testSecretKey,
      readOnly: true,
    );

    final quickCheck = await okDb.rawQuery('PRAGMA quick_check;');
    print('    PRAGMA quick_check: ${quickCheck.first.values.first}');
    if (quickCheck.first.values.first.toString().toLowerCase() != 'ok') {
      throw Exception('PRAGMA quick_check no retornó ok');
    }

    final versionRes = await okDb.rawQuery('PRAGMA user_version;');
    final version = versionRes.first.values.first as int;
    print('    PRAGMA user_version: $version');
    if (version != 24) {
      throw Exception('user_version no es 24 (es $version)');
    }

    final accounts = await okDb.query('accounts');
    print('    Cuentas leídas: ${accounts.length}, Nombre: ${accounts.first['name']}, Saldo: ${accounts.first['balance']}');
    final txs = await okDb.query('transactions');
    print('    Transacciones leídas: ${txs.length}, Monto: ${txs.first['amount']}');
    await okDb.close();

    print('[7] Verificando eliminación segura del fallback no cifrado tras commit...');
    final fallbackExists = await File(paths.fallbackPath).exists();
    print('    Fallback no cifrado existe: $fallbackExists (esperado: false tras cleanup exitoso)');
    if (fallbackExists) {
      throw Exception('El fallback pre_cipher_backup no fue eliminado tras commit!');
    }
    final markerExists = await File(paths.markerPath).exists();
    print('    Marcador existe: $markerExists (esperado: false tras cleanup exitoso)');
    if (markerExists) {
      throw Exception('El marcador de migración no fue eliminado!');
    }

    print('[8] Verificando crash recovery nativo en emulador (simulación de CASO B)...');
    final testCaseBPath = p.join(databasesDirPath, 'test_native_case_b_$uniqueTimestamp.db');
    final testCaseBFallback = p.join(databasesDirPath, 'test_native_case_b_$uniqueTimestamp.db.pre_cipher_backup');
    final testCaseBMarker = p.join(databasesDirPath, 'test_native_case_b_$uniqueTimestamp.db.migration.pending');
    final testCaseBStaging = p.join(databasesDirPath, 'test_native_case_b_$uniqueTimestamp.db.staging');
    final caseBPaths = MigrationPaths(
      sourcePath: testCaseBPath,
      fallbackPath: testCaseBFallback,
      markerPath: testCaseBMarker,
      stagingPath: testCaseBStaging,
    );

    final caseBDb = await sqflite.openDatabase(
      caseBPaths.fallbackPath,
      version: 24,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE accounts(id INTEGER PRIMARY KEY, name TEXT);');
        await db.insert('accounts', {'name': 'Recuperada'});
      },
    );
    await caseBDb.close();
    await File(caseBPaths.stagingPath).writeAsString('staging_garbage');
    await File(caseBPaths.markerPath).writeAsString('{"stage":"READY_TO_SWAP"}');

    final recoveryResult = await migrationService.recover(paths: caseBPaths);
    print('    Resultado de recovery nativo: ${recoveryResult.action}');
    if (recoveryResult.action != RecoveryActionTaken.rolledBackToUnencrypted) {
      throw Exception('Recovery nativo falló: no hizo rollback a no cifrado');
    }
    if (!await File(caseBPaths.sourcePath).exists()) {
      throw Exception('El archivo source no fue restaurado en recovery nativo');
    }
    if (await File(caseBPaths.fallbackPath).exists() ||
        await File(caseBPaths.stagingPath).exists() ||
        await File(caseBPaths.markerPath).exists()) {
      throw Exception('Artefactos residuales quedaron tras recovery nativo');
    }

    // Limpieza de archivos de prueba
    await File(caseBPaths.sourcePath).delete();
    await File(paths.sourcePath).delete();

    print('===============================================================');
    print('¡VALIDACIÓN NATIVA REAL DE SQLCIPHER Y RECOVERY COMPLETADA 100%!');
    print('===============================================================');

    exit(0);
  } catch (e, stack) {
    print('FATAL ERROR EN VALIDACIÓN NATIVA: $e');
    print(stack);
    exit(1);
  }
}
