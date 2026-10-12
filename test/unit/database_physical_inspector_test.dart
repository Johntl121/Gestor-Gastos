import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/services/database_physical_inspector.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late DatabasePhysicalInspector inspector;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('inspector_test_');
    inspector = DatabasePhysicalInspector(
      unencryptedDbOpener: (path, {readOnly, singleInstance}) =>
          databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: readOnly ?? false),
      ),
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<String> createValidV24Database(String fileName) async {
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
        },
      ),
    );
    await db.close();
    return dbPath;
  }

  group('DatabasePhysicalInspector — Suite de Pruebas Unitarias (13B-05)', () {
    test('1. Detecta archivo inexistente (fileNotFound)', () async {
      final nonExistent = p.join(tempDir.path, 'no_existe.db');
      final report = await inspector.inspect(dbPath: nonExistent);

      expect(report.status, equals(DatabasePhysicalStatus.fileNotFound));
      expect(report.isMigratableV24, isFalse);
    });

    test('2. Detecta archivo vacío o truncado menor a 16 bytes (corruptedOrUnrecognized)', () async {
      final emptyFile = File(p.join(tempDir.path, 'vacio.db'));
      await emptyFile.writeAsBytes([]);

      final report = await inspector.inspect(dbPath: emptyFile.path);

      expect(report.status, equals(DatabasePhysicalStatus.corruptedOrUnrecognized));
      expect(report.failureReason, contains('menor a 16 bytes'));
    });

    test('3. Detecta migración incompleta si existe marcador pending en directorio', () async {
      final dbPath = await createValidV24Database('test_pending.db');
      final marker = File(p.join(tempDir.path, 'test_pending.db.migration.pending'));
      await marker.writeAsString('{"stage":"exporting"}');

      final report = await inspector.inspect(dbPath: dbPath);

      expect(report.status, equals(DatabasePhysicalStatus.incompleteMigration));
      expect(report.isMigratableV24, isFalse);
    });

    test('4. Detecta archivo no plano y exige clave (encryptedKeyRequired)', () async {
      final opaqueFile = File(p.join(tempDir.path, 'opaco.db'));
      // Escribir 1024 bytes aleatorios/cifrados sin cabecera SQLite
      await opaqueFile.writeAsBytes(List.filled(1024, 0xEF));

      final report = await inspector.inspect(dbPath: opaqueFile.path);

      expect(report.status, equals(DatabasePhysicalStatus.encryptedKeyRequired));
      expect(report.hasSqliteHeader, isFalse);
    });

    test('5. Inspecciona e identifica exitosamente SQLite plana v24 íntegra (validUnencryptedV24)', () async {
      final dbPath = await createValidV24Database('valida_v24.db');

      final report = await inspector.inspect(dbPath: dbPath);

      expect(report.status, equals(DatabasePhysicalStatus.validUnencryptedV24));
      expect(report.isMigratableV24, isTrue);
      expect(report.hasSqliteHeader, isTrue);
      expect(report.userVersion, equals(24));
      expect(report.detectedTables, containsAll([
        'accounts',
        'categories',
        'transactions',
        'fixed_expenses',
        'goals',
        'reminders',
      ]));

      // Verificar generación de prueba física
      final proof = report.toMigrationProof();
      expect(proof.dbPath, equals(dbPath));
      expect(proof.userVersion, equals(24));
      expect(proof.fileSizeBytes, greaterThan(0));
      expect(proof.sha256Fingerprint, isNotEmpty);
      expect(proof.sha256Fingerprint.length, equals(64));
    });

    test('6. Rechaza SQLite plana con user_version incompatible (incompatibleSchemaVersion)', () async {
      final dbPath = p.join(tempDir.path, 'version_antigua.db');
      final db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 15,
          onCreate: (db, version) async {
            await db.execute('CREATE TABLE accounts (id INTEGER PRIMARY KEY);');
          },
        ),
      );
      await db.close();

      final report = await inspector.inspect(dbPath: dbPath);

      expect(report.status, equals(DatabasePhysicalStatus.incompatibleSchemaVersion));
      expect(report.userVersion, equals(15));
      expect(report.isMigratableV24, isFalse);
    });

    test('7. Rechaza SQLite plana con esquema incompleto (faltan tablas v24)', () async {
      final dbPath = p.join(tempDir.path, 'incompleta.db');
      final db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 24,
          onCreate: (db, version) async {
            // Solo creamos accounts, faltan las demás
            await db.execute('CREATE TABLE accounts (id INTEGER PRIMARY KEY);');
          },
        ),
      );
      await db.close();

      final report = await inspector.inspect(dbPath: dbPath);

      expect(report.status, equals(DatabasePhysicalStatus.corruptedOrUnrecognized));
      expect(report.failureReason, contains('Faltan tablas obligatorias'));
    });
  });
}
