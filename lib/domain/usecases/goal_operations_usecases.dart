import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../entities/transaction_entity.dart';
import '../repositories/goal_operations_repository.dart';

class DepositToGoalUseCase implements UseCase<void, DepositToGoalParams> {
  final GoalOperationsRepository repository;

  DepositToGoalUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DepositToGoalParams params) async {
    return await repository.depositToGoalAtomic(
        params.goalId, params.transaction);
  }
}

class DepositToGoalParams {
  final String goalId;
  final TransactionEntity transaction;

  DepositToGoalParams({required this.goalId, required this.transaction});
}

class PurchaseGoalUseCase implements UseCase<void, PurchaseGoalParams> {
  final GoalOperationsRepository repository;

  PurchaseGoalUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(PurchaseGoalParams params) async {
    return await repository.purchaseGoalAtomic(
        params.goalId, params.transaction);
  }
}

class PurchaseGoalParams {
  final String goalId;
  final TransactionEntity transaction;

  PurchaseGoalParams({required this.goalId, required this.transaction});
}

class DeleteGoalAtomicUseCase implements UseCase<void, DeleteGoalAtomicParams> {
  final GoalOperationsRepository repository;

  DeleteGoalAtomicUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteGoalAtomicParams params) async {
    return await repository.deleteGoalAtomic(params.goalId,
        refundTransaction: params.refundTransaction);
  }
}

class DeleteGoalAtomicParams {
  final String goalId;
  final TransactionEntity? refundTransaction;

  DeleteGoalAtomicParams({required this.goalId, this.refundTransaction});
}
