import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';

const String CACHED_TRANSACTIONS_KEY = 'CACHED_TRANSACTIONS';
const String KEY_FIRST_TIME = 'FIRST_TIME';
const String KEY_USER_NAME = 'USER_NAME';
const String KEY_BUDGET_LIMIT = 'BUDGET_LIMIT';

abstract class TransactionLocalDataSource {
  Future<List<TransactionModel>> getTransactions();
  Future<void> cacheTransactions(List<TransactionModel> transactions);

  bool isFirstTime();
  Future<void> setFirstTime(bool value);
  Future<void> saveUserName(String name);
  String? getUserName();
  Future<void> saveBudgetLimit(double amount);
  double getBudgetLimit();
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
}
