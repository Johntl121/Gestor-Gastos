import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../core/services/database_helper.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/goal_operations_repository.dart';
import '../helpers/account_transaction_helper.dart';
import '../models/transaction_model.dart';

class GoalOperationsRepositoryImpl implements GoalOperationsRepository {
  final LocalDatabase localDatabase;

  GoalOperationsRepositoryImpl({required this.localDatabase});

  @override
  Future<Either<Failure, void>> depositToGoalAtomic(
      String goalId, TransactionEntity transaction) async {
    try {
      final db = await localDatabase.database;

      // Precondiciones
      if (transaction.accountId <= 0 ||
          transaction.destinationAccountId == null) {
        throw Exception("Cuenta origen o destino inválida para el depósito");
      }
      if (transaction.amount <= 0) {
        throw Exception("El monto a depositar debe ser mayor a 0");
      }

      await db.transaction((txn) async {
        // 1. Verificar que la meta exista
        final goals =
            await txn.query('goals', where: 'id = ?', whereArgs: [goalId]);
        if (goals.isEmpty) throw Exception("La meta no existe");

        // 2. Insertar transacción
        final txModel = TransactionModel.fromEntity(transaction);
        await txn.insert('transactions', txModel.toJson());

        // 3. Aplicar efecto a las cuentas
        await AccountTransactionHelper.applyTransaction(txn, transaction);

        // 4. Actualizar la meta
        final updated = await txn.rawUpdate(
            'UPDATE goals SET currentAmount = currentAmount + ? WHERE id = ?',
            [transaction.amount, goalId]);
        if (updated == 0) {
          throw Exception("Error al actualizar el progreso de la meta");
        }
      });

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> purchaseGoalAtomic(
      String goalId, TransactionEntity transaction) async {
    try {
      final db = await localDatabase.database;

      if (transaction.accountId <= 0) {
        throw Exception("Cuenta alcancía inválida");
      }

      await db.transaction((txn) async {
        // 1. Verificar meta
        final goals =
            await txn.query('goals', where: 'id = ?', whereArgs: [goalId]);
        if (goals.isEmpty) throw Exception("La meta no existe");

        // 2. Insertar transacción de gasto
        final txModel = TransactionModel.fromEntity(transaction);
        await txn.insert('transactions', txModel.toJson());

        // 3. Aplicar gasto a la alcancía
        await AccountTransactionHelper.applyTransaction(txn, transaction);

        // 4. Marcar meta como completada y resetear saldo ya que se gastó
        final updated = await txn.rawUpdate(
            'UPDATE goals SET isCompleted = 1, currentAmount = 0.0 WHERE id = ?',
            [goalId]);
        if (updated == 0) throw Exception("Error al completar la meta");
      });

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteGoalAtomic(String goalId,
      {TransactionEntity? refundTransaction}) async {
    try {
      final db = await localDatabase.database;

      await db.transaction((txn) async {
        // 1. Verificar meta
        final goals =
            await txn.query('goals', where: 'id = ?', whereArgs: [goalId]);
        if (goals.isEmpty) return; // Si no existe, nada que hacer

        // 2. Reembolso si aplica
        if (refundTransaction != null) {
          if (refundTransaction.accountId <= 0 ||
              refundTransaction.destinationAccountId == null) {
            throw Exception(
                "Cuenta origen o destino inválida para el reembolso");
          }
          final txModel = TransactionModel.fromEntity(refundTransaction);
          await txn.insert('transactions', txModel.toJson());
          await AccountTransactionHelper.applyTransaction(
              txn, refundTransaction);
        }

        // 3. Eliminar meta
        final deleted =
            await txn.delete('goals', where: 'id = ?', whereArgs: [goalId]);
        if (deleted == 0) throw Exception("No se pudo eliminar la meta");
      });

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
