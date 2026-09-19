import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fuentes de Datos
import 'core/services/database_helper.dart';
import 'data/datasources/preferences_local_data_source.dart';
import 'data/datasources/goal_local_data_source.dart';
import 'data/datasources/subscription_local_data_source.dart';
import 'data/datasources/transaction_local_data_source.dart';
import 'data/datasources/local/reminder_local_data_source.dart';
import 'core/services/secure_storage_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/notification_coordinator.dart';

// Repositorios
import 'domain/repositories/transaction_repository.dart';
import 'domain/repositories/account_repository.dart';
import 'domain/repositories/goal_operations_repository.dart';
import 'domain/repositories/reminder_repository.dart';
import 'domain/repositories/subscription_repository.dart';
import 'data/repositories/account_repository_impl.dart';
import 'data/repositories/transaction_repository_impl.dart';
import 'data/repositories/goal_operations_repository_impl.dart';
import 'data/repositories/reminder_repository_impl.dart';
import 'data/repositories/subscription_repository_impl.dart';

// Casos de Uso
import 'domain/usecases/account_usecases.dart';
import 'domain/usecases/add_transaction_usecase.dart';
import 'domain/usecases/delete_transaction_usecase.dart';
import 'domain/usecases/get_account_balance_usecase.dart';
import 'domain/usecases/get_budget_mood_usecase.dart';
import 'domain/usecases/get_monthly_budget_usecase.dart';
import 'domain/usecases/get_transactions_by_date_range_usecase.dart';
import 'domain/usecases/get_transactions_usecase.dart';
import 'domain/usecases/update_transaction_usecase.dart';
import 'domain/usecases/goal_operations_usecases.dart';
import 'domain/usecases/delete_account_usecase.dart';
import 'domain/usecases/update_account_usecase.dart';

// Providers (New)
import 'presentation/providers/ui_provider.dart';
import 'presentation/providers/transaction_provider.dart';
import 'presentation/providers/wallet_provider.dart';
import 'presentation/providers/reminder_provider.dart';
import 'presentation/providers/goal_provider.dart';
import 'presentation/providers/stats_provider.dart';
import 'presentation/providers/subscription_provider.dart';


final sl = GetIt.instance;

Future<void> init() async {
  //! Externo
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // Singleton de Base de Datos Local
  sl.registerLazySingleton<LocalDatabase>(() => LocalDatabase());

  // Storage Seguro para datos sensibles (PIN)
  sl.registerLazySingleton<SecureStorageService>(() => SecureStorageService());

  sl.registerLazySingleton<PreferencesLocalDataSource>(
    () => PreferencesLocalDataSourceImpl(
      sharedPreferences: sl(),
      secureStorage: sl(),
    ),
  );

  sl.registerLazySingleton<GoalLocalDataSource>(
    () => GoalLocalDataSourceImpl(localDatabase: sl()),
  );

  sl.registerLazySingleton<SubscriptionLocalDataSource>(
    () => SubscriptionLocalDataSourceImpl(localDatabase: sl()),
  );

  sl.registerLazySingleton<TransactionLocalDataSource>(
    () => TransactionLocalDataSourceImpl(localDatabase: sl()),
  );

  sl.registerLazySingleton<ReminderLocalDataSource>(
    () => ReminderLocalDataSourceImpl(localDatabase: sl()),
  );

  //! Notificaciones
  sl.registerLazySingleton<NotificationService>(() => NotificationService());
  sl.registerLazySingleton<NotificationCoordinator>(
    () => NotificationCoordinator(
      notificationService: sl(),
      preferences: sl(),
      subscriptionRepository: sl(),
      reminderRepository: sl(),
    ),
  );

  //! Repositorio
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(
      localDatabase: sl(),
      transactionLocalDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<AccountRepository>(
    () => AccountRepositoryImpl(
      localDatabase: sl(),
      preferencesLocalDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<GoalOperationsRepository>(
    () => GoalOperationsRepositoryImpl(
      localDatabase: sl(),
    ),
  );

  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(
      localDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<ReminderRepository>(
    () => ReminderRepositoryImpl(
      localDataSource: sl(),
    ),
  );

  //! Casos de Uso
  sl.registerLazySingleton(() => AddTransactionUseCase(sl()));
  sl.registerLazySingleton(() => GetAccountBalanceUseCase(sl()));
  sl.registerLazySingleton(() => GetBudgetMoodUseCase(sl(), sl()));
  sl.registerLazySingleton(() => GetTransactionsUseCase(sl()));
  sl.registerLazySingleton(() => GetMonthlyBudgetUseCase(sl()));
  sl.registerLazySingleton(() => UpdateTransactionUseCase(sl()));
  sl.registerLazySingleton(() => DeleteTransactionUseCase(sl()));
  sl.registerLazySingleton(() => GetAccountsUseCase(sl()));
  sl.registerLazySingleton(() => CreateAccountUseCase(sl()));
  sl.registerLazySingleton(() => UpdateAccountUseCase(sl()));
  sl.registerLazySingleton(() => DeleteAccountUseCase(sl()));
  sl.registerLazySingleton(() => GetTransactionsByDateRangeUseCase(sl()));
  sl.registerLazySingleton(() => DepositToGoalUseCase(
      repository: sl(),
      goalLocalDataSource: sl(),
      accountRepository: sl(),
      preferencesLocalDataSource: sl()));
  sl.registerLazySingleton(() => PurchaseGoalUseCase(
      repository: sl(),
      goalLocalDataSource: sl()));
  sl.registerLazySingleton(() => DeleteGoalAtomicUseCase(
      repository: sl(),
      goalLocalDataSource: sl(),
      accountRepository: sl(),
      preferencesLocalDataSource: sl()));

  //! Proveedores (Refactored)

  // 1. UI Provider
  sl.registerLazySingleton(
    () => UiProvider(
      preferencesLocalDataSource: sl(),
      notificationCoordinator: sl(),
    ),
  );
  // 2. Wallet Provider
  sl.registerLazySingleton(
    () => WalletProvider(
      getAccountBalance: sl(),
      getAccountsUseCase: sl(),
      createAccountUseCase: sl(),
      updateAccountUseCase: sl(),
      deleteAccountUseCase: sl(),
      getMonthlyBudgetUseCase: sl(),
      addTransactionUseCase: sl(),
      preferencesLocalDataSource: sl(),
    ),
  );

  // 2.5 Goal Provider
  sl.registerLazySingleton(
    () => GoalProvider(
      goalOperationsRepository: sl(),
      depositToGoalUseCase: sl(),
      purchaseGoalUseCase: sl(),
      deleteGoalAtomicUseCase: sl(),
    ),
  );

  // 3. Transaction Provider
  sl.registerLazySingleton(
    () => TransactionProvider(
      getTransactionsUseCase: sl(),
      addTransactionUseCase: sl(),
      updateTransactionUseCase: sl(),
      deleteTransactionUseCase: sl(),
      getTransactionsByDateRange: sl(),
      preferencesLocalDataSource: sl(),
      subscriptionLocalDataSource: sl(),
      notificationCoordinator: sl(),
    ),
  );

  // 3.5 Subscription Provider
  sl.registerLazySingleton(
    () => SubscriptionProvider(
      subscriptionRepository: sl(),
      notificationCoordinator: sl(),
    ),
  );

  // 4. Stats Provider
  sl.registerLazySingleton(
    () => StatsProvider(
      getBudgetMood: sl(),
      getTransactionsByDateRange: sl(),
      preferencesLocalDataSource: sl(),
      subscriptionRepository: sl(),
      goalLocalDataSource: sl(),
    ),
  );

  // 5. Reminder Provider
  sl.registerLazySingleton(
    () => ReminderProvider(
      repository: sl(),
      notificationCoordinator: sl(),
    ),
  );
}
