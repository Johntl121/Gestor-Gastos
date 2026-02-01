import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../entities/transaction_entity.dart';
import '../entities/balance_breakdown.dart';

abstract class TransactionRepository {
  Future<Either<Failure, void>> addTransaction(TransactionEntity transaction);
  Future<Either<Failure, BalanceBreakdown>> getBalanceBreakdown();
  Future<Either<Failure, double>> getCurrentMonthExpenses();
  Future<Either<Failure, double>> getMonthlyBudget();
}
