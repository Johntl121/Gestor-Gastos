import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gestor_gastos/presentation/providers/transaction_provider.dart';
import 'package:gestor_gastos/presentation/providers/subscription_provider.dart';
import 'package:gestor_gastos/domain/repositories/subscription_repository.dart';
import 'package:gestor_gastos/data/datasources/subscription_local_data_source.dart';
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';
import 'package:gestor_gastos/core/services/notification_coordinator.dart';
import 'package:gestor_gastos/domain/entities/transaction_entity.dart';
import 'package:gestor_gastos/data/models/subscription.dart';
import 'package:gestor_gastos/domain/usecases/get_transactions_usecase.dart';
import 'package:gestor_gastos/domain/usecases/add_transaction_usecase.dart';
import 'package:gestor_gastos/domain/usecases/update_transaction_usecase.dart';
import 'package:gestor_gastos/domain/usecases/delete_transaction_usecase.dart';
import 'package:gestor_gastos/domain/usecases/get_transactions_by_date_range_usecase.dart';
import 'package:gestor_gastos/domain/usecases/subscriptions/pay_subscription_usecase.dart';

class MockSubscriptionRepository extends Mock implements SubscriptionRepository {}
class MockSubscriptionLocalDataSource extends Mock implements SubscriptionLocalDataSource {}
class MockPreferencesLocalDataSource extends Mock implements PreferencesLocalDataSource {}
class MockNotificationCoordinator extends Mock implements NotificationCoordinator {}
class MockGetTransactionsUseCase extends Mock implements GetTransactionsUseCase {}
class MockAddTransactionUseCase extends Mock implements AddTransactionUseCase {}
class MockUpdateTransactionUseCase extends Mock implements UpdateTransactionUseCase {}
class MockDeleteTransactionUseCase extends Mock implements DeleteTransactionUseCase {}
class MockGetTransactionsByDateRange extends Mock implements GetTransactionsByDateRangeUseCase {}
class MockPaySubscriptionUseCase extends Mock implements PaySubscriptionUseCase {}

class FakeSubscription extends Fake implements Subscription {}

void main() {
  late MockSubscriptionRepository mockSubscriptionRepository;
  late MockSubscriptionLocalDataSource mockSubscriptionLocalDataSource;
  late MockPreferencesLocalDataSource mockPreferences;
  late MockNotificationCoordinator mockNotificationCoordinator;
  late MockGetTransactionsUseCase mockGetTransactions;
  late MockAddTransactionUseCase mockAddTransaction;
  late MockUpdateTransactionUseCase mockUpdateTransaction;
  late MockDeleteTransactionUseCase mockDeleteTransaction;
  late MockGetTransactionsByDateRange mockGetTransactionsByDateRange;
  late MockPaySubscriptionUseCase mockPaySubscriptionUseCase;

  late TransactionProvider transactionProvider;
  late SubscriptionProvider subscriptionProvider;

  setUp(() {
    mockSubscriptionRepository = MockSubscriptionRepository();
    mockSubscriptionLocalDataSource = MockSubscriptionLocalDataSource();
    mockPreferences = MockPreferencesLocalDataSource();
    mockNotificationCoordinator = MockNotificationCoordinator();
    mockGetTransactions = MockGetTransactionsUseCase();
    mockAddTransaction = MockAddTransactionUseCase();
    mockUpdateTransaction = MockUpdateTransactionUseCase();
    mockDeleteTransaction = MockDeleteTransactionUseCase();
    mockGetTransactionsByDateRange = MockGetTransactionsByDateRange();
    mockPaySubscriptionUseCase = MockPaySubscriptionUseCase();
    
    // By default, no transactions
    when(() => mockGetTransactions.call(any())).thenAnswer((_) async => Right(List.empty(growable: true)));
    
    // By default, empty subscriptions
    when(() => mockSubscriptionRepository.getSubscriptions()).thenAnswer((_) async => Right(List.empty(growable: true)));
    when(() => mockSubscriptionLocalDataSource.getSubscriptions()).thenAnswer((_) async => []);

    transactionProvider = TransactionProvider(
      getTransactionsUseCase: mockGetTransactions,
      addTransactionUseCase: mockAddTransaction,
      updateTransactionUseCase: mockUpdateTransaction,
      deleteTransactionUseCase: mockDeleteTransaction,
      getTransactionsByDateRange: mockGetTransactionsByDateRange,
      paySubscriptionUseCase: mockPaySubscriptionUseCase,
      preferencesLocalDataSource: mockPreferences,
      subscriptionLocalDataSource: mockSubscriptionLocalDataSource,
      notificationCoordinator: mockNotificationCoordinator,
    );
    
    subscriptionProvider = SubscriptionProvider(
      subscriptionRepository: mockSubscriptionRepository,
      notificationCoordinator: mockNotificationCoordinator,
    );
    
    // Wire up as it's done in main_page.dart
    transactionProvider.onSubscriptionsUpdated = () {
      subscriptionProvider.loadSubscriptions();
    };
  });

  setUpAll(() {
    registerFallbackValue(const GetTransactionsParams());
    registerFallbackValue(FakeSubscription());
  });

  test('_checkSubscriptionStatuses changes trigger SubscriptionProvider update', () async {
    // 1. Arrange
    final now = DateTime.now();
    final sub = Subscription(
      id: '1',
      name: 'Netflix',
      amount: 15.0,
      paymentDate: now,
      categoryId: 1,
      frequency: ExpenseFrequency.monthly,
      accountToCharge: 1,
      orderIndex: 0,
      isPaid: false, // Initially unpaid
    );
    
    // When _checkSubscriptionStatuses reads local DB
    when(() => mockSubscriptionLocalDataSource.getSubscriptions())
        .thenAnswer((_) async => [sub]);
    // Allow saving the updated sub
    when(() => mockSubscriptionLocalDataSource.saveSubscription(any()))
        .thenAnswer((_) async {});
    
    // Set a transaction that matches the subscription for current month
    final tx = TransactionEntity(
      accountId: 1,
      categoryId: 1,
      amount: 15.0,
      date: now,
      type: TransactionType.expense,
      description: 'Netflix',
    );
    
    when(() => mockGetTransactions.call(any())).thenAnswer((_) async => Right([tx]));

    // Track how many times loadSubscriptions is actually executed in repo
    int loadCalls = 0;
    when(() => mockSubscriptionRepository.getSubscriptions()).thenAnswer((_) async {
      loadCalls++;
      return Right([sub.copyWith(isPaid: true)]);
    });

    // 2. Act
    // This will fetch transactions, see 'Netflix' paid, update the DB directly via localDataSource,
    // and then (with the fix) trigger onSubscriptionsUpdated, invoking loadSubscriptions.
    await transactionProvider.loadTransactions();

    // 3. Assert
    // If the fix works, loadCalls should be > 0 (actually 1 if it wasn't called manually before)
    expect(loadCalls, greaterThanOrEqualTo(1), reason: "SubscriptionProvider should have been refreshed");
  });
}
