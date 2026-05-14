import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fuentes de Datos
import 'core/services/database_helper.dart';
import 'data/repositories/transaction_data_source.dart';
import 'core/services/secure_storage_service.dart';

// Repositorios
import 'domain/repositories/transaction_repository.dart';
import 'data/repositories/transaction_repository_impl.dart';

// Casos de Uso
import 'domain/usecases/add_transaction_usecase.dart';
import 'domain/usecases/get_account_balance_usecase.dart';
import 'domain/usecases/get_budget_mood_usecase.dart';
import 'domain/usecases/get_transactions_usecase.dart';
import 'domain/usecases/get_monthly_budget_usecase.dart';
import 'domain/usecases/update_transaction_usecase.dart';
import 'domain/usecases/delete_transaction_usecase.dart';
import 'domain/usecases/account_usecases.dart';
import 'domain/usecases/delete_account_usecase.dart';
import 'domain/usecases/update_account_usecase.dart';
import 'domain/usecases/get_transactions_by_date_range_usecase.dart';

// Providers (New)
import 'presentation/providers/ui_provider.dart';
import 'presentation/providers/transaction_provider.dart';
import 'presentation/providers/wallet_provider.dart';
import 'presentation/providers/stats_provider.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! Externo
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // Singleton de Base de Datos Local
  sl.registerLazySingleton<LocalDatabase>(() => LocalDatabase());

  // Storage Seguro para datos sensibles (PIN)
  sl.registerLazySingleton<SecureStorageService>(() => SecureStorageService());

  //! Fuentes de Datos
  sl.registerLazySingleton<TransactionLocalDataSource>(
    () => TransactionLocalDataSourceImpl(
      sharedPreferences: sl(),
      localDatabase: sl(),
      secureStorage: sl(), // Nueva inyección
    ),
  );

  //! Repositorio
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(
      localDatabase: sl(),
      transactionLocalDataSource: sl(),
    ),
  );

  //! Casos de Uso
  sl.registerLazySingleton(() => AddTransactionUseCase(sl()));
  sl.registerLazySingleton(() => GetAccountBalanceUseCase(sl()));
  sl.registerLazySingleton(() => GetBudgetMoodUseCase(sl()));
  sl.registerLazySingleton(() => GetTransactionsUseCase(sl()));
  sl.registerLazySingleton(() => GetMonthlyBudgetUseCase(sl()));
  sl.registerLazySingleton(() => UpdateTransactionUseCase(sl()));
  sl.registerLazySingleton(() => DeleteTransactionUseCase(sl()));
  sl.registerLazySingleton(() => GetAccountsUseCase(sl()));
  sl.registerLazySingleton(() => CreateAccountUseCase(sl()));
  sl.registerLazySingleton(() => UpdateAccountUseCase(sl()));
  sl.registerLazySingleton(() => DeleteAccountUseCase(sl()));
  sl.registerLazySingleton(() => GetTransactionsByDateRangeUseCase(sl()));

  //! Proveedores (Refactored)

  // 1. UI Provider
  sl.registerLazySingleton(() => UiProvider(localDataSource: sl()));

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
      localDataSource: sl(),
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
      localDataSource: sl(),
    ),
  );

  // 4. Stats Provider
  sl.registerLazySingleton(
    () => StatsProvider(
      getBudgetMood: sl(),
      getTransactionsByDateRange: sl(),
      localDataSource: sl(),
    ),
  );
}
