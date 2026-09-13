import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../core/services/database_helper.dart';
import '../datasources/transaction_local_data_source.dart';
import '../models/transaction_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final LocalDatabase localDatabase;
  final TransactionLocalDataSource transactionLocalDataSource;

  TransactionRepositoryImpl({
    required this.localDatabase,
    required this.transactionLocalDataSource,
  });

  @override
  Future<Either<Failure, void>> addTransaction(TransactionEntity transaction,
      {bool updateBalance = true}) async {
    try {
      final db = await localDatabase.database;

      await db.transaction((txn) async {
        // 1. Guardar la transacción en SQLite
        final transactionModel = TransactionModel.fromEntity(transaction);
        await txn.insert('transactions', transactionModel.toJson());

        // 2. Actualizar Saldo de Cuenta en SQL
        if (updateBalance) {
          if (transaction.type == TransactionType.transfer &&
              transaction.destinationAccountId != null) {
            
            // Lógica de Transferencia: Restar de Origen, Sumar a Destino
            await txn.rawUpdate('''
              UPDATE accounts 
              SET balance = balance - ? 
              WHERE id = ?
            ''', [transaction.amount.abs(), transaction.accountId]);

            await txn.rawUpdate('''
              UPDATE accounts 
              SET balance = balance + ? 
              WHERE id = ?
            ''', [
              transaction.receivedAmount ?? transaction.amount.abs(),
              transaction.destinationAccountId
            ]);
          } else {
            // Lógica estándar de Gasto/Ingreso
            await txn.rawUpdate('''
              UPDATE accounts 
              SET balance = balance + ? 
              WHERE id = ?
            ''', [transaction.amount, transaction.accountId]);
          }
        }
      });

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }



  @override
  Future<Either<Failure, double>> getCurrentMonthExpenses() async {
    try {
      final db = await localDatabase.database;
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
      
      // Consultar directamente a la base de datos es mucho más eficiente
      final result = await db.rawQuery('''
        SELECT SUM(amount) as total 
        FROM transactions 
        WHERE amount < 0 
        AND date >= ?
      ''', [firstDayOfMonth]);

      final total = result.first['total'] as double? ?? 0.0;
      return Right(total);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }



  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactions({int limit = 50, int offset = 0}) async {
    try {
      final transactionModels = await transactionLocalDataSource.getTransactions(limit: limit, offset: offset);
      return Right(transactionModels);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateTransaction(
      TransactionEntity transaction) async {
    try {
      final db = await localDatabase.database;
      
      await db.transaction((txn) async {
        // 1. Leer original
        final List<Map<String, dynamic>> oldList = await txn.query(
          'transactions', 
          where: 'id = ?', 
          whereArgs: [transaction.id]
        );

        if (oldList.isEmpty) {
          throw Exception('Transacción original no encontrada para editar');
        }

        final oldTx = TransactionModel.fromJson(oldList.first);

        // 2. Revertir efecto anterior
        if (oldTx.type == TransactionType.transfer && oldTx.destinationAccountId != null) {
          await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE id = ?', 
            [oldTx.amount.abs(), oldTx.accountId]);
          final destAmount = oldTx.receivedAmount ?? oldTx.amount.abs();
          await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE id = ?', 
            [destAmount, oldTx.destinationAccountId]);
        } else {
          await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE id = ?', 
            [oldTx.amount, oldTx.accountId]);
        }

        // 3. UPDATE del mismo registro
        await txn.update(
          'transactions',
          TransactionModel.fromEntity(transaction).toJson(),
          where: 'id = ?',
          whereArgs: [transaction.id],
        );

        // 4. Aplicar efecto nuevo
        if (transaction.type == TransactionType.transfer && transaction.destinationAccountId != null) {
          await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE id = ?', 
            [transaction.amount.abs(), transaction.accountId]);
          await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE id = ?', 
            [transaction.receivedAmount ?? transaction.amount.abs(), transaction.destinationAccountId]);
        } else {
          await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE id = ?', 
            [transaction.amount, transaction.accountId]);
        }
      });
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTransaction(int id) async {
    try {
      final db = await localDatabase.database;
      
      final List<Map<String, dynamic>> list = await db.query(
        'transactions', 
        where: 'id = ?', 
        whereArgs: [id]
      );

      if (list.isNotEmpty) {
        final transactionToDelete = TransactionModel.fromJson(list.first);

        await db.transaction((txn) async {
          // Eliminar de SQLite
          await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);

          // Revertir saldo
          if (transactionToDelete.type == TransactionType.transfer &&
              transactionToDelete.destinationAccountId != null) {
            
            // Revertir Transferencia
            await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE id = ?', 
              [transactionToDelete.amount.abs(), transactionToDelete.accountId]);

            final destAmount = transactionToDelete.receivedAmount ?? transactionToDelete.amount.abs();
            await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE id = ?', 
              [destAmount, transactionToDelete.destinationAccountId]);
          } else {
            // Revertir Gasto/Ingreso estándar
            await txn.rawUpdate('''
                  UPDATE accounts 
                  SET balance = balance - ? 
                  WHERE id = ?
              ''', [transactionToDelete.amount, transactionToDelete.accountId]);
          }
        });
      }
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }



  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    try {
      final transactions = await transactionLocalDataSource.getTransactionsByDateRange(start, end);
      return Right(transactions);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }


}
