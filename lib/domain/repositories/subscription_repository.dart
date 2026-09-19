import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../data/models/subscription.dart';

abstract class SubscriptionRepository {
  Future<Either<Failure, List<Subscription>>> getSubscriptions();
  Future<Either<Failure, void>> saveSubscription(Subscription subscription);
  Future<Either<Failure, void>> deleteSubscription(String id);
}
