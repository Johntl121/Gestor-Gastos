import 'package:flutter/material.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/balance_breakdown.dart';
import '../../domain/entities/budget_mood.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import '../../domain/usecases/get_account_balance_usecase.dart';
import '../../domain/usecases/get_budget_mood_usecase.dart';

class DashboardProvider extends ChangeNotifier {
  final GetAccountBalanceUseCase getAccountBalance;
  final GetBudgetMoodUseCase getBudgetMood;
  final AddTransactionUseCase addTransactionUseCase;

  DashboardProvider({
    required this.getAccountBalance,
    required this.getBudgetMood,
    required this.addTransactionUseCase,
  });

  BalanceBreakdown? _balanceBreakdown;
  BudgetMood _budgetMood = BudgetMood.neutral; // Estado por defecto
  bool _isLoading = false;
  Failure? _failure;

  BalanceBreakdown? get balanceBreakdown => _balanceBreakdown;
  BudgetMood get budgetMood => _budgetMood;
  bool get isLoading => _isLoading;
  Failure? get failure => _failure;

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

    // Obtener Estado de Ánimo (Solo si la carga de saldo no falló críticamente, aunque independiente es mejor)
    final moodResult = await getBudgetMood(NoParams());
    moodResult.fold(
      (fail) {// ¿Mantener estado previo o manejar separado? Por ahora, registrar fallo estrictamente
         if (_failure == null) _failure = fail;
      },
      (mood) => _budgetMood = mood,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTransaction(TransactionEntity transaction) async {
    _isLoading = true;
    notifyListeners();

    final result = await addTransactionUseCase(AddTransactionParams(transaction: transaction));

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
