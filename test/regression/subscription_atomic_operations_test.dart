import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

import 'package:gestor_gastos/core/services/database_helper.dart';
import 'package:gestor_gastos/data/repositories/subscription_operations_repository_impl.dart';
import 'package:gestor_gastos/domain/entities/transaction_entity.dart';
import 'package:gestor_gastos/data/models/subscription.dart';

void main() {
  late LocalDatabase localDatabase;
  late SubscriptionOperationsRepositoryImpl repository;
  late Database db;

  setUpAll(() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  setUp(() async {
    // Usar base de datos en memoria
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);

    // Inicializar esquema
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
        goalId TEXT,
        imagePath TEXT,
        iconCode INTEGER,
        colorValue INTEGER,
        isSubscription INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE fixed_expenses(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        paymentDate TEXT NOT NULL,
        frequency TEXT NOT NULL,
        isPaid INTEGER NOT NULL DEFAULT 0,
        custom_icon TEXT,
        custom_color INTEGER,
        accountToCharge INTEGER NOT NULL DEFAULT 2,
        categoryId INTEGER NOT NULL,
        orderIndex INTEGER DEFAULT 0
      )
    ''');

    // Datos base (una cuenta y una suscripción sin pagar)
    await db.insert('accounts', {
      'id': 1,
      'name': 'Banco',
      'type': 'DIGITAL',
      'balance': 1000.0,
      'currencySymbol': 'S/'
    });

    await db.insert(
        'categories', {'id': 1, 'name': 'Suscripciones', 'type': 'EXPENSE'});

    await db.insert('fixed_expenses', {
      'id': 'sub_1',
      'name': 'Netflix',
      'amount': 15.0,
      'paymentDate': DateTime.now().toIso8601String(),
      'frequency': 'monthly',
      'isPaid': 0,
      'accountToCharge': 1,
      'categoryId': 1,
    });

    localDatabase = _MockLocalDatabase(db);
    repository =
        SubscriptionOperationsRepositoryImpl(localDatabase: localDatabase);
  });

  tearDown(() async {
    await db.close();
  });

  group('P9-02B: Operaciones Atómicas de Suscripciones', () {
    test('paySubscriptionAtomic - Éxito total', () async {
      final sub = Subscription(
        id: 'sub_1',
        name: 'Netflix',
        amount: 15.0,
        paymentDate: DateTime.now(),
        frequency: ExpenseFrequency.monthly,
        isPaid: false,
        accountToCharge: 1,
        categoryId: 1,
      );

      final tx = TransactionEntity(
        accountId: 1,
        categoryId: 1,
        amount: -15.0,
        date: DateTime.now(),
        description: 'Netflix',
        type: TransactionType.expense,
      );

      final result = await repository.paySubscriptionAtomic(
        subscription: sub,
        transaction: tx,
      );

      expect(result.isRight(), true);

      // Verify Account Balance
      final account =
          await db.query('accounts', where: 'id = ?', whereArgs: [1]);
      expect(account.first['balance'], 985.0); // 1000 - 15

      // Verify Transaction inserted
      final txCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM transactions'));
      expect(txCount, 1);

      // Verify Subscription isPaid = 1
      final subRecord = await db
          .query('fixed_expenses', where: 'id = ?', whereArgs: ['sub_1']);
      expect(subRecord.first['isPaid'], 1);
    });

    test(
        'paySubscriptionAtomic - Falla en actualización de Suscripción hace Rollback de Transacción',
        () async {
      // Create a trigger to intentionally fail when updating fixed_expenses
      await db.execute('''
        CREATE TRIGGER trigger_fail_sub_update
        BEFORE INSERT ON fixed_expenses
        BEGIN
          SELECT RAISE(ABORT, 'Intended fail on sub update');
        END;
      ''');

      final sub = Subscription(
        id: 'sub_1',
        name: 'Netflix',
        amount: 15.0,
        paymentDate: DateTime.now(),
        frequency: ExpenseFrequency.monthly,
        isPaid: false,
        accountToCharge: 1,
        categoryId: 1,
      );

      final tx = TransactionEntity(
        accountId: 1,
        categoryId: 1,
        amount: -15.0,
        date: DateTime.now(),
        description: 'Netflix',
        type: TransactionType.expense,
      );

      final result = await repository.paySubscriptionAtomic(
        subscription: sub,
        transaction: tx,
      );

      expect(result.isLeft(), true);

      // Verify Account Balance was NOT changed (Rollback)
      final account =
          await db.query('accounts', where: 'id = ?', whereArgs: [1]);
      expect(account.first['balance'], 1000.0);

      // Verify Transaction was NOT inserted (Rollback)
      final txCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM transactions'));
      expect(txCount, 0);

      // Verify Subscription was NOT modified
      final subRecord = await db
          .query('fixed_expenses', where: 'id = ?', whereArgs: ['sub_1']);
      expect(subRecord.first['isPaid'], 0);
    });

    test(
        'paySubscriptionAtomic - Falla en Saldo de Cuenta hace Rollback completo',
        () async {
      // Trigger to fail account update
      await db.execute('''
        CREATE TRIGGER trigger_fail_account_update
        BEFORE UPDATE ON accounts
        BEGIN
          SELECT RAISE(ABORT, 'Intended fail on account update');
        END;
      ''');

      final sub = Subscription(
        id: 'sub_1',
        name: 'Netflix',
        amount: 15.0,
        paymentDate: DateTime.now(),
        frequency: ExpenseFrequency.monthly,
        isPaid: false,
        accountToCharge: 1,
        categoryId: 1,
      );

      final tx = TransactionEntity(
        accountId: 1,
        categoryId: 1,
        amount: -15.0,
        date: DateTime.now(),
        description: 'Netflix',
        type: TransactionType.expense,
      );

      final result = await repository.paySubscriptionAtomic(
        subscription: sub,
        transaction: tx,
      );

      expect(result.isLeft(), true);

      // Verify Account Balance was NOT changed (Rollback)
      final account =
          await db.query('accounts', where: 'id = ?', whereArgs: [1]);
      expect(account.first['balance'], 1000.0);

      // Verify Transaction was NOT inserted (Rollback)
      final txCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM transactions'));
      expect(txCount, 0);

      // Verify Subscription was NOT modified
      final subRecord = await db
          .query('fixed_expenses', where: 'id = ?', whereArgs: ['sub_1']);
      expect(subRecord.first['isPaid'], 0);
    });
  });
}

class _MockLocalDatabase implements LocalDatabase {
  final Database _db;
  _MockLocalDatabase(this._db);

  @override
  Future<Database> get database async => _db;

  @override
  Future<void> clearAllTables() async {}
}
