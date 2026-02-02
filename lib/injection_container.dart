import 'package:get_it/get_it.dart';
import 'package:sqflite/sqflite.dart';

// Fuentes de Datos
import 'data/datasources/local_database.dart';

// Repositorios
import 'domain/repositories/transaction_repository.dart';
import 'data/repositories/transaction_repository_impl.dart';

// Casos de Uso
import 'domain/usecases/add_transaction_usecase.dart';
import 'domain/usecases/get_account_balance_usecase.dart';
import 'domain/usecases/get_budget_mood_usecase.dart';
import 'presentation/providers/dashboard_provider.dart';

final sl = GetIt.instance;

Future<void> init() async {
  //! Externo
  // Singleton de Base de Datos Local (Ya implementado como singleton, pero bueno tener acceso vía sl)
  sl.registerLazySingleton<LocalDatabase>(() => LocalDatabase());

  //! Fuentes de Datos
  // Accedemos a la db vía la clase LocalDatabase directamente en el repositorio por ahora basado en la implementación
  // pero si tuviéramos una interfaz DataSource separada, la registraríamos aquí.

  //! Repositorio
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(sl()),
  );

  //! Casos de Uso
  sl.registerLazySingleton(() => AddTransactionUseCase(sl()));
  sl.registerLazySingleton(() => GetAccountBalanceUseCase(sl()));
  sl.registerLazySingleton(() => GetBudgetMoodUseCase(sl()));

  //! Proveedores
  sl.registerFactory(
    () => DashboardProvider(
      getAccountBalance: sl(),
      getBudgetMood: sl(),
      addTransactionUseCase: sl(),
    ),
  );
}
