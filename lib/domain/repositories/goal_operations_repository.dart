import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../entities/transaction_entity.dart';
import '../entities/goal_entity.dart';

abstract class GoalOperationsRepository {
  Future<Either<Failure, List<GoalEntity>>> getGoals();
  Future<Either<Failure, void>> saveGoal(GoalEntity goal);
  
  Future<Either<Failure, void>> depositToGoalAtomic(
      String goalId, TransactionEntity transaction);
  Future<Either<Failure, void>> purchaseGoalAtomic(
      String goalId, TransactionEntity transaction);
  Future<Either<Failure, void>> deleteGoalAtomic(String goalId,
      {TransactionEntity? refundTransaction});
}
