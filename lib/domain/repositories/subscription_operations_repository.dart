import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../data/models/subscription.dart';
import '../entities/transaction_entity.dart';

abstract class SubscriptionOperationsRepository {
  /// Atomic operation to mark a subscription as paid.
  /// This creates the financial transaction, adjusts the account balance,
  /// and updates the subscription status inside a single SQLite transaction.
  Future<Either<Failure, void>> paySubscriptionAtomic({
    required Subscription subscription,
    required TransactionEntity transaction,
  });
}
