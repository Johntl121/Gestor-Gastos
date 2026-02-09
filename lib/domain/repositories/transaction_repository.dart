import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../entities/transaction_entity.dart';
import '../entities/account_entity.dart';
import '../entities/balance_breakdown.dart';

abstract class TransactionRepository {
  Future<Either<Failure, void>> addTransaction(TransactionEntity transaction);
  Future<Either<Failure, BalanceBreakdown>> getBalanceBreakdown();
  Future<Either<Failure, double>> getCurrentMonthExpenses();
  Future<Either<Failure, double>> getMonthlyBudget();
  Future<Either<Failure, List<TransactionEntity>>> getTransactions();
  Future<Either<Failure, void>> updateTransaction(
      TransactionEntity transaction);
  Future<Either<Failure, void>> deleteTransaction(int id);

  // Custom Accounts
  Future<Either<Failure, List<AccountEntity>>> getAccounts();
  Future<Either<Failure, void>> createAccount(AccountEntity account);
  Future<Either<Failure, void>> updateAccount(AccountEntity account);
  Future<Either<Failure, void>> deleteAccount(int id);
}
