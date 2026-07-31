import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../entities/transaction_entity.dart';


abstract class TransactionRepository {
  Future<Either<Failure, void>> addTransaction(TransactionEntity transaction,
      {bool updateBalance = true});
  Future<Either<Failure, double>> getCurrentMonthExpenses();
  Future<Either<Failure, List<TransactionEntity>>> getTransactions({int limit = 50, int offset = 0});
  Future<Either<Failure, List<TransactionEntity>>> getTransactionsByDateRange(DateTime start, DateTime end);
  Future<Either<Failure, void>> updateTransaction(
      TransactionEntity transaction);
  Future<Either<Failure, void>> deleteTransaction(int id);
}
