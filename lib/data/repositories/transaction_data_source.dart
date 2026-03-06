import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/subscription.dart';
import '../models/goal_model.dart';

const String CACHED_TRANSACTIONS_KEY = 'CACHED_TRANSACTIONS';
const String CACHED_SUBSCRIPTIONS_KEY = 'CACHED_SUBSCRIPTIONS';
const String CACHED_GOALS_KEY = 'CACHED_GOALS';
const String KEY_FIRST_TIME = 'FIRST_TIME';
const String KEY_USER_NAME = 'USER_NAME';
const String KEY_CURRENCY = 'CURRENCY';
const String KEY_BUDGET_LIMIT = 'BUDGET_LIMIT';
const String KEY_SECURITY_PIN = 'SECURITY_PIN';
const String KEY_USER_AVATAR = 'USER_AVATAR';
const String KEY_PROFILE_IMAGE_PATH = 'PROFILE_IMAGE_PATH';
const String KEY_THEME_MODE = 'THEME_MODE';

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
    final jsonString = sharedPreferences.getString(CACHED_TRANSACTIONS_KEY);
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
    return sharedPreferences.setString(CACHED_TRANSACTIONS_KEY, jsonString);
  }

  @override
  Future<List<Subscription>> getSubscriptions() {
    final jsonString = sharedPreferences.getString(CACHED_SUBSCRIPTIONS_KEY);
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
        CACHED_SUBSCRIPTIONS_KEY, json.encode(jsonList));
  }

  @override
  Future<List<GoalModel>> getGoals() {
    final jsonString = sharedPreferences.getString(CACHED_GOALS_KEY);
    if (jsonString != null) {
      List<dynamic> jsonList = json.decode(jsonString);
      return Future.value(jsonList.map((j) => GoalModel.fromJson(j)).toList());
    }
    return Future.value([]);
  }

  @override
  Future<void> cacheGoals(List<GoalModel> goals) {
    List<Map<String, dynamic>> jsonList = goals.map((g) => g.toJson()).toList();
    return sharedPreferences.setString(CACHED_GOALS_KEY, json.encode(jsonList));
  }

  @override
  bool isFirstTime() {
    return sharedPreferences.getBool(KEY_FIRST_TIME) ?? true;
  }

  @override
  Future<void> setFirstTime(bool value) {
    return sharedPreferences.setBool(KEY_FIRST_TIME, value);
  }

  @override
  Future<void> saveUserName(String name) {
    return sharedPreferences.setString(KEY_USER_NAME, name);
  }

  @override
  String? getUserName() {
    return sharedPreferences.getString(KEY_USER_NAME);
  }

  @override
  Future<void> saveBudgetLimit(double amount) {
    return sharedPreferences.setDouble(KEY_BUDGET_LIMIT, amount);
  }

  @override
  double getBudgetLimit() {
    return sharedPreferences.getDouble(KEY_BUDGET_LIMIT) ?? 2400.00; // Default
  }

  @override
  Future<void> saveCurrency(String symbol) {
    return sharedPreferences.setString(KEY_CURRENCY, symbol);
  }

  @override
  String getCurrency() {
    return sharedPreferences.getString(KEY_CURRENCY) ?? 'S/';
  }

  @override
  Future<void> saveSecurityPin(String? pin) {
    if (pin == null) {
      return sharedPreferences.remove(KEY_SECURITY_PIN);
    }
    return sharedPreferences.setString(KEY_SECURITY_PIN, pin);
  }

  @override
  String? getSecurityPin() {
    return sharedPreferences.getString(KEY_SECURITY_PIN);
  }

  @override
  Future<void> saveUserAvatar(String avatar) {
    return sharedPreferences.setString(KEY_USER_AVATAR, avatar);
  }

  @override
  String getUserAvatar() {
    return sharedPreferences.getString(KEY_USER_AVATAR) ?? '😎';
  }

  @override
  Future<void> saveProfileImagePath(String? path) {
    if (path == null) {
      return sharedPreferences.remove(KEY_PROFILE_IMAGE_PATH);
    }
    return sharedPreferences.setString(KEY_PROFILE_IMAGE_PATH, path);
  }

  @override
  String? getProfileImagePath() {
    return sharedPreferences.getString(KEY_PROFILE_IMAGE_PATH);
  }

  @override
  Future<void> saveThemeMode(bool isDark) {
    return sharedPreferences.setBool(KEY_THEME_MODE, isDark);
  }

  @override
  bool getThemeMode() {
    return sharedPreferences.getBool(KEY_THEME_MODE) ?? true; // Default dark
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
