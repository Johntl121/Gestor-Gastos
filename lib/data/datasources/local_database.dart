import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  static Database? _database;

  factory LocalDatabase() {
    return _instance;
  }

  LocalDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'gestor_gastos.db');
    return await openDatabase(
      path,
      version: 6, // Increment version
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migración V1 -> V2: Asegurar que existan categorías y segunda cuenta

      // 1. Verificar si falta cuenta Bancaria
      final accounts =
          await db.query('accounts', where: "type = ?", whereArgs: ['DIGITAL']);
      if (accounts.isEmpty) {
        await db.rawInsert('''
            INSERT INTO accounts(name, type, balance, color) VALUES('Bancaria', 'DIGITAL', 0.0, 4280391411)
         ''');
      }

      // 2. Verificar si faltan categorías
      final categoriesCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM categories'));
      if (categoriesCount == 0) {
        // Insertar categorías por defecto
        await db.rawInsert(
            "INSERT INTO categories(name, icon, color, type) VALUES('Comida', 'fastfood', 4294198070, 'EXPENSE')");
        await db.rawInsert(
            "INSERT INTO categories(name, icon, color, type) VALUES('Transporte', 'directions_bus', 4280391411, 'EXPENSE')");
        await db.rawInsert(
            "INSERT INTO categories(name, icon, color, type) VALUES('Ocio', 'movie', 4289721600, 'EXPENSE')");
        await db.rawInsert(
            "INSERT INTO categories(name, icon, color, type) VALUES('Varios', 'category', 4286611584, 'EXPENSE')");
      }
    }

    if (oldVersion < 3) {
      // Migración V2 -> V3: Agregar columa 'type' a transactions
      // We check if column exists first to be safe, or just run ADD COLUMN which is safe in SQLite if done right,
      // but simplistic approach works.
      try {
        await db.execute(
            "ALTER TABLE transactions ADD COLUMN type TEXT DEFAULT 'EXPENSE'");
      } catch (e) {
        // Column might already exist
      }
    }

    if (oldVersion < 4) {
      // Migración V3 -> V4: Agregar cuenta Ahorros
      final savings =
          await db.query('accounts', where: "name = ?", whereArgs: ['Ahorros']);
      if (savings.isEmpty) {
        await db.rawInsert(
            "INSERT INTO accounts(name, type, balance, color) VALUES('Ahorros', 'DIGITAL', 0.0, 4285143962)");
      }
    }

    if (oldVersion < 5) {
      // Migración V4 -> V5: Agregar columna 'destinationAccountId' a transactions
      try {
        await db.execute(
            "ALTER TABLE transactions ADD COLUMN destinationAccountId INTEGER");
      } catch (e) {
        // Column might already exist
      }
    }

    if (oldVersion < 6) {
      // Migración V5 -> V6: Asegurar cuenta Ahorros (Fix para nuevos usuarios en V5)
      final savings =
          await db.query('accounts', where: "name = ?", whereArgs: ['Ahorros']);
      if (savings.isEmpty) {
        await db.rawInsert(
            "INSERT INTO accounts(name, type, balance, color) VALUES('Ahorros', 'DIGITAL', 0.0, 4285143962)");
      }
    }
  }

  Future<void> _onConfigure(Database db) async {
    // Habilitar claves foráneas
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Tabla de Cuentas
    await db.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('CASH', 'DIGITAL')),
        balance REAL DEFAULT 0.0,
        color INTEGER
      )
    ''');

    // 2. Tabla de Categorias
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT,
        color INTEGER,
        type TEXT NOT NULL CHECK(type IN ('EXPENSE', 'INCOME'))
      )
    ''');

    // 3. Tabla de Transacciones
    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        accountId INTEGER NOT NULL,
        categoryId INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        type TEXT DEFAULT 'EXPENSE',
        destinationAccountId INTEGER,
        FOREIGN KEY (accountId) REFERENCES accounts (id) ON DELETE CASCADE,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Semilla de Datos Inicial (Opcional, pero bueno para UX)
    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    // Cuentas Iniciales
    await db.rawInsert('''
      INSERT INTO accounts(name, type, balance, color) VALUES('Efectivo', 'CASH', 0.0, 4283215696)
    ''');
    await db.rawInsert('''
      INSERT INTO accounts(name, type, balance, color) VALUES('Bancaria', 'DIGITAL', 0.0, 4280391411)
    '''); // Color Azul
    await db.rawInsert('''
      INSERT INTO accounts(name, type, balance, color) VALUES('Ahorros', 'DIGITAL', 0.0, 4285143962)
    '''); // Color Morado

    // Categorías Iniciales (Gastos)
    await db.rawInsert('''
      INSERT INTO categories(name, icon, color, type) VALUES('Comida', 'fastfood', 4294198070, 'EXPENSE')
    '''); // Orange
    await db.rawInsert('''
      INSERT INTO categories(name, icon, color, type) VALUES('Transporte', 'directions_bus', 4280391411, 'EXPENSE')
    '''); // Blue
    await db.rawInsert('''
      INSERT INTO categories(name, icon, color, type) VALUES('Ocio', 'movie', 4289721600, 'EXPENSE')
    '''); // Purple
    await db.rawInsert('''
      INSERT INTO categories(name, icon, color, type) VALUES('Varios', 'category', 4286611584, 'EXPENSE')
    '''); // Grey
  }

  Future<void> clearAllTables() async {
    final db = await database;
    await db.delete('transactions');
    await db.rawUpdate('UPDATE accounts SET balance = 0.0');
  }
}
