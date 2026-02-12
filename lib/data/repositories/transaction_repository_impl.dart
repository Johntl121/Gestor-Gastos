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
  Future<Either<Failure, void>> addTransaction(TransactionEntity transaction,
      {bool updateBalance = true}) async {
    try {
      // 1. Persistir en Shared Preferences (Lista de Transacciones)
      final transactions = await transactionLocalDataSource.getTransactions();

      // Generate ID
      final newId = DateTime.now().millisecondsSinceEpoch;
      final transactionWithId = TransactionModel(
          id: newId,
          accountId: transaction.accountId,
          categoryId: transaction.categoryId,
          amount: transaction.amount,
          date: transaction.date,
          description: transaction.description,
          note: transaction.note,
          type: transaction.type,
          destinationAccountId: transaction.destinationAccountId,
          receivedAmount: transaction.receivedAmount,
          imagePath: transaction.imagePath);

      transactions.add(transactionWithId);
      await transactionLocalDataSource.cacheTransactions(transactions);

      // 2. Actualizar Saldo de Cuenta en SQL (LocalDatabase)
      if (updateBalance) {
        final db = await localDatabase.database;

        if (transaction.type == TransactionType.transfer &&
            transaction.destinationAccountId != null) {
          // Transfer Logic: Subtract from Source, Add to Destination
          // Assumption: 'transaction.amount' is Positive in Transfer UI Logic (User enters 500)
          // Source (accountId): -500
          // Dest (destinationAccountId): +500

          await db.rawUpdate('''
            UPDATE accounts 
            SET balance = balance - ? 
            WHERE id = ?
          ''', [transaction.amount.abs(), transaction.accountId]);

          await db.rawUpdate('''
            UPDATE accounts 
            SET balance = balance + ? 
            WHERE id = ?
          ''', [
            transaction.receivedAmount ?? transaction.amount.abs(),
            transaction.destinationAccountId
          ]);
        } else {
          // Standard Expense/Income Logic
          await db.rawUpdate('''
            UPDATE accounts 
            SET balance = balance + ? 
            WHERE id = ?
          ''', [transaction.amount, transaction.accountId]);
        }
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

      // Map to AccountModel handling legacy fields if needed
      final accounts = accountsMap.map((e) {
        // Handle migration/legacy data where new columns might be null
        return AccountModel(
          id: e['id'],
          name: e['name'],
          initialBalance:
              0.0, // SQL 'balance' is technically current balance in this architecture
          currencySymbol: e['currencySymbol'] ?? 'S/',
          colorValue: e['color'] ?? 0xFF4CAF50,
          iconCode: e['iconCode'] ?? 58343, // Icons.account_balance_wallet
        ).copyWith(currentBalance: (e['balance'] as num).toDouble());
      }).toList();

      double total = 0;
      double cash = 0;
      double digital = 0;
      double savings = 0;

      for (var account in accounts) {
        total += account.currentBalance;

        // Legacy categorization for BalanceBreakdown
        if (account.id == 1 || account.name.toLowerCase() == 'efectivo') {
          cash += account.currentBalance;
        } else if (account.id == 3 || account.name.toLowerCase() == 'ahorros') {
          savings += account.currentBalance;
        } else {
          // All other accounts (Bank, Crypto, Custom) are treated as Digital/Other
          digital += account.currentBalance;
        }
      }

      return Right(BalanceBreakdown(
        total: total,
        cash: cash,
        digital: digital,
        savings: savings,
      ));
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, double>> getCurrentMonthExpenses() async {
    try {
      // Obtener transacciones desde SharedPrefs
      final transactions = await transactionLocalDataSource.getTransactions();

      final now = DateTime.now();

      // Filtrar por mes actual y sumar
      double totalExpenses = 0.0;

      for (var t in transactions) {
        // Filtramos por fecha y por signo negativo (Gasto real)
        if (t.date.year == now.year && t.date.month == now.month) {
          if (t.amount < 0) {
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
      final transactionModels =
          await transactionLocalDataSource.getTransactions();

      // Auto-fixing corrupt data (null IDs) & Legacy Transfers
      bool needsFix = false;
      for (int i = 0; i < transactionModels.length; i++) {
        final t = transactionModels[i];
        bool changed = false;

        int? newId = t.id;
        TransactionType newType = t.type;

        // Fix ID
        if (newId == null) {
          newId = DateTime.now().millisecondsSinceEpoch + i;
          changed = true;
        }

        // Fix Type
        if (newType != TransactionType.transfer &&
            t.description.toLowerCase().contains('transferencia')) {
          newType = TransactionType.transfer;
          changed = true;
        }

        if (changed) {
          needsFix = true;
          transactionModels[i] = TransactionModel(
            id: newId,
            accountId: t.accountId,
            categoryId: t.categoryId,
            amount: t.amount,
            date: t.date,
            description: t.description,
            note: t.note,
            type: newType,
            destinationAccountId: t.destinationAccountId,
            receivedAmount: t.receivedAmount,
            imagePath: t.imagePath,
          );
        }
      }

      if (needsFix) {
        await transactionLocalDataSource.cacheTransactions(transactionModels);
      }

      // Los modelos (TransactionModel) extienden de la entidad (TransactionEntity),
      // por lo que podemos retornarlos directamente como una lista de entidades.
      return Right(transactionModels);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateTransaction(
      TransactionEntity transaction) async {
    try {
      final transactions = await transactionLocalDataSource.getTransactions();
      final index = transactions.indexWhere((t) => t.id == transaction.id);

      if (index != -1) {
        final oldTransaction = transactions[index];
        final double diff = transaction.amount - oldTransaction.amount;

        // Update list
        transactions[index] = TransactionModel.fromEntity(transaction);
        await transactionLocalDataSource.cacheTransactions(transactions);

        // Update Account Balance if amount changed
        if (diff != 0) {
          final db = await localDatabase.database;
          await db.rawUpdate('''
            UPDATE accounts 
            SET balance = balance + ? 
            WHERE id = ?
          ''', [diff, transaction.accountId]);
        }
      }
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTransaction(int id) async {
    try {
      final transactions = await transactionLocalDataSource.getTransactions();
      final index = transactions.indexWhere((t) => t.id == id);

      if (index != -1) {
        final transactionToDelete = transactions[index];

        // Remove from list
        transactions.removeAt(index);
        await transactionLocalDataSource.cacheTransactions(transactions);

        final db = await localDatabase.database;

        if (transactionToDelete.type == TransactionType.transfer &&
            transactionToDelete.destinationAccountId != null) {
          // Revert Transfer
          // Source: Add back
          await db.rawUpdate('''
            UPDATE accounts 
            SET balance = balance + ? 
            WHERE id = ?
          ''', [
            transactionToDelete.amount.abs(),
            transactionToDelete.accountId
          ]);

          // Dest: Subtract
          final destAmount = transactionToDelete.receivedAmount ??
              transactionToDelete.amount.abs();
          await db.rawUpdate('''
            UPDATE accounts 
            SET balance = balance - ? 
            WHERE id = ?
          ''', [destAmount, transactionToDelete.destinationAccountId]);
        } else {
          // Restore Account Balance (Subtract the transaction amount)
          // If it was -50 (expense), we subtract -50 => +50 (refund).
          // If it was +100 (income), we subtract +100 => -100 (remove income).
          await db.rawUpdate('''
                UPDATE accounts 
                SET balance = balance - ? 
                WHERE id = ?
            ''', [transactionToDelete.amount, transactionToDelete.accountId]);
        }
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
        return AccountModel(
          id: e['id'],
          name: e['name'],
          initialBalance: 0.0,
          currencySymbol: e['currencySymbol'] ?? 'S/',
          colorValue: e['color'] ?? 0xFF4CAF50,
          iconCode: e['iconCode'] ?? 58343,
          includeInTotal:
              e['includeInTotal'] == null ? true : (e['includeInTotal'] == 1),
        ).copyWith(currentBalance: (e['balance'] as num).toDouble());
      }).toList();

      return Right(accounts);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> createAccount(AccountEntity account) async {
    try {
      final db = await localDatabase.database;

      // SQL Insert expects Map
      await db.insert('accounts', {
        'name': account.name,
        'type': 'DIGITAL', // Maintain legacy check constraint
        'balance': account.initialBalance,
        'color': account.colorValue,
        'currencySymbol': account.currencySymbol,
        'iconCode': account.iconCode,
        'includeInTotal': account.includeInTotal ? 1 : 0
      });

      // Also creation initial transaction for record keeping if balance > 0?
      // Let's stick to just setting balance for now as requested.

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount(int id) async {
    try {
      final db = await localDatabase.database;
      // Cascade delete handles dependent transactions
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
