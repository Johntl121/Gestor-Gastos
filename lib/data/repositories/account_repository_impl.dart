import 'package:sqflite/sqflite.dart';
import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/balance_breakdown.dart';
import '../../domain/repositories/account_repository.dart';
import '../../core/services/database_helper.dart';
import '../datasources/preferences_local_data_source.dart';
import '../models/account_model.dart';

class AccountRepositoryImpl implements AccountRepository {
  final LocalDatabase localDatabase;
  final PreferencesLocalDataSource preferencesLocalDataSource;

  AccountRepositoryImpl({
    required this.localDatabase,
    required this.preferencesLocalDataSource,
  });

  @override
  Future<Either<Failure, List<AccountEntity>>> getAccounts() async {
    try {
      final db = await localDatabase.database;
      final List<Map<String, dynamic>> maps = await db.query('accounts');

      final accounts = maps.map((e) {
        final model = AccountModel.fromJson(e);
        return model.copyWith(currentBalance: (e['balance'] as num).toDouble());
      }).toList();

      return Right(accounts);
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
  Future<Either<Failure, double>> getMonthlyBudget() async {
    try {
      final budget = preferencesLocalDataSource.getBudgetLimit();
      return Right(budget);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
