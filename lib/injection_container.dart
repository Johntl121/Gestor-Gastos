import 'package:get_it/get_it.dart';
import 'package:sqflite/sqflite.dart';

// Data Sources
import 'data/datasources/local_database.dart';

// Repositories
import 'domain/repositories/transaction_repository.dart';
import 'data/repositories/transaction_repository_impl.dart';

// Use Cases
import 'domain/usecases/add_transaction_usecase.dart';
import 'domain/usecases/get_account_balance_usecase.dart';
import 'domain/usecases/get_budget_mood_usecase.dart';
import 'presentation/providers/dashboard_provider.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! External
  // Local Database Singleton (Already implemented as singleton, but good to have access via sl)
  sl.registerLazySingleton<LocalDatabase>(() => LocalDatabase());

  //! Data sources
  // We access the db via LocalDatabase class directly in repository for now based on implementation
  // but if we had a separate DataSource interface, we would register it here.

  //! Repository
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(sl()),
  );

  //! Use cases
  sl.registerLazySingleton(() => AddTransactionUseCase(sl()));
  sl.registerLazySingleton(() => GetAccountBalanceUseCase(sl()));
  sl.registerLazySingleton(() => GetBudgetMoodUseCase(sl()));

  //! Providers
  sl.registerFactory(
    () => DashboardProvider(
      getAccountBalance: sl(),
      getBudgetMood: sl(),
      addTransactionUseCase: sl(),
    ),
  );
}
