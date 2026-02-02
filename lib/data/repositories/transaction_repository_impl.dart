import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/balance_breakdown.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/local_database.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final LocalDatabase localDatabase;

  TransactionRepositoryImpl(this.localDatabase);

  @override
  Future<Either<Failure, void>> addTransaction(TransactionEntity transaction) async {
    try {
      final db = await localDatabase.database;
      final transactionModel = TransactionModel.fromEntity(transaction);
      
      await db.transaction((txn) async {
        // 1. Insert Transaction
        await txn.insert(
          'transactions',
          transactionModel.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 2. Update Account Balance
        // Check if it's Expense or Income would require checking the Category, 
        // but for MVP let's assume negative amount is expense, positive is income in the UI logic?
        // OR better: query the category type.
        
        // For now, let's assume the amount passed IS the delta to apply.
        // If it's an expense, the usecase should pass a negative value or we should handle it here.
        // Let's implement a safer approach:
        
        // Get category to check type
        final List<Map<String, dynamic>> categoryResult = await txn.query(
          'categories',
          columns: ['type'],
          where: 'id = ?',
          whereArgs: [transaction.categoryId],
        );
        
        if (categoryResult.isNotEmpty) {
           final type = categoryResult.first['type'] as String;
           double amountToApply = transaction.amount;
           
           // If it is an expense, we subtract (make negative if positive)
           if (type == 'EXPENSE') {
             amountToApply = -transaction.amount.abs();
           } else {
             // Income adds up
             amountToApply = transaction.amount.abs();
           }

           // Update Account
           await txn.rawUpdate('''
             UPDATE accounts 
             SET balance = balance + ? 
             WHERE id = ?
           ''', [amountToApply, transaction.accountId]);
        }
      });
      
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BalanceBreakdown>> getBalanceBreakdown() async {
    try {
      final db = await localDatabase.database;
      
      // Get all accounts
      final List<Map<String, dynamic>> accountsMap = await db.query('accounts');
      final accounts = accountsMap.map((e) => AccountModel.fromJson(e)).toList();

      double total = 0;
      double cash = 0;
      double digital = 0;

      for (var account in accounts) {
        total += account.currentBalance;
        if (account.type == AccountEnumType.cash) {
          cash += account.currentBalance;
        } else {
          digital += account.currentBalance;
        }
      }

      return Right(BalanceBreakdown(
        total: total,
        cash: cash,
        digital: digital,
      ));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getCurrentMonthExpenses() async {
    try {
      final db = await localDatabase.database;
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
      final endOfMonth = DateTime(now.year, now.month + 1, 0).toIso8601String();

      // Query sum of transactions where category type is EXPENSE
      final result = await db.rawQuery('''
        SELECT SUM(t.amount) as total
        FROM transactions t
        JOIN categories c ON t.categoryId = c.id
        WHERE c.type = 'EXPENSE' 
        AND t.date BETWEEN ? AND ?
      ''', [startOfMonth, endOfMonth]);

      double totalExpenses = 0.0;
      if (result.first['total'] != null) {
        totalExpenses = (result.first['total'] as num).toDouble();
      }

      return Right(totalExpenses);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getMonthlyBudget() async {
    // TODO: Implement Logic to get defined budget. 
    // For MVP, returning a hardcoded mockup value or fetching from a settings table.
    // Let's assume a default budget or create a settings table later.
    return const Right(2000.00); // Mock Budget: 2000 Soles
  }
}
