import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../entities/account_entity.dart';
import '../entities/balance_breakdown.dart';

abstract class AccountRepository {
  Future<Either<Failure, List<AccountEntity>>> getAccounts();
  Future<Either<Failure, int>> createAccount(AccountEntity account);
  Future<Either<Failure, void>> updateAccount(AccountEntity account);
  Future<Either<Failure, void>> deleteAccount(int id);
  Future<Either<Failure, BalanceBreakdown>> getBalanceBreakdown();
  Future<Either<Failure, double>> getMonthlyBudget();
}
