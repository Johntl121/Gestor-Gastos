import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/balance_breakdown.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/local_database.dart';
import '../datasources/transaction_local_data_source.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final LocalDatabase localDatabase;
  final TransactionLocalDataSource transactionLocalDataSource;

  TransactionRepositoryImpl({
    required this.localDatabase,
    required this.transactionLocalDataSource,
  });

  @override
  Future<Either<Failure, void>> addTransaction(
      TransactionEntity transaction) async {
    try {
      // 1. Persistir en Shared Preferences (Lista de Transacciones)
      final transactions = await transactionLocalDataSource.getTransactions();

      // Generate ID
      final newId = DateTime.now().millisecondsSinceEpoch;
      final transactionWithId = TransactionModel(
          id: newId,
          accountId: transaction.accountId,
          categoryId: transaction.categoryId,
          amount: transaction.amount,
          date: transaction.date,
          description: transaction.description,
          note: transaction.note);

      transactions.add(transactionWithId);
      await transactionLocalDataSource.cacheTransactions(transactions);

      // 2. Actualizar Saldo de Cuenta en SQL (LocalDatabase)
      final db = await localDatabase.database;

      // 2. Actualizar Saldo de Cuenta en SQL (LocalDatabase)
      // Confiamos en el signo de 'transaction.amount' que viene de la UI/Lógica
      await db.rawUpdate('''
          UPDATE accounts 
          SET balance = balance + ? 
          WHERE id = ?
        ''', [transaction.amount, transaction.accountId]);

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BalanceBreakdown>> getBalanceBreakdown() async {
    try {
      final db = await localDatabase.database;

      // Obtener todas las cuentas
      final List<Map<String, dynamic>> accountsMap = await db.query('accounts');
      final accounts =
          accountsMap.map((e) => AccountModel.fromJson(e)).toList();

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
      // Obtener transacciones desde SharedPrefs
      final transactions = await transactionLocalDataSource.getTransactions();

      final now = DateTime.now();

      // Filtrar por mes actual y sumar
      double totalExpenses = 0.0;

      for (var t in transactions) {
        // Filtramos por fecha y por signo negativo (Gasto real)
        if (t.date.year == now.year && t.date.month == now.month) {
          if (t.amount < 0) {
            totalExpenses += t.amount;
          }
        }
      }

      return Right(totalExpenses);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getMonthlyBudget() async {
    try {
      final budget = transactionLocalDataSource.getBudgetLimit();
      return Right(budget);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactions() async {
    try {
      final transactionModels =
          await transactionLocalDataSource.getTransactions();

      // Auto-fixing corrupt data (null IDs)
      bool needsFix = false;
      for (int i = 0; i < transactionModels.length; i++) {
        if (transactionModels[i].id == null) {
          needsFix = true;
          // Generate unique ID based on index to avoid collision
          final fixedId = DateTime.now().millisecondsSinceEpoch + i;
          transactionModels[i] = TransactionModel(
              id: fixedId,
              accountId: transactionModels[i].accountId,
              categoryId: transactionModels[i].categoryId,
              amount: transactionModels[i].amount,
              date: transactionModels[i].date,
              description: transactionModels[i].description,
              note: transactionModels[i].note);
        }
      }

      if (needsFix) {
        await transactionLocalDataSource.cacheTransactions(transactionModels);
      }

      // Los modelos (TransactionModel) extienden de la entidad (TransactionEntity),
      // por lo que podemos retornarlos directamente como una lista de entidades.
      return Right(transactionModels);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateTransaction(
      TransactionEntity transaction) async {
    try {
      final transactions = await transactionLocalDataSource.getTransactions();
      final index = transactions.indexWhere((t) => t.id == transaction.id);

      if (index != -1) {
        final oldTransaction = transactions[index];
        final double diff = transaction.amount - oldTransaction.amount;

        // Update list
        transactions[index] = TransactionModel.fromEntity(transaction);
        await transactionLocalDataSource.cacheTransactions(transactions);

        // Update Account Balance if amount changed
        if (diff != 0) {
          final db = await localDatabase.database;
          await db.rawUpdate('''
            UPDATE accounts 
            SET balance = balance + ? 
            WHERE id = ?
          ''', [diff, transaction.accountId]);
        }
      }
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTransaction(int id) async {
    try {
      final transactions = await transactionLocalDataSource.getTransactions();
      final index = transactions.indexWhere((t) => t.id == id);

      if (index != -1) {
        final transactionToDelete = transactions[index];

        // Remove from list
        transactions.removeAt(index);
        await transactionLocalDataSource.cacheTransactions(transactions);

        // Restore Account Balance (Subtract the transaction amount)
        // If it was -50 (expense), we subtract -50 => +50 (refund).
        // If it was +100 (income), we subtract +100 => -100 (remove income).
        final db = await localDatabase.database;
        await db.rawUpdate('''
            UPDATE accounts 
            SET balance = balance - ? 
            WHERE id = ?
          ''', [transactionToDelete.amount, transactionToDelete.accountId]);
      }
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
