import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/app_categories.dart';

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
      version: 20, // Incrementado a 20 para Wipe & Rebuild (Clean Slate)
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // ... (migraciones previas mantenidas para compatibilidad)
    if (oldVersion < 2) {
      final accounts = await db.query('accounts', where: "type = ?", whereArgs: ['DIGITAL']);
      if (accounts.isEmpty) {
        await db.rawInsert("INSERT INTO accounts(name, type, balance, color) VALUES('Bancaria', 'DIGITAL', 0.0, 4280391411)");
      }
      final categoriesCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categories'));
      if (categoriesCount == 0) {
        await db.rawInsert("INSERT INTO categories(name, icon, color, type) VALUES('Comida', 'fastfood', 4294198070, 'EXPENSE')");
        await db.rawInsert("INSERT INTO categories(name, icon, color, type) VALUES('Transporte', 'directions_bus', 4280391411, 'EXPENSE')");
        await db.rawInsert("INSERT INTO categories(name, icon, color, type) VALUES('Ocio', 'movie', 4289721600, 'EXPENSE')");
        await db.rawInsert("INSERT INTO categories(name, icon, color, type) VALUES('Varios', 'category', 4286611584, 'EXPENSE')");
      }
    }

    if (oldVersion < 3) {
      try {
        await db.execute(
            "ALTER TABLE transactions ADD COLUMN type TEXT DEFAULT 'EXPENSE'");
      } catch (e) {
        // Ignorar si la columna ya existe
      }
    }

    if (oldVersion < 5) {
      try {
        await db.execute(
            "ALTER TABLE transactions ADD COLUMN destinationAccountId INTEGER");
      } catch (e) {
        // Ignorar si la columna ya existe
      }
    }

    if (oldVersion < 7) {
      try {
        await db.execute(
            "ALTER TABLE accounts ADD COLUMN currencySymbol TEXT DEFAULT 'S/'");
      } catch (e) {
        // Ignorar si ya existe
      }
      try {
        await db.execute(
            "ALTER TABLE accounts ADD COLUMN iconCode INTEGER DEFAULT 58343");
      } catch (e) {
        // Ignorar si ya existe
      }
    }

    if (oldVersion < 8) {
      try {
        await db.execute(
            "ALTER TABLE accounts ADD COLUMN includeInTotal INTEGER DEFAULT 1");
      } catch (e) {
        // Ignorar si ya existe
      }
    }

    if (oldVersion < 9) {
      try {
        await db.execute("ALTER TABLE transactions ADD COLUMN receivedAmount REAL");
      } catch (e) {
        // Ignorar si ya existe
      }
    }

    if (oldVersion < 10) {
      try {
        await db.execute("ALTER TABLE transactions ADD COLUMN imagePath TEXT");
      } catch (e) {
        // Ignorar si ya existe
      }
    }

    if (oldVersion < 11) {
      try {
        await db.execute("ALTER TABLE transactions ADD COLUMN iconCode INTEGER");
        await db.execute("ALTER TABLE transactions ADD COLUMN colorValue INTEGER");
      } catch (e) {
        // Ignorar si ya existen
      }
    }

    // NUEVA MIGRACIÓN V13: Asegurar que TODAS las categorías están presentes
    if (oldVersion < 13) {
      final expenseCategories = {
        1: {'name': 'Comida', 'icon': 'restaurant', 'color': 0xFFFB8C00},
        2: {'name': 'Mercado', 'icon': 'shopping_cart', 'color': 0xFF9CCC65},
        3: {'name': 'Vivienda', 'icon': 'home', 'color': 0xFF607D8B},
        4: {'name': 'Servicios', 'icon': 'bolt', 'color': 0xFFF57C00},
        5: {'name': 'Transporte', 'icon': 'directions_bus', 'color': 0xFF2196F3},
        6: {'name': 'Vehículo', 'icon': 'directions_car', 'color': 0xFFFF5252},
        7: {'name': 'Compras', 'icon': 'shopping_bag', 'color': 0xFFE91E63},
        8: {'name': 'Cuidado', 'icon': 'spa', 'color': 0xFF9C27B0},
        9: {'name': 'Suscripciones', 'icon': 'play_circle_filled', 'color': 0xFFF44336},
        10: {'name': 'Salud', 'icon': 'local_hospital', 'color': 0xFF009688},
        11: {'name': 'Deportes', 'icon': 'fitness_center', 'color': 0xFF4CAF50},
        12: {'name': 'Entretenimiento', 'icon': 'movie', 'color': 0xFF3F51B5},
        13: {'name': 'Viajes', 'icon': 'flight', 'color': 0xFF00BCD4},
        14: {'name': 'Educación', 'icon': 'school', 'color': 0xFF795548},
        15: {'name': 'Tecnología', 'icon': 'computer', 'color': 0xFF9E9E9E},
        16: {'name': 'Deudas', 'icon': 'money_off', 'color': 0xFFFF5722},
        17: {'name': 'Ahorro', 'icon': 'savings', 'color': 0xFFCDDC39},
        20: {'name': 'Otros', 'icon': 'grid_view', 'color': 0xFF607D8B},
      };

      final incomeCategories = {
        18: {'name': 'Sueldo', 'icon': 'monetization_on', 'color': 0xFF2E7D32},
        19: {'name': 'Negocio', 'icon': 'work', 'color': 0xFF0D47A1},
        21: {'name': 'Inversiones', 'icon': 'trending_up', 'color': 0xFF9C27B0},
        22: {'name': 'Regalos', 'icon': 'card_giftcard', 'color': 0xFFFF4081},
        23: {'name': 'Ventas', 'icon': 'storefront', 'color': 0xFFFB8C00},
        24: {'name': 'Préstamos', 'icon': 'handshake', 'color': 0xFF009688},
        25: {'name': 'Otros', 'icon': 'category', 'color': 0xFF607D8B},
      };

      final allCats = {...expenseCategories, ...incomeCategories};

      for (var entry in allCats.entries) {
        try {
          final type = entry.key >= 18 && entry.key <= 25 && entry.key != 20 ? 'INCOME' : 'EXPENSE';
          await db.rawInsert(
              "INSERT OR IGNORE INTO categories(id, name, icon, color, type) VALUES(?, ?, ?, ?, ?)",
              [entry.key, entry.value['name'], entry.value['icon'], entry.value['color'], type]);
        } catch (e) {
          // Ignorar si hay algún error puntual
        }
      }

      try {
        await db.execute("ALTER TABLE transactions ADD COLUMN note TEXT");
      } catch (e) {
        // Ignorar
      }
    }

    if (oldVersion < 14) {
      await _createFixedExpensesTable(db);
      await _createGoalsTable(db);
    }

    if (oldVersion < 15) {
      await db.execute("CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)");
      await db.execute("CREATE INDEX IF NOT EXISTS idx_transactions_accountId ON transactions(accountId)");
    }

    // --- MIGRACIÓN V16: ESTANDARIZACIÓN DE CATEGORÍAS ---
    if (oldVersion < 16) {
      // 1. Limpiar categorías antiguas para evitar conflictos o duplicados
      await db.delete('categories');
      
      // 2. Re-insertar desde el Master Seed (AppCategories)
      for (var entry in AppCategories.allCategories.entries) {
        final isIncome = entry.key >= 18 && entry.key <= 25 && entry.key != 20;
        await db.rawInsert(
            "INSERT INTO categories(id, name, icon, color, type) VALUES(?, ?, ?, ?, ?)",
            [
              entry.key, 
              entry.value['name'], 
              entry.value['icon'], 
              entry.value['color'], 
              isIncome ? 'INCOME' : 'EXPENSE'
            ]);
      }
    }

    // --- MIGRACIÓN V17: AÑADIR CATEGORÍA A GASTOS FIJOS ---
    if (oldVersion < 17) {
      try {
        await db.execute(
            "ALTER TABLE fixed_expenses ADD COLUMN categoryId INTEGER DEFAULT 9");
      } catch (e) {
        // Ignorar si ya existe
      }
    }

    // --- MIGRACIÓN V20: WIPE & REBUILD (CLEAN SLATE) ---
    if (oldVersion < 20 && oldVersion > 0) {
      // Destructive Wipe: Limpiar historial anterior
      await db.execute("DROP TABLE IF EXISTS transactions");
      await db.execute("DROP TABLE IF EXISTS fixed_expenses");
      await db.execute("DROP TABLE IF EXISTS goals");
      await db.execute("DROP TABLE IF EXISTS categories");
      await db.execute("DROP TABLE IF EXISTS accounts");
      
      // Recrear esquema desde cero
      await _onCreate(db, newVersion);
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
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

    await db.execute("CREATE INDEX idx_transactions_date ON transactions(date)");
    await db.execute("CREATE INDEX idx_transactions_accountId ON transactions(accountId)");

    await _createFixedExpensesTable(db);
    await _createGoalsTable(db);

    await _seedData(db);
  }

  Future<void> _createFixedExpensesTable(Database db) async {
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
        FOREIGN KEY (accountToCharge) REFERENCES accounts (id) ON DELETE SET NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createGoalsTable(Database db) async {
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
        FOREIGN KEY (accountId) REFERENCES accounts (id) ON DELETE SET NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');
  }

  Future<void> _seedData(Database db) async {
    // 1. Cuentas iniciales por defecto
    await db.insert('accounts', {
      'name': 'Efectivo',
      'type': 'CASH',
      'balance': 0.0,
      'color': 4280391411,
      'currencySymbol': 'S/',
      'iconCode': 58343,
      'includeInTotal': 1
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // 2. Semilla robusta de Categorías asegurando exactamente los 15 IDs mapeados
    await _seedCategories(db);
  }

  Future<void> _seedCategories(Database db) async {
    final categories = [
      // Gastos (1 al 10)
      {'id': 1, 'name': 'Alimentación', 'icon': 'restaurant', 'color': 0xFFF28B82, 'type': 'EXPENSE'},
      {'id': 2, 'name': 'Vivienda', 'icon': 'home', 'color': 0xFF81C995, 'type': 'EXPENSE'},
      {'id': 3, 'name': 'Transporte', 'icon': 'directions_bus', 'color': 0xFF8AB4F8, 'type': 'EXPENSE'},
      {'id': 4, 'name': 'Servicios', 'icon': 'bolt', 'color': 0xFFFDE293, 'type': 'EXPENSE'},
      {'id': 5, 'name': 'Salud', 'icon': 'local_hospital', 'color': 0xFF80DEEA, 'type': 'EXPENSE'},
      {'id': 6, 'name': 'Educación', 'icon': 'school', 'color': 0xFFD7CCC8, 'type': 'EXPENSE'},
      {'id': 7, 'name': 'Entretenimiento', 'icon': 'movie', 'color': 0xFFC58AF9, 'type': 'EXPENSE'},
      {'id': 8, 'name': 'Compras', 'icon': 'shopping_bag', 'color': 0xFFF48FB1, 'type': 'EXPENSE'},
      {'id': 9, 'name': 'Deudas', 'icon': 'money_off', 'color': 0xFFE57373, 'type': 'EXPENSE'},
      {'id': 10, 'name': 'Otros Gastos', 'icon': 'grid_view', 'color': 0xFFB0BEC5, 'type': 'EXPENSE'},
      
      // Ingresos (11 al 15)
      {'id': 11, 'name': 'Sueldo', 'icon': 'monetization_on', 'color': 0xFFA5D6A7, 'type': 'INCOME'},
      {'id': 12, 'name': 'Negocio', 'icon': 'work', 'color': 0xFF9FA8DA, 'type': 'INCOME'},
      {'id': 13, 'name': 'Inversiones', 'icon': 'trending_up', 'color': 0xFFCE93D8, 'type': 'INCOME'},
      {'id': 14, 'name': 'Regalos', 'icon': 'card_giftcard', 'color': 0xFFFFAB91, 'type': 'INCOME'},
      {'id': 15, 'name': 'Otros Ingresos', 'icon': 'category', 'color': 0xFF90A4AE, 'type': 'INCOME'},
    ];

    for (var cat in categories) {
      await db.insert('categories', {
        'id': cat['id'],
        'name': cat['name'],
        'icon': cat['icon'],
        'color': cat['color'],
        'type': cat['type'],
        'is_editable': 0
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> clearAllTables() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('accounts');
    await db.delete('goals');
    await db.delete('fixed_expenses');
    await db.delete('categories');
    await db.delete('sqlite_sequence');
    // Garantizamos que las categorías maestras se re-siembren instantáneamente para evitar fallos de Foreign Key
    await _seedCategories(db);
  }
}
