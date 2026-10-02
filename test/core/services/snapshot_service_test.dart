import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gestor_gastos/core/services/database_helper.dart';
import 'package:gestor_gastos/core/services/snapshot_service.dart';

void main() {
  late SnapshotService snapshotService;
  late LocalDatabase localDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    localDb = LocalDatabase();
    snapshotService = SnapshotService(localDatabase: localDb);
    // Asegurar que la DB principal está abierta
    final db = await localDb.database;
    await db.rawInsert("INSERT OR IGNORE INTO accounts(name, type, balance, color) VALUES('TestAccount', 'DIGITAL', 100.0, 1)");
  });

  tearDown(() async {
    await localDb.closeAndRelease();
    final String activeDbPath = join(await getDatabasesPath(), 'gestor_gastos.db');
    if (await File(activeDbPath).exists()) {
      await File(activeDbPath).delete();
    }
  });

  group('SnapshotService y Mutex', () {
    test('closeAndRelease deja la DB liberada y el siguiente acceso la reabre', () async {
      var db1 = await localDb.database;
      expect(db1.isOpen, isTrue);

      await localDb.closeAndRelease();
      expect(db1.isOpen, isFalse); // The old reference is closed

      var db2 = await localDb.database;
      expect(db2.isOpen, isTrue); // A new reference is opened
      expect(db1 == db2, isFalse);
    });

    test('createDatabaseSnapshot crea una copia válida y conserva user_version y datos', () async {
      final snapshotPath = join(await getDatabasesPath(), 'snapshot_test.db');
      if (await File(snapshotPath).exists()) await File(snapshotPath).delete();

      final snapshotFile = await snapshotService.createDatabaseSnapshot(snapshotPath);
      
      // snapshot existe
      expect(await snapshotFile.exists(), isTrue);

      // validar snapshot externamente
      final snapshotDb = await openDatabase(snapshotPath, singleInstance: false);
      
      // snapshot quick_check = ok
      final quickCheck = await snapshotDb.rawQuery('PRAGMA quick_check;');
      expect(quickCheck.first['quick_check'], 'ok');

      // snapshot conserva user_version
      final versionResult = await snapshotDb.rawQuery('PRAGMA user_version;');
      expect(versionResult.first.values.first, 24); // _databaseVersion en database_helper.dart es 24

      // datos existentes están presentes en snapshot
      final accounts = await snapshotDb.query('accounts', where: "name = ?", whereArgs: ['TestAccount']);
      expect(accounts.isNotEmpty, isTrue);
      expect(accounts.first['balance'], 100.0);

      await snapshotDb.close();
      await snapshotFile.delete();
    });

    test('fallo durante copy -> DB productiva vuelve a quedar utilizable', () async {
      // Pasamos un directorio en lugar de un archivo para forzar un FileSystemException
      final invalidPath = await getDatabasesPath(); 

      try {
        await snapshotService.createDatabaseSnapshot(invalidPath);
        fail('Debería haber fallado al copiar sobre un directorio');
      } catch (e) {
        expect(e, isA<FileSystemException>());
      }

      // La DB debe seguir abierta y funcional
      final db = await localDb.database;
      expect(db.isOpen, isTrue);
      
      final accounts = await db.query('accounts', where: "name = ?", whereArgs: ['TestAccount']);
      expect(accounts.isNotEmpty, isTrue);
    });

    test('dos intentos concurrentes de snapshot no rompen la DB', () async {
      final path1 = join(await getDatabasesPath(), 'snap1.db');
      final path2 = join(await getDatabasesPath(), 'snap2.db');

      // Lanzamos ambos concurrentemente
      final future1 = snapshotService.createDatabaseSnapshot(path1);
      final future2 = snapshotService.createDatabaseSnapshot(path2);

      await Future.wait([future1, future2]);

      expect(await File(path1).exists(), isTrue);
      expect(await File(path2).exists(), isTrue);

      // Verificamos que la DB productiva sigue viva
      final db = await localDb.database;
      expect(db.isOpen, isTrue);

      await File(path1).delete();
      await File(path2).delete();
    });
  });
}
