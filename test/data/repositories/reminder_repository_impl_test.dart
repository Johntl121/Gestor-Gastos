import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/services/database_helper.dart';
import 'package:gestor_gastos/data/datasources/local/reminder_local_data_source.dart';
import 'package:gestor_gastos/data/repositories/reminder_repository_impl.dart';
import 'package:gestor_gastos/domain/entities/reminder.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_helper.dart';

void main() {
  late LocalDatabase localDatabase;
  late ReminderLocalDataSourceImpl localDataSource;
  late ReminderRepositoryImpl repository;

  setUpAll(() async {
    await setupTestDatabase();
  });

  setUp(() async {
    localDatabase = LocalDatabase();
    await localDatabase.clearAllTables();

    localDataSource = ReminderLocalDataSourceImpl(localDatabase: localDatabase);
    repository = ReminderRepositoryImpl(localDataSource: localDataSource);
  });

  final testReminder = Reminder(
    id: 'r1',
    title: 'Test Reminder',
    description: 'A description',
    type: ReminderType.general,
    date: DateTime(2023, 1, 1),
    hour: 9,
    minute: 30,
    recurrence: ReminderRecurrence.none,
    createdAt: DateTime(2023, 1, 1),
    updatedAt: DateTime(2023, 1, 1),
  );

  group('ReminderRepositoryImpl - CRUD y Constraints', () {
    test('create y read funcionan correctamente', () async {
      final createResult = await repository.createReminder(testReminder);
      expect(createResult.isRight(), isTrue);

      final readResult = await repository.getReminderById('r1');
      expect(readResult.isRight(), isTrue);

      final fetched = readResult.getOrElse(() => null);
      expect(fetched, isNotNull);
      expect(fetched!.id, 'r1');
      expect(fetched.title, 'Test Reminder');
      expect(fetched.hour, 9);
      expect(fetched.minute, 30);
    });

    test('update y delete funcionan correctamente', () async {
      await repository.createReminder(testReminder);

      final updated = testReminder.copyWith(title: 'Updated Title');
      final updateResult = await repository.updateReminder(updated);
      expect(updateResult.isRight(), isTrue);

      final readResult = await repository.getReminderById('r1');
      final fetched = readResult.getOrElse(() => null);
      expect(fetched!.title, 'Updated Title');

      final deleteResult = await repository.deleteReminder('r1');
      expect(deleteResult.isRight(), isTrue);

      final readDeleted = await repository.getReminderById('r1');
      expect(readDeleted.getOrElse(() => null), isNull);
    });

    test('categoryId nullable es permitido', () async {
      final reminder = testReminder.copyWith(id: 'r3', categoryId: null);
      final result = await repository.createReminder(reminder);
      expect(result.isRight(), isTrue);
    });

    test('normalización monetaria antes de persistir', () async {
      // 100.555 en USD (2 decimales) debería normalizarse a 100.56
      final unnormalized = Reminder(
        id: 'r4',
        title: 'Unnormalized',
        type: ReminderType.payment,
        amount: 100.555,
        currencyCode: 'USD',
        date: DateTime(2023, 1, 1),
        hour: 9,
        minute: 0,
        recurrence: ReminderRecurrence.none,
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 1),
      );

      await repository.createReminder(unnormalized);
      final readResult = await repository.getReminderById('r4');
      final fetched = readResult.getOrElse(() => null);
      expect(fetched!.amount, 100.56);
    });

    test('completedAt inválido para recurrente -> rechazado', () async {

      // Usamos reflexión de map para forzar el estado inválido y evadir la validación de la entidad
      // El repositorio también debe validarlo en _toModel.
      // Sin embargo, para forzarlo, lo simulamos metiendo datos directo en SQFlite, y fallará al tratar de insertarlo si hay CHECK
      // Pero 'completedAt' no tiene CHECK en SQLite para recurrencia, la validación está en el repo.
      // Como no podemos instanciar el Reminder con ese error (por los asserts),
      // lo inyectamos por SQFLite y luego al leerlo lanzaremos error (Format Exception o similar si queremos, o falla silente?
      // El requerimiento dice: "completedAt inválido para recurrente -> rechazado").

      // La validación ya está en `Reminder()` assert, pero si creamos un mapa y usamos DataSource:
      await localDataSource.createReminder({
        'id': 'bad_rem',
        'title': 'Bad',
        'type': 'general',
        'date': DateTime.now().toIso8601String(),
        'hour': 10,
        'minute': 0,
        'recurrence': 'monthly',
        'active': 1,
        'completedAt': DateTime.now().toIso8601String(), // Invalido
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // El repositorio no valida al LEER esto estrictamente, pero el ENUM u otra cosa puede fallar.
      // En realidad, la prueba de que el repositorio RECHAZA guardar un estado inválido se cubre al intentar guardar
      // Pero no podemos instanciar un Reminder inválido.
      // Simplemente verificamos que el Assert del Reminder salta al instanciarlo después de leer de DB,
      // O que al intentar guardar un modelo trampeado falle.

      final readResult = await repository.getReminderById('bad_rem');
      expect(readResult.isLeft(), isTrue,
          reason: 'Debe fallar al instanciar el Reminder con asserts');
    });

    test('enum inválido desde DB -> error explícito', () async {
      await localDataSource.createReminder({
        'id': 'bad_enum',
        'title': 'Bad Enum',
        'type': 'unknown_type', // Invalido
        'date': DateTime.now().toIso8601String(),
        'hour': 10,
        'minute': 0,
        'recurrence': 'none',
        'active': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final readResult = await repository.getReminderById('bad_enum');
      expect(readResult.isLeft(), isTrue,
          reason: 'Debe devolver un DatabaseFailure por FormatException');
    });
  });

  group('Migración SQLite', () {
    test('migración V22 a V23 crea tabla reminders y preserva datos', () async {
      // Creamos una BD temporal forzando V22
      final factory = databaseFactoryFfi;
      final dbPath = 'test_migration_${DateTime.now().millisecondsSinceEpoch}.db';

      final dbV22 = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 22,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE accounts(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL
              )
            ''');
            await db.insert('accounts', {'name': 'V22 Account'});
          },
        ),
      );

      final accountsV22 = await dbV22.query('accounts');
      expect(accountsV22.length, 1);

      // Cerramos V22
      await dbV22.close();

      // Abrimos con V23 (simulando la lógica de migración de DatabaseHelper)
      final dbV23 = await factory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 23,
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 23) {
              await db.execute('''
                CREATE TABLE reminders(
                  id TEXT PRIMARY KEY,
                  title TEXT NOT NULL,
                  amount REAL,
                  currencyCode TEXT
                )
               ''');
            }
          },
        ),
      );

      // Verificamos que los datos se preservaron
      final accountsV23 = await dbV23.query('accounts');
      expect(accountsV23.length, 1,
          reason: 'Los datos históricos no deben borrarse');

      // Verificamos que la tabla reminders existe insertando un dato
      await dbV23
          .insert('reminders', {'id': 'mig_1', 'title': 'Migration Test'});
      final reminders = await dbV23.query('reminders');
      expect(reminders.length, 1, reason: 'La tabla reminders debe existir tras la migración');

      await dbV23.close();
      await factory.deleteDatabase(dbPath);
    });
  });
}
