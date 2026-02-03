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
      final transactionModel = TransactionModel.fromEntity(transaction);
      transactions.add(transactionModel);
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
      // Los modelos (TransactionModel) extienden de la entidad (TransactionEntity),
      // por lo que podemos retornarlos directamente como una lista de entidades.
      return Right(transactionModels);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
