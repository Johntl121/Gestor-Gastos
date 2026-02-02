import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/balance_breakdown.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/local_database.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final LocalDatabase localDatabase;

  TransactionRepositoryImpl(this.localDatabase);

  @override
  Future<Either<Failure, void>> addTransaction(
      TransactionEntity transaction) async {
    try {
      final db = await localDatabase.database;
      final transactionModel = TransactionModel.fromEntity(transaction);

      await db.transaction((txn) async {
        // 1. Insertar Transacción
        await txn.insert(
          'transactions',
          transactionModel.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 2. Actualizar Saldo de Cuenta
        // Verificar categoría para determinar tipo.
        // Si es gasto, restamos (hacemos negativo si es positivo)

        // Obtener categoría para verificar tipo
        final List<Map<String, dynamic>> categoryResult = await txn.query(
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
          await txn.rawUpdate('''
             UPDATE accounts 
             SET balance = balance + ? 
             WHERE id = ?
           ''', [amountToApply, transaction.accountId]);
        }
      });

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
      final db = await localDatabase.database;
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
      final endOfMonth = DateTime(now.year, now.month + 1, 0).toIso8601String();

      // Consultar suma de transacciones donde el tipo de categoría es GASTO
      final result = await db.rawQuery('''
        SELECT SUM(t.amount) as total
        FROM transactions t
        JOIN categories c ON t.categoryId = c.id
        WHERE c.type = 'EXPENSE' 
        AND t.date BETWEEN ? AND ?
      ''', [startOfMonth, endOfMonth]);

      double totalExpenses = 0.0;
      if (result.first['total'] != null) {
        totalExpenses = (result.first['total'] as num).toDouble();
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
