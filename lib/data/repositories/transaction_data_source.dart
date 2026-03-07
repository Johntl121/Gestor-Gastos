import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/subscription.dart';
import '../models/goal_model.dart';

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
  Future<List<TransactionModel>> getTransactions();
  Future<void> cacheTransactions(List<TransactionModel> transactions);

  Future<List<Subscription>> getSubscriptions();
  Future<void> cacheSubscriptions(List<Subscription> subscriptions);

  Future<List<GoalModel>> getGoals();
  Future<void> cacheGoals(List<GoalModel> goals);

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
  Future<void> clearAllData();
}

class TransactionLocalDataSourceImpl implements TransactionLocalDataSource {
  final SharedPreferences sharedPreferences;

  TransactionLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<List<TransactionModel>> getTransactions() {
    final jsonString = sharedPreferences.getString(cachedTransactionsKey);
    if (jsonString != null) {
      List<dynamic> jsonList = json.decode(jsonString);
      List<TransactionModel> transactions = jsonList
          .map((jsonItem) => TransactionModel.fromJson(jsonItem))
          .toList();
      return Future.value(transactions);
    } else {
      return Future.value([]);
    }
  }

  @override
  Future<void> cacheTransactions(List<TransactionModel> transactions) {
    List<Map<String, dynamic>> jsonList =
        transactions.map((transaction) => transaction.toJson()).toList();
    final String jsonString = json.encode(jsonList);
    return sharedPreferences.setString(cachedTransactionsKey, jsonString);
  }

  @override
  Future<List<Subscription>> getSubscriptions() {
    final jsonString = sharedPreferences.getString(cachedSubscriptionsKey);
    if (jsonString != null) {
      List<dynamic> jsonList = json.decode(jsonString);
      return Future.value(
          jsonList.map((j) => Subscription.fromJson(j)).toList());
    }
    return Future.value([]);
  }

  @override
  Future<void> cacheSubscriptions(List<Subscription> subscriptions) {
    List<Map<String, dynamic>> jsonList =
        subscriptions.map((s) => s.toJson()).toList();
    return sharedPreferences.setString(
        cachedSubscriptionsKey, json.encode(jsonList));
  }

  @override
  Future<List<GoalModel>> getGoals() {
    final jsonString = sharedPreferences.getString(cachedGoalsKey);
    if (jsonString != null) {
      List<dynamic> jsonList = json.decode(jsonString);
      return Future.value(jsonList.map((j) => GoalModel.fromJson(j)).toList());
    }
    return Future.value([]);
  }

  @override
  Future<void> cacheGoals(List<GoalModel> goals) {
    List<Map<String, dynamic>> jsonList = goals.map((g) => g.toJson()).toList();
    return sharedPreferences.setString(cachedGoalsKey, json.encode(jsonList));
  }

  @override
  bool isFirstTime() {
    return sharedPreferences.getBool(keyFirstTime) ?? true;
  }

  @override
  Future<void> setFirstTime(bool value) {
    return sharedPreferences.setBool(keyFirstTime, value);
  }

  @override
  Future<void> saveUserName(String name) {
    return sharedPreferences.setString(keyUserName, name);
  }

  @override
  String? getUserName() {
    return sharedPreferences.getString(keyUserName);
  }

  @override
  Future<void> saveBudgetLimit(double amount) {
    return sharedPreferences.setDouble(keyBudgetLimit, amount);
  }

  @override
  double getBudgetLimit() {
    return sharedPreferences.getDouble(keyBudgetLimit) ?? 2400.00; // Default
  }

  @override
  Future<void> saveCurrency(String symbol) {
    return sharedPreferences.setString(keyCurrency, symbol);
  }

  @override
  String getCurrency() {
    return sharedPreferences.getString(keyCurrency) ?? 'S/';
  }

  @override
  Future<void> saveSecurityPin(String? pin) {
    if (pin == null) {
      return sharedPreferences.remove(keySecurityPin);
    }
    return sharedPreferences.setString(keySecurityPin, pin);
  }

  @override
  String? getSecurityPin() {
    return sharedPreferences.getString(keySecurityPin);
  }

  @override
  Future<void> saveUserAvatar(String avatar) {
    return sharedPreferences.setString(keyUserAvatar, avatar);
  }

  @override
  String getUserAvatar() {
    return sharedPreferences.getString(keyUserAvatar) ?? '😎';
  }

  @override
  Future<void> saveProfileImagePath(String? path) {
    if (path == null) {
      return sharedPreferences.remove(keyProfileImagePath);
    }
    return sharedPreferences.setString(keyProfileImagePath, path);
  }

  @override
  String? getProfileImagePath() {
    return sharedPreferences.getString(keyProfileImagePath);
  }

  @override
  Future<void> saveThemeMode(bool isDark) {
    return sharedPreferences.setBool(keyThemeMode, isDark);
  }

  @override
  bool getThemeMode() {
    return sharedPreferences.getBool(keyThemeMode) ?? true; // Default dark
  }

  @override
  Future<void> clearAllData() async {
    // We should preserve the theme even if data is cleared, or maybe not.
    // We will clear all to be safe, but they might want theme preserved.
    final currentTheme = getThemeMode();
    await sharedPreferences.clear();
    await saveThemeMode(currentTheme); // Restore theme after wipe
  }
}
