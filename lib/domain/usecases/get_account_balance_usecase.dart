import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../entities/balance_breakdown.dart';
import '../repositories/transaction_repository.dart';

class GetAccountBalanceUseCase implements UseCase<BalanceBreakdown, NoParams> {
  final TransactionRepository repository;

  GetAccountBalanceUseCase(this.repository);

  @override
  Future<Either<Failure, BalanceBreakdown>> call(NoParams params) async {
    return await repository.getBalanceBreakdown();
  }
}
