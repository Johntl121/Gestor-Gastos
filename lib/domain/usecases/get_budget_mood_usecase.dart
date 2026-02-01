import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../entities/budget_mood.dart';
import '../repositories/transaction_repository.dart';

class GetBudgetMoodUseCase implements UseCase<BudgetMood, NoParams> {
  final TransactionRepository repository;

  GetBudgetMoodUseCase(this.repository);

  @override
  Future<Either<Failure, BudgetMood>> call(NoParams params) async {
    final expensesResult = await repository.getCurrentMonthExpenses();
    final budgetResult = await repository.getMonthlyBudget();

    return expensesResult.fold(
      (failure) => Left(failure),
      (expenses) => budgetResult.fold(
        (failure) => Left(failure),
        (budget) {
          if (budget == 0) return const Right(BudgetMood.neutral); // Avoid division by zero
          
          final percentage = expenses / budget;

          if (percentage < 0.5) {
            return const Right(BudgetMood.happy);
          } else if (percentage <= 0.8) {
            return const Right(BudgetMood.neutral);
          } else {
            return const Right(BudgetMood.sad);
          }
        },
      ),
    );
  }
}
