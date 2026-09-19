import 'package:dartz/dartz.dart';
import '../../../core/errors/failure.dart';
import '../../../data/models/subscription.dart';
import '../../entities/transaction_entity.dart';
import '../../repositories/subscription_operations_repository.dart';

class PaySubscriptionParams {
  final Subscription subscription;
  final TransactionEntity transaction;

  const PaySubscriptionParams({
    required this.subscription,
    required this.transaction,
  });
}

class PaySubscriptionUseCase {
  final SubscriptionOperationsRepository repository;

  PaySubscriptionUseCase(this.repository);

  Future<Either<Failure, void>> call(PaySubscriptionParams params) async {
    return await repository.paySubscriptionAtomic(
      subscription: params.subscription,
      transaction: params.transaction,
    );
  }
}
