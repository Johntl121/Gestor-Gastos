import 'package:sqflite/sqflite.dart';
import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/balance_breakdown.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../core/services/database_helper.dart';
import 'transaction_data_source.dart';
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
  Future<Either<Failure, BalanceBreakdown>> getBalanceBreakdown() async {
    try {
      final db = await localDatabase.database;
      final List<Map<String, dynamic>> accountsMap = await db.query('accounts');

      final accounts = accountsMap.map((e) {
        final model = AccountModel.fromJson(e);
        return model.copyWith(currentBalance: (e['balance'] as num).toDouble());
      }).toList();

      double total = 0, cash = 0, digital = 0;

      for (var account in accounts) {
        if (!account.includeInTotal) continue;
        total += account.currentBalance;
        if (account.isCash) {
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
  Future<Either<Failure, double>> getMonthlyBudget() async {
    try {
      final budget = transactionLocalDataSource.getBudgetLimit();
      return Right(budget);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactions() async {
    try {
      final transactionModels = await transactionLocalDataSource.getTransactions();
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
      
      // Obtener transacción antigua para calcular la diferencia de saldo
      final List<Map<String, dynamic>> oldList = await db.query(
        'transactions', 
        where: 'id = ?', 
        whereArgs: [transaction.id]
      );

      if (oldList.isNotEmpty) {
        final oldAmount = oldList.first['amount'] as double;
        final diff = transaction.amount - oldAmount;

        await db.transaction((txn) async {
          // Actualizar transacción
          await txn.update(
            'transactions',
            TransactionModel.fromEntity(transaction).toJson(),
            where: 'id = ?',
            whereArgs: [transaction.id],
          );

          // Si el monto cambió, actualizar saldo de cuenta
          if (diff != 0) {
            await txn.rawUpdate('''
              UPDATE accounts 
              SET balance = balance + ? 
              WHERE id = ?
            ''', [diff, transaction.accountId]);
          }
        });
      }
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
  Future<Either<Failure, List<AccountEntity>>> getAccounts() async {
    try {
      final db = await localDatabase.database;
      final List<Map<String, dynamic>> maps = await db.query('accounts');

      final accounts = maps.map((e) {
        final model = AccountModel.fromJson(e);
        return model.copyWith(currentBalance: model.initialBalance);
      }).toList();

      return Right(accounts);
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

  @override
  Future<Either<Failure, int>> createAccount(AccountEntity account) async {
    try {
      final db = await localDatabase.database;
      final map = <String, dynamic>{
        'name': account.name,
        'type': account.isCash ? 'CASH' : 'DIGITAL',
        'balance': account.initialBalance,
        'color': account.colorValue,
        'currencySymbol': account.currencySymbol,
        'iconCode': account.iconCode,
        'includeInTotal': account.includeInTotal ? 1 : 0
      };
      if (account.id > 0) {
        map['id'] = account.id;
      }
      final id = await db.insert('accounts', map, conflictAlgorithm: ConflictAlgorithm.replace);
      return Right(id);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount(int id) async {
    try {
      final db = await localDatabase.database;
      await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateAccount(AccountEntity account) async {
    try {
      final db = await localDatabase.database;
      await db.update(
          'accounts',
          {
            'name': account.name,
            'type': account.isCash ? 'CASH' : 'DIGITAL',
            'balance': account.currentBalance,
            'color': account.colorValue,
            'currencySymbol': account.currencySymbol,
            'iconCode': account.iconCode,
            'includeInTotal': account.includeInTotal ? 1 : 0
          },
          where: 'id = ?',
          whereArgs: [account.id]);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
