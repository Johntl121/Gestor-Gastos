
import '../../core/services/database_helper.dart';
import '../models/transaction_model.dart';

abstract class TransactionLocalDataSource {
  Future<List<TransactionModel>> getTransactions({int limit = 50, int offset = 0});
  Future<List<TransactionModel>> getTransactionsByDateRange(DateTime start, DateTime end);
  Future<void> saveTransaction(TransactionModel transaction);
  Future<void> updateTransaction(TransactionModel transaction);
  Future<void> deleteTransaction(int id);
}

class TransactionLocalDataSourceImpl implements TransactionLocalDataSource {
  final LocalDatabase localDatabase;

  TransactionLocalDataSourceImpl({required this.localDatabase});

  String get _transactionJoinQuery => '''
    SELECT t.*, c.name as cat_name, c.icon as cat_icon, c.color as cat_color, a.name as acc_name
    FROM transactions t
    LEFT JOIN categories c ON t.categoryId = c.id
    LEFT JOIN accounts a ON t.accountId = a.id
  ''';

  @override
  Future<List<TransactionModel>> getTransactions({int limit = 50, int offset = 0}) async {
    final db = await localDatabase.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '$_transactionJoinQuery ORDER BY t.date DESC LIMIT ? OFFSET ?',
      [limit, offset]
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
}
