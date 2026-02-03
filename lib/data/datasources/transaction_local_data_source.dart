import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';

abstract class TransactionLocalDataSource {
  Future<List<TransactionModel>> getTransactions();
  Future<void> cacheTransactions(List<TransactionModel> transactions);
}

const String CACHED_TRANSACTIONS_KEY = 'CACHED_TRANSACTIONS';

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
}
