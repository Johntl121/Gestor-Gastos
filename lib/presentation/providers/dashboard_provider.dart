import 'package:flutter/material.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/balance_breakdown.dart';
import '../../domain/entities/budget_mood.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import '../../domain/usecases/get_account_balance_usecase.dart';
import '../../domain/usecases/get_budget_mood_usecase.dart';

import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/get_monthly_budget_usecase.dart';

/// DashboardProvider: Gestiona el estado principal de la aplicación.
/// Coordina la obtención de saldos, transacciones y el cálculo del estado de ánimo financiero.
class DashboardProvider extends ChangeNotifier {
  final GetAccountBalanceUseCase getAccountBalance;
  final GetBudgetMoodUseCase getBudgetMood;
  final AddTransactionUseCase addTransactionUseCase;
  final GetTransactionsUseCase getTransactionsUseCase;
  final GetMonthlyBudgetUseCase getMonthlyBudgetUseCase;

  DashboardProvider({
    required this.getAccountBalance,
    required this.getBudgetMood,
    required this.addTransactionUseCase,
    required this.getTransactionsUseCase,
    required this.getMonthlyBudgetUseCase,
  }) {
    loadData();
  }

  BalanceBreakdown? _balanceBreakdown;
  BudgetMood _budgetMood = BudgetMood.neutral; // Estado por defecto
  bool _isLoading = false;
  Failure? _failure;
  List<TransactionEntity> _transactions = [];

  double _budgetLimit = 2400.00;

  BalanceBreakdown? get balanceBreakdown => _balanceBreakdown;
  BudgetMood get budgetMood => _budgetMood;
  bool get isLoading => _isLoading;
  Failure? get failure => _failure;
  double get budgetLimit => _budgetLimit;
  List<TransactionEntity> get transactions => _transactions;

  /// Carga todos los datos necesarios para el Dashboard:
  /// 1. Balance total
  /// 2. Estado de ánimo (Mood)
  /// 3. Lista de transacciones recientes
  Future<void> loadData() async {
    _isLoading = true;
    _failure = null;
    notifyListeners();

    // Obtener Saldo
    final balanceResult = await getAccountBalance(NoParams());
    balanceResult.fold(
      (fail) => _failure = fail,
      (balance) => _balanceBreakdown = balance,
    );

    // Obtener Estado de Ánimo
    final moodResult = await getBudgetMood(NoParams());
    moodResult.fold(
      (fail) => _failure ??= fail,
      (mood) => _budgetMood = mood,
    );

    // Obtener Límite de Presupuesto
    final budgetResult = await getMonthlyBudgetUseCase(NoParams());
    budgetResult.fold(
      (fail) => _failure ??= fail,
      (budget) => _budgetLimit = budget,
    );

    // Obtener Transacciones
    final transactionsResult = await getTransactionsUseCase(NoParams());
    transactionsResult.fold((fail) => _failure ??= fail, (transactions) {
      _transactions = transactions;
      _transactions.sort((a, b) => b.date
          .compareTo(a.date)); // Ordenar descendente (más recientes primero)
    });

    _isLoading = false;
    notifyListeners();
  }

  /// Actualiza el límite de presupuesto mensual.
  /// Afecta cómo se calcula el progreso del presupuesto en el Home.
  void setBudgetLimit(double newLimit) {
    _budgetLimit = newLimit;
    notifyListeners();
    // TODO: En una app real, deberíamos persistir este valor aquí (SharedPrefs)
  }

  /// Obtiene el gasto total por categoría para el mes actual.
  /// Retorna un mapa: {'Comida': 150.0, 'Transporte': 50.0}
  Map<String, double> get spendingByCategory {
    final now = DateTime.now();
    final expenses = _transactions.where((t) =>
        t.amount < 0 && t.date.month == now.month && t.date.year == now.year);

    final Map<String, double> result = {};
    for (var t in expenses) {
      final category =
          t.description; // La descripción guarda el nombre de la categoría
      if (result.containsKey(category)) {
        result[category] = result[category]! + t.amount.abs();
      } else {
        result[category] = t.amount.abs();
      }
    }
    return result;
  }

  /// Obtiene el total de gastos del mes actual.
  double get totalMonthlyExpenses {
    return spendingByCategory.values.fold(0.0, (sum, item) => sum + item);
  }

  Future<void> addTransaction(TransactionEntity transaction) async {
    _isLoading = true;
    notifyListeners();

    final result = await addTransactionUseCase(
        AddTransactionParams(transaction: transaction));

    result.fold(
      (fail) {
        _failure = fail;
        _isLoading = false;
        notifyListeners();
      },
      (_) {
        // Éxito -> Recargar Datos para actualizar UI
        loadData();
      },
    );
  }
}
