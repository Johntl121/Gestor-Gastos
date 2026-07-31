import 'package:dartz/dartz.dart';

import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/account_repository.dart';

class GetMonthlyBudgetUseCase implements UseCase<double, NoParams> {
  final AccountRepository repository;

  GetMonthlyBudgetUseCase(this.repository);

  @override
  Future<Either<Failure, double>> call(NoParams params) async {
    return await repository.getMonthlyBudget();
  }
}
