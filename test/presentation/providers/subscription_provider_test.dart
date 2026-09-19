import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:gestor_gastos/presentation/providers/subscription_provider.dart';
import 'package:gestor_gastos/domain/repositories/subscription_repository.dart';
import 'package:gestor_gastos/domain/repositories/transaction_repository.dart';
import 'package:gestor_gastos/core/services/notification_coordinator.dart';
import 'package:gestor_gastos/data/models/subscription.dart';
import 'package:gestor_gastos/core/errors/failure.dart';
import 'package:gestor_gastos/core/services/notification_service.dart';
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';
import 'package:gestor_gastos/domain/repositories/reminder_repository.dart';
import 'package:gestor_gastos/domain/usecases/subscriptions/refresh_subscription_cycles_usecase.dart';

class MockSubscriptionRepository implements SubscriptionRepository {
  List<Subscription> subs = [];
  bool shouldFail = false;
  
  int saveCount = 0;
  int deleteCount = 0;

  @override
  Future<Either<Failure, List<Subscription>>> getSubscriptions() async {
    if (shouldFail) return const Left(DatabaseFailure('Error loading'));
    return Right(subs);
  }

  @override
  Future<Either<Failure, void>> saveSubscription(Subscription subscription) async {
    saveCount++;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteSubscription(String id) async {
    deleteCount++;
    return const Right(null);
  }
}

class MockNotificationCoordinator extends NotificationCoordinator {
  int scheduleCount = 0;
  int cancelCount = 0;

  MockNotificationCoordinator()
      : super(
          notificationService: _DummyNotificationService(),
          preferences: _DummyPreferences(),
          subscriptionRepository: _DummySubRepo(),
          reminderRepository: _DummyReminderRepo(),
        );

  @override
  Future<NotificationStatus> scheduleSubscription(Subscription subscription) async {
    scheduleCount++;
    return NotificationStatus.scheduled;
  }

  @override
  Future<NotificationStatus> cancelSubscription(String id) async {
    cancelCount++;
    return NotificationStatus.scheduled;
  }
}

class MockRefreshSubscriptionCyclesUseCase implements RefreshSubscriptionCyclesUseCase {
  bool shouldFail = false;
  List<Subscription> subs = [];

  @override
  SubscriptionRepository get subscriptionRepository => throw UnimplementedError();

  @override
  TransactionRepository get transactionRepository => throw UnimplementedError();

  @override
  Future<Either<Failure, List<Subscription>>> call(RefreshSubscriptionCyclesParams params) async {
    if (shouldFail) return const Left(DatabaseFailure('DB Error'));
    return Right(subs);
  }
}

class _DummyNotificationService implements NotificationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyPreferences implements PreferencesLocalDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummySubRepo implements SubscriptionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DummyReminderRepo implements ReminderRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}


void main() {
  late MockSubscriptionRepository mockRepo;
  late MockNotificationCoordinator mockCoordinator;
  late MockRefreshSubscriptionCyclesUseCase mockRefreshSubscriptionCyclesUseCase;
  late SubscriptionProvider provider;

  final tSubscription = Subscription(
    id: 'sub1',
    name: 'Netflix',
    amount: 15.0,
    paymentDate: DateTime.now().add(const Duration(days: 5)),
    categoryId: 1,
    frequency: ExpenseFrequency.monthly,
    accountToCharge: 1,
    orderIndex: 0,
  );

  final tSubscription2 = Subscription(
    id: 'sub2',
    name: 'Spotify',
    amount: 10.0,
    paymentDate: DateTime.now().add(const Duration(days: 10)),
    categoryId: 1,
    frequency: ExpenseFrequency.monthly,
    accountToCharge: 1,
    orderIndex: 1,
  );

  setUp(() {
    mockRepo = MockSubscriptionRepository();
    mockCoordinator = MockNotificationCoordinator();
    mockRefreshSubscriptionCyclesUseCase = MockRefreshSubscriptionCyclesUseCase();
    
    provider = SubscriptionProvider(
      subscriptionRepository: mockRepo,
      notificationCoordinator: mockCoordinator,
      refreshSubscriptionCyclesUseCase: mockRefreshSubscriptionCyclesUseCase,
    );
  });

  test('loadSubscriptions - success', () async {
    mockRepo.subs = [tSubscription];
    mockRefreshSubscriptionCyclesUseCase.subs = [tSubscription];
    
    await provider.loadSubscriptions();

    expect(provider.subscriptions, [tSubscription]);
    expect(provider.isLoading, false);
    expect(provider.errorMessage, isNull);
  });

  test('loadSubscriptions - failure', () async {
    mockRefreshSubscriptionCyclesUseCase.shouldFail = true;
        
    await provider.loadSubscriptions();

    expect(provider.subscriptions, isEmpty);
    expect(provider.isLoading, false);
    expect(provider.errorMessage, 'DB Error');
  });

  test('addSubscription - new subscription', () async {
    await provider.addSubscription(tSubscription);

    expect(provider.subscriptions.length, 1);
    expect(provider.subscriptions.first.id, 'sub1');
    expect(mockRepo.saveCount, 1);
    expect(mockCoordinator.scheduleCount, 1);
  });

  test('addSubscription - update existing', () async {
    mockRepo.subs = [tSubscription];
    await provider.loadSubscriptions();

    final updatedSub = tSubscription.copyWith(amount: 20.0);
    await provider.addSubscription(updatedSub);

    expect(provider.subscriptions.length, 1);
    expect(provider.subscriptions.first.amount, 20.0);
    expect(mockRepo.saveCount, 1);
    expect(mockCoordinator.scheduleCount, 1);
  });

  test('removeSubscription', () async {
    mockRepo.subs = [tSubscription];
    await provider.loadSubscriptions();

    await provider.removeSubscription('sub1');

    expect(provider.subscriptions, isEmpty);
    expect(mockRepo.deleteCount, 1);
    expect(mockCoordinator.cancelCount, 1);
  });

  test('reorderSubscriptions', () async {
    mockRepo.subs = [tSubscription, tSubscription2];
    mockRefreshSubscriptionCyclesUseCase.subs = [tSubscription, tSubscription2];
    await provider.loadSubscriptions();

    provider.reorderSubscriptions(0, 2);

    expect(provider.subscriptions[0].id, 'sub2');
    expect(provider.subscriptions[1].id, 'sub1');
    expect(provider.subscriptions[0].orderIndex, 0);
    expect(provider.subscriptions[1].orderIndex, 1);
    
    // El repo se llama dos veces porque hay dos elementos a guardar
    expect(mockRepo.saveCount, 2);
  });
}
