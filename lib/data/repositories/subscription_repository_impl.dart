import 'package:dartz/dartz.dart';
import '../../../core/errors/failure.dart';
import '../../../data/models/subscription.dart';
import '../../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_local_data_source.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionLocalDataSource localDataSource;

  SubscriptionRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<Subscription>>> getSubscriptions() async {
    try {
      final subscriptions = await localDataSource.getSubscriptions();
      return Right(subscriptions);
    } catch (e) {
      return Left(CacheFailure('Error retrieving subscriptions: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveSubscription(Subscription subscription) async {
    try {
      await localDataSource.saveSubscription(subscription);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Error saving subscription: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSubscription(String id) async {
    try {
      await localDataSource.deleteSubscription(id);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure('Error deleting subscription: $e'));
    }
  }
}
