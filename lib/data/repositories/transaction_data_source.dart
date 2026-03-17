import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/database_helper.dart';
import '../models/transaction_model.dart';
import '../models/subscription.dart';
import '../models/goal_model.dart';
import '../../core/services/secure_storage_service.dart';

const String cachedTransactionsKey = 'CACHED_TRANSACTIONS';
const String cachedSubscriptionsKey = 'CACHED_SUBSCRIPTIONS';
const String cachedGoalsKey = 'CACHED_GOALS';
const String keyFirstTime = 'FIRST_TIME';
const String keyUserName = 'USER_NAME';
const String keyCurrency = 'CURRENCY';
const String keyBudgetLimit = 'BUDGET_LIMIT';
const String keySecurityPin = 'SECURITY_PIN';
const String keyUserAvatar = 'USER_AVATAR';
const String keyProfileImagePath = 'PROFILE_IMAGE_PATH';
const String keyThemeMode = 'THEME_MODE';

abstract class TransactionLocalDataSource {
  // Transacciones (Ahora en SQLite)
  Future<List<TransactionModel>> getTransactions();
  Future<List<TransactionModel>> getTransactionsByDateRange(DateTime start, DateTime end);
  Future<void> saveTransaction(TransactionModel transaction);
  Future<void> updateTransaction(TransactionModel transaction);
  Future<void> deleteTransaction(int id);

  // Otros datos (Migrados a SQLite)
  Future<List<Subscription>> getSubscriptions();
  Future<void> saveSubscription(Subscription subscription);
  Future<void> deleteSubscription(String id);
  
  Future<List<GoalModel>> getGoals();
  Future<void> saveGoal(GoalModel goal);
  Future<void> deleteGoal(String id);

  // Script de Migración
  Future<void> migrateDataFromPrefsToSql();
  Future<void> migratePinIfNeeded();

  // Preferencias de Usuario
  bool isFirstTime();
  Future<void> setFirstTime(bool value);
  Future<void> saveUserName(String name);
  String? getUserName();
  Future<void> saveBudgetLimit(double amount);
  double getBudgetLimit();
  Future<void> saveCurrency(String symbol);
  String getCurrency();
  Future<void> saveSecurityPin(String? pin);
  String? getSecurityPin();
  Future<void> saveUserAvatar(String avatar);
  String getUserAvatar();
  Future<void> saveProfileImagePath(String? path);
  String? getProfileImagePath();
  Future<void> saveThemeMode(bool isDark);
  bool getThemeMode();
  Future<String?> getSecurityPinAsync();
  Future<void> clearAllData();
}

class TransactionLocalDataSourceImpl implements TransactionLocalDataSource {
  final SharedPreferences sharedPreferences;
  final LocalDatabase localDatabase;
  final SecureStorageService secureStorage;

  TransactionLocalDataSourceImpl({
    required this.sharedPreferences,
    required this.localDatabase,
    required this.secureStorage,
  });

  String get _transactionJoinQuery => '''
    SELECT t.*, c.name as cat_name, c.icon as cat_icon, c.color as cat_color, a.name as acc_name
    FROM transactions t
    LEFT JOIN categories c ON t.categoryId = c.id
    LEFT JOIN accounts a ON t.accountId = a.id
  ''';

  @override
  Future<List<TransactionModel>> getTransactions() async {
    final db = await localDatabase.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '$_transactionJoinQuery ORDER BY t.date DESC'
    );
    
    return maps.map((m) => TransactionModel.fromJson(m)).toList();
  }

  @override
  Future<List<TransactionModel>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    final db = await localDatabase.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '$_transactionJoinQuery WHERE t.date >= ? AND t.date <= ? ORDER BY t.date DESC',
      [start.toIso8601String(), end.toIso8601String()]
    );
    
    return maps.map((m) => TransactionModel.fromJson(m)).toList();
  }

  @override
  Future<void> saveTransaction(TransactionModel transaction) async {
    final db = await localDatabase.database;
    await db.insert('transactions', transaction.toJson());
  }

  @override
  Future<void> updateTransaction(TransactionModel transaction) async {
    final db = await localDatabase.database;
    await db.update(
      'transactions',
      transaction.toJson(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  @override
  Future<void> deleteTransaction(int id) async {
    final db = await localDatabase.database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Mantenemos SharedPreferences para lo demás ---

  // --- SQLite para Subscriptions y Goals ---

  @override
  Future<List<Subscription>> getSubscriptions() async {
    final db = await localDatabase.database;
    final List<Map<String, dynamic>> maps = await db.query('fixed_expenses');
    return maps.map((j) => Subscription.fromJson(j)).toList();
  }

  @override
  Future<void> saveSubscription(Subscription subscription) async {
    final db = await localDatabase.database;
    await db.insert('fixed_expenses', subscription.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteSubscription(String id) async {
    final db = await localDatabase.database;
    await db.delete('fixed_expenses', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<GoalModel>> getGoals() async {
    final db = await localDatabase.database;
    final List<Map<String, dynamic>> maps = await db.query('goals');
    return maps.map((j) => GoalModel.fromJson(j)).toList();
  }

  @override
  Future<void> saveGoal(GoalModel goal) async {
    final db = await localDatabase.database;
    await db.insert('goals', goal.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteGoal(String id) async {
    final db = await localDatabase.database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> migrateDataFromPrefsToSql() async {
    // 1. Migrar Subscriptions
    final subJson = sharedPreferences.getString(cachedSubscriptionsKey);
    if (subJson != null) {
      try {
        List<dynamic> jsonList = json.decode(subJson);
        for (var j in jsonList) {
          await saveSubscription(Subscription.fromJson(j));
        }
        await sharedPreferences.remove(cachedSubscriptionsKey);
        debugPrint("✅ Migración exitosa: Subscriptions movidas a SQLite");
      } catch (e) {
        debugPrint("❌ Error migrando Subscriptions: $e");
      }
    }

    // 2. Migrar Goals
    final goalJson = sharedPreferences.getString(cachedGoalsKey);
    if (goalJson != null) {
      try {
        List<dynamic> jsonList = json.decode(goalJson);
        for (var j in jsonList) {
          await saveGoal(GoalModel.fromJson(j));
        }
        await sharedPreferences.remove(cachedGoalsKey);
        debugPrint("✅ Migración exitosa: Goals movidas a SQLite");
      } catch (e) {
        debugPrint("❌ Error migrando Goals: $e");
      }
    }
  }

  @override
  Future<void> migratePinIfNeeded() async {
    final oldPin = sharedPreferences.getString(keySecurityPin);
    if (oldPin != null) {
      try {
        await secureStorage.savePin(oldPin);
        await sharedPreferences.remove(keySecurityPin);
        debugPrint("🔐 Migración exitosa: PIN movido a almacenamiento seguro");
      } catch (e) {
        debugPrint("❌ Error migrando PIN: $e");
      }
    }
  }

  @override
  bool isFirstTime() => sharedPreferences.getBool(keyFirstTime) ?? true;

  @override
  Future<void> setFirstTime(bool value) => sharedPreferences.setBool(keyFirstTime, value);

  @override
  Future<void> saveUserName(String name) => sharedPreferences.setString(keyUserName, name);

  @override
  String? getUserName() => sharedPreferences.getString(keyUserName);

  @override
  Future<void> saveBudgetLimit(double amount) => sharedPreferences.setDouble(keyBudgetLimit, amount);

  @override
  double getBudgetLimit() => sharedPreferences.getDouble(keyBudgetLimit) ?? 2400.00;

  @override
  Future<void> saveCurrency(String symbol) => sharedPreferences.setString(keyCurrency, symbol);

  @override
  String getCurrency() => sharedPreferences.getString(keyCurrency) ?? 'S/';

  @override
  Future<void> saveSecurityPin(String? pin) async {
    if (pin == null) {
      await secureStorage.deletePin();
      return;
    }
    await secureStorage.savePin(pin);
  }

  @override
  String? getSecurityPin() {
    // Nota: SharedPreferences es sincrono, pero SecureStorage es ASÍNCRONO.
    // Necesitaremos manejar esto en el Provider si getSecurityPin() es usado en tiempo real.
    // Por simplicidad en la interfaz original, devolvemos null aquí y confiamos en el Provider 
    // que use SecureStorage directamente o maneje el Future.
    return null; 
  }

  @override
  Future<String?> getSecurityPinAsync() => secureStorage.getPin();

  @override
  Future<void> saveUserAvatar(String avatar) => sharedPreferences.setString(keyUserAvatar, avatar);

  @override
  String getUserAvatar() => sharedPreferences.getString(keyUserAvatar) ?? '😎';

  @override
  Future<void> saveProfileImagePath(String? path) {
    if (path == null) return sharedPreferences.remove(keyProfileImagePath);
    return sharedPreferences.setString(keyProfileImagePath, path);
  }

  @override
  String? getProfileImagePath() => sharedPreferences.getString(keyProfileImagePath);

  @override
  Future<void> saveThemeMode(bool isDark) => sharedPreferences.setBool(keyThemeMode, isDark);

  @override
  bool getThemeMode() => sharedPreferences.getBool(keyThemeMode) ?? true;

  @override
  Future<void> clearAllData() async {
    final currentTheme = getThemeMode();
    await sharedPreferences.clear();
    await localDatabase.clearAllTables();
    await saveThemeMode(currentTheme);
  }
}
