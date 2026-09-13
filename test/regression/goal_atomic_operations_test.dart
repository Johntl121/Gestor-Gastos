import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

import 'package:gestor_gastos/core/services/database_helper.dart';
import 'package:gestor_gastos/data/repositories/goal_operations_repository_impl.dart';
import 'package:gestor_gastos/domain/entities/transaction_entity.dart';

void main() {
  late LocalDatabase localDatabase;
  late GoalOperationsRepositoryImpl goalRepository;
  late Database db;

  setUpAll(() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  setUp(() async {
    // Usar base de datos en memoria para los tests
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
        imagePath TEXT,
        iconCode INTEGER,
        colorValue INTEGER,
        FOREIGN KEY (accountId) REFERENCES accounts (id) ON DELETE CASCADE,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE CASCADE
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
        orderIndex INTEGER DEFAULT 0,
        FOREIGN KEY (accountId) REFERENCES accounts (id) ON DELETE SET NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // Inyectar base de datos simulada en LocalDatabase mediante un mock
    localDatabase = _MockLocalDatabase(db);
    goalRepository = GoalOperationsRepositoryImpl(localDatabase: localDatabase);
  });

  tearDown(() async {
    await db.close();
  });

  group('P1-01: Operaciones Atómicas de Metas (Rollback Tests)', () {
    test(
        'depositToGoal falla por cuenta destino inexistente y hace rollback completo',
        () async {
      // 1. Setup: Crear cuenta origen y meta, PERO la cuenta destino de la meta NO existe.
      await db.insert('accounts',
          {'id': 1, 'name': 'Origen', 'type': 'CASH', 'balance': 1000.0});
      await db.insert(
          'categories', {'id': 1, 'name': 'Transfer', 'type': 'EXPENSE'});
      await db.insert('goals', {
        'id': 'g1',
        'name': 'Mi Meta',
        'targetAmount': 500.0,
        'currentAmount': 0.0,
        'accountId': 999, // CUENTA INEXISTENTE
      });

      final transaction = TransactionEntity(
        id: 0,
        accountId: 1, // Origen
        categoryId: 1,
        amount: 100.0,
        date: DateTime.now(),
        type: TransactionType.transfer,
        destinationAccountId: 999, // CUENTA INEXISTENTE
        description: 'Test',
      );

      // 2. Acción: Intentar depositar
      final result =
          await goalRepository.depositToGoalAtomic('g1', transaction);

      // 3. Verificación
      expect(result.isLeft(), isTrue); // Debe fallar

      // Validar Rollback:
      // A. Ninguna transacción insertada
      final txs = await db.query('transactions');
      expect(txs.length, 0);

      // B. El saldo original no cambió (no se restaron los 100)
      final accounts = await db.query('accounts', where: 'id = 1');
      expect(accounts.first['balance'], 1000.0);

      // C. La meta quedó en su estado original
      final goals = await db.query('goals', where: 'id = ?', whereArgs: ['g1']);
      expect(goals.first['currentAmount'], 0.0);
    });

    test(
        'purchaseGoal falla por saldo de categoría (falla simulada en SQLite) y hace rollback',
        () async {
      // Setup
      await db.insert('accounts',
          {'id': 1, 'name': 'Alcancía', 'type': 'CASH', 'balance': 500.0});
      // NO insertamos la categoría 1 para forzar un fallo de Foreign Key (categoryId)
      await db.insert('goals', {
        'id': 'g2',
        'name': 'Mi Meta',
        'targetAmount': 500.0,
        'currentAmount': 500.0,
        'accountId': 1,
      });

      final transaction = TransactionEntity(
        id: 0,
        accountId: 1,
        categoryId: 999, // CATEGORÍA INEXISTENTE (Foreign key violation)
        amount: -500.0,
        date: DateTime.now(),
        type: TransactionType.expense,
        description: 'Test',
      );

      // Enable foreign keys to force the violation
      await db.execute('PRAGMA foreign_keys = ON');

      // Acción
      final result = await goalRepository.purchaseGoalAtomic('g2', transaction);

      // Verificación
      expect(result.isLeft(), isTrue);

      // Validar Rollback:
      final txs = await db.query('transactions');
      expect(txs.length, 0);

      final accounts = await db.query('accounts', where: 'id = 1');
      expect(accounts.first['balance'], 500.0);

      final goals = await db.query('goals', where: 'id = ?', whereArgs: ['g2']);
      expect(goals.first['isCompleted'], 0);
    });

    test(
        'deleteGoalAtomic con reembolso falla por cuenta origen (Alcancía) inexistente',
        () async {
      // Setup
      await db.insert('accounts',
          {'id': 2, 'name': 'Reembolso', 'type': 'CASH', 'balance': 100.0});
      await db.insert(
          'categories', {'id': 1, 'name': 'Transfer', 'type': 'EXPENSE'});
      await db.insert('goals', {
        'id': 'g3',
        'name': 'Mi Meta',
        'targetAmount': 500.0,
        'currentAmount': 200.0,
        'accountId': 999, // INEXISTENTE
      });

      final refundTx = TransactionEntity(
        id: 0,
        accountId: 999, // Origen inexistente
        categoryId: 1,
        amount: 200.0,
        date: DateTime.now(),
        type: TransactionType.transfer,
        destinationAccountId: 2, // Reembolso válido
        description: 'Test',
      );

      // Acción
      final result = await goalRepository.deleteGoalAtomic('g3',
          refundTransaction: refundTx);

      // Verificación
      expect(result.isLeft(), isTrue);

      // Validar Rollback:
      final txs = await db.query('transactions');
      expect(txs.length, 0);

      // Saldo de reembolso intacto
      final accounts = await db.query('accounts', where: 'id = 2');
      expect(accounts.first['balance'], 100.0);

      // Meta no fue eliminada
      final goals = await db.query('goals', where: 'id = ?', whereArgs: ['g3']);
      expect(goals.length, 1);
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
