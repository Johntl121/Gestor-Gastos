import 'package:dartz/dartz.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/money_utils.dart';
import '../../entities/transaction_entity.dart';
import '../../entities/category_group.dart';
import '../../entities/account_entity.dart';
import '../../../data/datasources/preferences_local_data_source.dart';
import '../../repositories/subscription_repository.dart';
import '../../../data/datasources/goal_local_data_source.dart';

class BuildFinancialContextParams {
  final List<TransactionEntity> currentPeriodTransactions;
  final List<CategoryGroup> topCategories;
  final String currencySymbol;
  final List<AccountEntity> accounts;
  final double Function(double amount, String fromCurrency, String toCurrency) currencyConvert;

  BuildFinancialContextParams({
    required this.currentPeriodTransactions,
    required this.topCategories,
    required this.currencySymbol,
    required this.accounts,
    required this.currencyConvert,
  });
}

class BuildFinancialContextUseCase {
  final PreferencesLocalDataSource preferencesLocalDataSource;
  final SubscriptionRepository subscriptionRepository;
  final GoalLocalDataSource goalLocalDataSource;

  BuildFinancialContextUseCase({
    required this.preferencesLocalDataSource,
    required this.subscriptionRepository,
    required this.goalLocalDataSource,
  });

  Future<Either<Failure, String>> call(BuildFinancialContextParams params) async {
    try {
      final budgetLimit = preferencesLocalDataSource.getBudgetLimit();

      double totalIncome = 0;
      double totalExpense = 0;

      for (var t in params.currentPeriodTransactions) {
        if (t.type == TransactionType.transfer) continue;

        double convertedAmount = t.amount;
        if (params.accounts.isNotEmpty) {
          final account = params.accounts.firstWhere(
            (a) => a.id == t.accountId,
            orElse: () => params.accounts.first,
          );
          convertedAmount = params.currencyConvert(
              t.amount, account.currencySymbol, params.currencySymbol);
        }

        if (t.type == TransactionType.income) totalIncome += convertedAmount;
        if (t.type == TransactionType.expense) totalExpense += convertedAmount;
      }

      totalIncome = MoneyUtils.normalize(totalIncome, params.currencySymbol);
      totalExpense = MoneyUtils.normalize(totalExpense, params.currencySymbol);

      final buffer = StringBuffer();
      buffer.writeln("DATOS DEL USUARIO:");
      buffer.writeln("Moneda Principal: ${params.currencySymbol}");
      buffer.writeln();
      buffer.writeln("--- RESUMEN DEL PERIODO ---");
      buffer.writeln("Total Ingresos: ${MoneyUtils.format(totalIncome, params.currencySymbol)}");
      buffer.writeln("Total Gastos: ${MoneyUtils.format(totalExpense, params.currencySymbol)}");
      buffer.writeln("Presupuesto Mensual: ${MoneyUtils.format(budgetLimit, params.currencySymbol)}");
      buffer.writeln();

      buffer.writeln("--- GASTOS POR CATEGORÍA (Top 5) ---");
      final topCategories = params.topCategories.take(5).toList();
      for (int i = 0; i < topCategories.length; i++) {
        buffer.writeln(
            "${i + 1}. ${topCategories[i].name}: ${MoneyUtils.format(topCategories[i].amount, params.currencySymbol)}");
      }
      buffer.writeln();

      final subsResult = await subscriptionRepository.getSubscriptions();
      final subscriptions = subsResult.fold((l) => [], (r) => r);
      if (subscriptions.isNotEmpty) {
        buffer.writeln("--- GASTOS FIJOS ACTIVOS ---");
        for (var s in subscriptions) {
          buffer.writeln(
              "- ${s.name}: ${MoneyUtils.format(s.amount, params.currencySymbol)} | Vence el día: ${s.paymentDate.day}");
        }
        buffer.writeln();
      }

      final goals = await goalLocalDataSource.getGoals();
      if (goals.isNotEmpty) {
        buffer.writeln("--- METAS DE AHORRO ---");
        for (var g in goals) {
          double currentAmt = g.currentAmount;
          double targetAmt = g.targetAmount;

          if (g.accountId != null && params.accounts.isNotEmpty) {
            final accountIdx =
                params.accounts.indexWhere((a) => a.id == g.accountId);
            if (accountIdx != -1) {
              final account = params.accounts[accountIdx];
              currentAmt = params.currencyConvert(
                  currentAmt, account.currencySymbol, params.currencySymbol);
              targetAmt = params.currencyConvert(
                  targetAmt, account.currencySymbol, params.currencySymbol);
            }
          }

          buffer.writeln(
              "- ${g.name}: ${MoneyUtils.format(currentAmt, params.currencySymbol)} / ${MoneyUtils.format(targetAmt, params.currencySymbol)}");
        }
      }

      return Right(buffer.toString());
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
