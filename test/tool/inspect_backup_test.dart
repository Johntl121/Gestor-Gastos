import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gestor_gastos/core/services/backup_crypto_service.dart';
import '../../tool/inspect_backup.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('InspectBackupTool Tests', () {
    late Directory tempDir;
    const testPassword = 'TestPassword123!';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('inspect_backup_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    /// Crea un archivo .gestorbackup válido para pruebas con datos de fixture controlados.
    Future<String> createTestBackupFile({
      required Directory dir,
      required String password,
      bool includeFixedExpenses = true,
      int accounts = 2,
      int transactions = 3,
    }) async {
      final stagingDir = Directory(p.join(dir.path, 'staging'));
      await stagingDir.create(recursive: true);

      // 1. Crear SQLite DB real
      final dbPath = p.join(stagingDir.path, 'gestor_gastos.db');
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 24,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE accounts(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                type TEXT NOT NULL,
                balance REAL DEFAULT 0.0
              )
            ''');
            await db.execute('''
              CREATE TABLE categories(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                type TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE transactions(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                accountId INTEGER NOT NULL,
                categoryId INTEGER NOT NULL,
                amount REAL NOT NULL,
                date TEXT NOT NULL,
                imagePath TEXT
              )
            ''');

            if (includeFixedExpenses) {
              await db.execute('''
                CREATE TABLE fixed_expenses(
                  id TEXT PRIMARY KEY,
                  name TEXT NOT NULL,
                  amount REAL NOT NULL
                )
              ''');
            }
            await db.execute('''
              CREATE TABLE goals(
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                targetAmount REAL NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE reminders(
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                type TEXT NOT NULL
              )
            ''');
          },
        ),
      );

      // Insertar datos de fixture
      for (int i = 1; i <= accounts; i++) {
        await db.insert('accounts', {'name': 'Cuenta $i', 'type': 'CASH', 'balance': 100.0 * i});
      }
      for (int i = 1; i <= 4; i++) {
        await db.insert('categories', {'name': 'Cat $i', 'type': 'EXPENSE'});
      }
      for (int i = 1; i <= transactions; i++) {
        await db.insert('transactions', {
          'accountId': 1,
          'categoryId': 1,
          'amount': 25.0 * i,
          'date': '2026-10-0${i}T12:00:00Z',
          'imagePath': i == 1 ? 'attachments/transactions/recibo_01.jpg' : null,
        });
      }
      if (includeFixedExpenses) {
        await db.insert('fixed_expenses', {'id': 'fe_1', 'name': 'Internet', 'amount': 80.0});
      }
      await db.insert('goals', {'id': 'g_1', 'name': 'Ahorro', 'targetAmount': 500.0});
      await db.insert('reminders', {'id': 'r_1', 'title': 'Pagar servicio', 'type': 'BILL'});

      await db.close();

      // 2. Crear adjunto físico
      final attFile = File(p.join(stagingDir.path, 'attachments', 'transactions', 'recibo_01.jpg'));
      await attFile.parent.create(recursive: true);
      await attFile.writeAsBytes(utf8.encode('fake image bytes'));

      // 3. Crear manifest.json
      final manifestMap = {
        'payloadVersion': 1,
        'appVersion': '1.0.0+1',
        'databaseSchemaVersion': 24,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'components': ['database', 'preferences', 'transactionAttachments'],
        'transactionAttachmentsIncluded': 1,
        'transactionAttachmentsMissing': 0,
      };
      final manifestFile = File(p.join(stagingDir.path, 'manifest.json'));
      await manifestFile.writeAsString(jsonEncode(manifestMap));

      // 4. Crear preferences.json
      final prefsMap = {
        'FIRST_TIME': false,
        'USER_NAME': 'Test User',
        'CURRENCY': 'PEN',
      };
      final prefsFile = File(p.join(stagingDir.path, 'preferences.json'));
      await prefsFile.writeAsString(jsonEncode(prefsMap));

      // 5. Empaquetar ZIP en memoria
      final archive = Archive();
      final dbBytes = await File(dbPath).readAsBytes();
      archive.addFile(ArchiveFile('gestor_gastos.db', dbBytes.length, dbBytes));
      archive.addFile(ArchiveFile('manifest.json', manifestFile.readAsBytesSync().length, manifestFile.readAsBytesSync()));
      archive.addFile(ArchiveFile('preferences.json', prefsFile.readAsBytesSync().length, prefsFile.readAsBytesSync()));
      final attBytes = await attFile.readAsBytes();
      archive.addFile(ArchiveFile('attachments/transactions/recibo_01.jpg', attBytes.length, attBytes));

      final zipBytes = ZipEncoder().encode(archive);

      // 6. Cifrar con BackupCryptoService productivo
      final crypto = BackupCryptoService();
      final encryptedBytes = await crypto.encrypt(Uint8List.fromList(zipBytes), password);

      final finalBackupPath = p.join(dir.path, 'test_backup.gestorbackup');
      await File(finalBackupPath).writeAsBytes(encryptedBytes);
      return finalBackupPath;
    }

    test('1. Inspección exitosa de un fixture válido con conteos exactos e integridad OK', () async {
      final backupPath = await createTestBackupFile(
        dir: tempDir,
        password: testPassword,
        accounts: 2,
        transactions: 3,
      );

      final result = await inspectBackupFile(
        backupPath: backupPath,
        password: testPassword,
      );

      expect(result.authSuccess, isTrue);
      expect(result.formatSuccess, isTrue);
      expect(result.quickCheckPassed, isTrue);
      expect(result.quickCheckResult?.toLowerCase(), equals('ok'));
      expect(result.dbSchemaVersion, equals(24));
      expect(result.manifestPayloadVersion, equals(1));
      expect(result.manifestAppVersion, equals('1.0.0+1'));
      expect(result.manifestSchemaVersion, equals(24));
      expect(result.preferencesCount, equals(3));

      // Tablas detectadas
      expect(result.detectedTables, containsAll(['accounts', 'categories', 'transactions', 'fixed_expenses', 'goals', 'reminders']));

      // Conteos de entidades
      expect(result.accountsCount, equals(2));
      expect(result.transactionsCount, equals(3));
      expect(result.categoriesCount, equals(4));
      expect(result.goalsCount, equals(1));
      expect(result.fixedExpensesCount, equals(1));
      expect(result.remindersCount, equals(1));

      // Adjuntos
      expect(result.transactionAttachmentRefsCount, equals(1));
      expect(result.physicalAttachmentsCount, equals(1));

      expect(result.isFullyValid, isTrue);
    });

    test('2. Contraseña incorrecta devuelve autenticación fallida sin crash', () async {
      final backupPath = await createTestBackupFile(
        dir: tempDir,
        password: testPassword,
      );

      final result = await inspectBackupFile(
        backupPath: backupPath,
        password: 'WrongPassword!',
      );

      expect(result.authSuccess, isFalse);
      expect(result.formatSuccess, isTrue);
      expect(result.authError, contains('No se pudo desbloquear la copia de seguridad.'));
      expect(result.accountsCount, isNull);
      expect(result.transactionsCount, isNull);
      expect(result.quickCheckPassed, isNull);
    });

    test('3. Archivo dañado o truncado devuelve fallo de formato sin crash', () async {
      final corruptedPath = p.join(tempDir.path, 'corrupted.gestorbackup');
      // Escribir bytes no correspondientes al formato GGBK V1
      await File(corruptedPath).writeAsBytes([0x00, 0x01, 0x02, 0x03, 0x04]);

      final result = await inspectBackupFile(
        backupPath: corruptedPath,
        password: testPassword,
      );

      expect(result.authSuccess, isFalse);
      expect(result.formatSuccess, isFalse);
      expect(result.formatError, isNotNull);
      expect(result.accountsCount, isNull);
    });

    test('4. Archivo con tabla opcional ausente (ej. fixed_expenses) no falla y la reporta como nula', () async {
      final backupPath = await createTestBackupFile(
        dir: tempDir,
        password: testPassword,
        includeFixedExpenses: false,
        accounts: 1,
        transactions: 1,
      );

      final result = await inspectBackupFile(
        backupPath: backupPath,
        password: testPassword,
      );

      expect(result.authSuccess, isTrue);
      expect(result.formatSuccess, isTrue);
      expect(result.accountsCount, equals(1));
      expect(result.transactionsCount, equals(1));
      expect(result.fixedExpensesCount, isNull); // Tabla no existe en este esquema
      expect(result.detectedTables, isNot(contains('fixed_expenses')));
    });

    test('5. Archivo inexistente reporta error limpiamente', () async {
      final nonExistentPath = p.join(tempDir.path, 'does_not_exist.gestorbackup');

      final result = await inspectBackupFile(
        backupPath: nonExistentPath,
        password: testPassword,
      );

      expect(result.authSuccess, isFalse);
      expect(result.formatSuccess, isFalse);
      expect(result.formatError, contains('no existe'));
    });
  });
}
