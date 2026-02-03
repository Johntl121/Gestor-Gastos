import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/balance_breakdown.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/local_database.dart';
import '../datasources/transaction_local_data_source.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final LocalDatabase localDatabase;
  final TransactionLocalDataSource transactionLocalDataSource;

  TransactionRepositoryImpl({
    required this.localDatabase,
    required this.transactionLocalDataSource,
  });

  @override
  Future<Either<Failure, void>> addTransaction(
      TransactionEntity transaction) async {
    try {
      // 1. Persistir en Shared Preferences (Lista de Transacciones)
      final transactions = await transactionLocalDataSource.getTransactions();
      final transactionModel = TransactionModel.fromEntity(transaction);
      transactions.add(transactionModel);
      await transactionLocalDataSource.cacheTransactions(transactions);

      // 2. Actualizar Saldo de Cuenta en SQL (LocalDatabase)
      final db = await localDatabase.database;

      // Obtener categoría para verificar tipo
      // Nota: Si migramos todo a SP, esto también debería cambiar.
      // Por ahora asumimos que Categories y Accounts siguen en SQLite.
      final List<Map<String, dynamic>> categoryResult = await db.query(
        'categories',
        columns: ['type'],
        where: 'id = ?',
        whereArgs: [transaction.categoryId],
      );

      if (categoryResult.isNotEmpty) {
        final type = categoryResult.first['type'] as String;
        double amountToApply = transaction.amount;

        // Si es Gasto, restamos
        if (type == 'EXPENSE') {
          amountToApply = -transaction.amount.abs();
        } else {
          // Ingreso suma
          amountToApply = transaction.amount.abs();
        }

        // Actualizar Cuenta
        await db.rawUpdate('''
            UPDATE accounts 
            SET balance = balance + ? 
            WHERE id = ?
          ''', [amountToApply, transaction.accountId]);
      }

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, BalanceBreakdown>> getBalanceBreakdown() async {
    try {
      final db = await localDatabase.database;

      // Obtener todas las cuentas
      final List<Map<String, dynamic>> accountsMap = await db.query('accounts');
      final accounts =
          accountsMap.map((e) => AccountModel.fromJson(e)).toList();

      double total = 0;
      double cash = 0;
      double digital = 0;

      for (var account in accounts) {
        total += account.currentBalance;
        if (account.type == AccountEnumType.cash) {
          cash += account.currentBalance;
        } else {
          digital += account.currentBalance;
        }
      }

      return Right(BalanceBreakdown(
        total: total,
        cash: cash,
        digital: digital,
      ));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getCurrentMonthExpenses() async {
    try {
      // Obtener transacciones desde SP
      final transactions = await transactionLocalDataSource.getTransactions();

      final now = DateTime.now();

      // Filtrar por mes actual y sumar
      double totalExpenses = 0.0;

      // Nota: Para filtrar correctamente por tipo 'EXPENSE', necesitaríamos
      // saber el tipo de la categoría de cada transacción.
      // Como TransactionModel suele tener categoryId, tendríamos que consultar las categorías.
      // SIN EMBARGO, para simplificar y cumplir con "cargar datos guardados",
      // asumiremos que podemos cruzar datos o que el usuario acepta esta limitación por ahora.
      // O leemos categorías de DB.

      final db = await localDatabase.database;
      final categoriesMap = await db.query('categories');
      // Crear mapa de categoryId -> type
      final Map<int, String> categoryTypes = {
        for (var c in categoriesMap) c['id'] as int: c['type'] as String
      };

      for (var t in transactions) {
        if (t.date.year == now.year && t.date.month == now.month) {
          final type = categoryTypes[t.categoryId];
          if (type == 'EXPENSE') {
            totalExpenses += t.amount;
          }
        }
      }

      return Right(totalExpenses);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getMonthlyBudget() async {
    // Implementar lógica para obtener presupuesto definido.
    // Para MVP, retornando valor fijo o obteniendo de tabla de configuración.
    // Asumamos presupuesto por defecto o crearemos tabla de configuración luego.
    return const Right(2000.00); // Presupuesto Mock: 2000 Soles
  }
}
