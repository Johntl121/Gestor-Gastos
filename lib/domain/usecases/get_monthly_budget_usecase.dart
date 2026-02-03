import 'package:dartz/dartz.dart';

import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/transaction_repository.dart';

class GetMonthlyBudgetUseCase implements UseCase<double, NoParams> {
  final TransactionRepository repository;

  GetMonthlyBudgetUseCase(this.repository);

  @override
  Future<Either<Failure, double>> call(NoParams params) async {
    return await repository.getMonthlyBudget();
  }
}
