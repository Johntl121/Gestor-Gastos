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

  group('P1-01: Operaciones Atómicas de Metas (Rollback Tests con escrituras parciales comprobadas)', () {
    test('depositToGoal falla al final de la operación y revierte transacciones insertadas y saldos', () async {
      // 1. Setup: Crear cuenta origen válida y meta
      await db.insert('accounts', {'id': 1, 'name': 'Origen', 'type': 'CASH', 'balance': 1000.0});
      await db.insert('categories', {'id': 1, 'name': 'Transfer', 'type': 'EXPENSE'});
      // Para la meta, le pondremos la misma cuenta 1 para simplificar, no importa
      await db.insert('goals', {
        'id': 'g1',
        'name': 'Mi Meta',
        'targetAmount': 500.0,
        'currentAmount': 0.0,
        'accountId': 1, 
      });

      // Crear un Trigger que lance un error al intentar actualizar la tabla GOALS
      // Esto simula un error en la 3ra escritura, DESPUES de haber insertado la tx y actualizado la cuenta
      await db.execute('''
        CREATE TRIGGER force_fail_deposit
        BEFORE UPDATE ON goals
        BEGIN
          SELECT RAISE(ABORT, 'Simulated failure during goal update');
        END;
      ''');

      final transaction = TransactionEntity(
        id: 0,
        accountId: 1, // Origen
        categoryId: 1,
        amount: 100.0,
        date: DateTime.now(),
        type: TransactionType.transfer,
        destinationAccountId: 1, // Mismo para simplificar
        description: 'Test',
      );

      // 2. Acción: Intentar depositar
      final result = await goalRepository.depositToGoalAtomic('g1', transaction);

      // Limpiar trigger
      await db.execute('DROP TRIGGER force_fail_deposit');

      // 3. Verificación
      expect(result.isLeft(), isTrue); // Debe fallar

      // Validar Rollback:
      // A. Ninguna transacción insertada (se revirtió el INSERT de Step 2)
      final txs = await db.query('transactions');
      expect(txs.length, 0);

      // B. El saldo original no cambió (se revirtió el UPDATE de Step 3)
      final accounts = await db.query('accounts', where: 'id = 1');
      expect(accounts.first['balance'], 1000.0);

      // C. La meta quedó en su estado original
      final goals = await db.query('goals', where: 'id = ?', whereArgs: ['g1']);
      expect(goals.first['currentAmount'], 0.0);
    });

    test('purchaseGoal falla al final (durante el update de meta) y hace rollback de inserciones previas', () async {
      // Setup
      await db.insert('accounts', {'id': 1, 'name': 'Alcancía', 'type': 'CASH', 'balance': 500.0});
      await db.insert('categories', {'id': 2, 'name': 'Compras', 'type': 'EXPENSE'});
      await db.insert('goals', {
        'id': 'g2',
        'name': 'Mi Meta',
        'targetAmount': 500.0,
        'currentAmount': 500.0,
        'accountId': 1,
      });

      // Provocamos el fallo explícitamente en el último paso (UPDATE de la meta)
      await db.execute('''
        CREATE TRIGGER force_fail_purchase
        BEFORE UPDATE ON goals
        BEGIN
          SELECT RAISE(ABORT, 'Simulated failure during goal purchase update');
        END;
      ''');

      final transaction = TransactionEntity(
        id: 0,
        accountId: 1,
        categoryId: 2, 
        amount: -500.0,
        date: DateTime.now(),
        type: TransactionType.expense,
        description: 'Test',
      );

      // Acción
      final result = await goalRepository.purchaseGoalAtomic('g2', transaction);

      await db.execute('DROP TRIGGER force_fail_purchase');

      // Verificación
      expect(result.isLeft(), isTrue);

      // Validar Rollback:
      // La transacción que se había insertado debe haberse revertido
      final txs = await db.query('transactions');
      expect(txs.length, 0);

      // El gasto que se había aplicado a la cuenta (saldo pasó de 500 a 0) se revirtió a 500
      final accounts = await db.query('accounts', where: 'id = 1');
      expect(accounts.first['balance'], 500.0);

      // La meta no se marcó como completada
      final goals = await db.query('goals', where: 'id = ?', whereArgs: ['g2']);
      expect(goals.first['isCompleted'], 0);
    });

    test('deleteGoalAtomic con reembolso falla al eliminar la meta (luego de insertar refund)', () async {
      // Setup
      await db.insert('accounts', {'id': 2, 'name': 'Reembolso', 'type': 'CASH', 'balance': 100.0});
      await db.insert('accounts', {'id': 3, 'name': 'Meta', 'type': 'CASH', 'balance': 200.0});
      await db.insert('categories', {'id': 1, 'name': 'Transfer', 'type': 'EXPENSE'});
      await db.insert('goals', {
        'id': 'g3',
        'name': 'Mi Meta',
        'targetAmount': 500.0,
        'currentAmount': 200.0,
        'accountId': 3, 
      });

      // El fallo lo provocamos al momento de eliminar la meta (último paso de deleteGoalAtomic)
      await db.execute('''
        CREATE TRIGGER force_fail_delete
        BEFORE DELETE ON goals
        BEGIN
          SELECT RAISE(ABORT, 'Simulated failure during goal deletion');
        END;
      ''');

      final refundTx = TransactionEntity(
        id: 0,
        accountId: 3, // Origen meta
        categoryId: 1,
        amount: 200.0,
        date: DateTime.now(),
        type: TransactionType.transfer,
        destinationAccountId: 2, // Reembolso válido
        description: 'Test',
      );

      // Acción
      final result = await goalRepository.deleteGoalAtomic('g3', refundTransaction: refundTx);

      await db.execute('DROP TRIGGER force_fail_delete');

      // Verificación
      expect(result.isLeft(), isTrue);

      // Validar Rollback:
      // La inserción de la transacción de reembolso se revirtió
      final txs = await db.query('transactions');
      expect(txs.length, 0);

      // Saldo de reembolso intacto (no recibió los 200)
      final accounts = await db.query('accounts', where: 'id = 2');
      expect(accounts.first['balance'], 100.0);
      
      // Saldo de origen de la meta intacto (no perdió los 200)
      final accountsOrigin = await db.query('accounts', where: 'id = 3');
      expect(accountsOrigin.first['balance'], 200.0);

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
