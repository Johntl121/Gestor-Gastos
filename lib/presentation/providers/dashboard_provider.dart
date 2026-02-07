import 'package:flutter/material.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/balance_breakdown.dart';
import '../../domain/entities/budget_mood.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/goal_entity.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import '../../domain/usecases/get_account_balance_usecase.dart';
import '../../domain/usecases/get_budget_mood_usecase.dart';

import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/get_monthly_budget_usecase.dart';
import '../../domain/usecases/update_transaction_usecase.dart';
import '../../domain/usecases/delete_transaction_usecase.dart';
import '../../data/models/subscription.dart';
import '../../data/datasources/transaction_local_data_source.dart';
import '../../data/datasources/local_database.dart';
import '../../injection_container.dart';

enum PeriodType { week, month, year }

/// DashboardProvider: Gestiona el estado principal de la aplicación.
/// Coordina la obtención de saldos, transacciones y el cálculo del estado de ánimo financiero.
class DashboardProvider extends ChangeNotifier {
  final GetAccountBalanceUseCase getAccountBalance;
  final GetBudgetMoodUseCase getBudgetMood;
  final AddTransactionUseCase addTransactionUseCase;
  final GetTransactionsUseCase getTransactionsUseCase;
  final GetMonthlyBudgetUseCase getMonthlyBudgetUseCase;
  final UpdateTransactionUseCase updateTransactionUseCase;
  final DeleteTransactionUseCase deleteTransactionUseCase;

  DashboardProvider({
    required this.getAccountBalance,
    required this.getBudgetMood,
    required this.addTransactionUseCase,
    required this.getTransactionsUseCase,
    required this.getMonthlyBudgetUseCase,
    required this.updateTransactionUseCase,
    required this.deleteTransactionUseCase,
  }) {
    loadData();
  }

  BalanceBreakdown? _balanceBreakdown;
  BudgetMood _budgetMood = BudgetMood.neutral; // Estado por defecto
  bool _isLoading = false;
  Failure? _failure;
  List<TransactionEntity> _transactions = [];
  List<Subscription> _subscriptions = [];
  String _currencySymbol = 'S/';
  String _userName = 'Usuario';
  DateTime _currentStatsDate = DateTime.now();
  PeriodType _currentStatsPeriod = PeriodType.month;

  double _budgetLimit = 2400.00;
  bool _isDarkMode = true;
  bool _enableNotifications = true;
  bool _enableBiometrics = false;

  BalanceBreakdown? get balanceBreakdown => _balanceBreakdown;
  double get cashBalance => _balanceBreakdown?.cash ?? 0.0;
  double get bankBalance =>
      (_balanceBreakdown?.digital ?? 0.0) - savingsBalance;
  double get savingsBalance => _balanceBreakdown?.savings ?? 0.0;

  BudgetMood get budgetMood => _budgetMood;
  bool get isLoading => _isLoading;
  double get budgetLimit => _budgetLimit;
  List<TransactionEntity> get transactions => _transactions;
  List<Subscription> get subscriptions => _subscriptions;
  String get currencySymbol => _currencySymbol;
  String get userName => _userName;
  DateTime get currentStatsDate => _currentStatsDate;

  PeriodType get currentStatsPeriod => _currentStatsPeriod;
  bool get isDarkMode => _isDarkMode;
  bool get enableNotifications => _enableNotifications;
  bool get enableBiometrics => _enableBiometrics;

  // Security
  String? _userPin;
  bool get isPinEnabled => _userPin != null;

  /// Sets a new PIN.
  void setPin(String pin) {
    _userPin = pin;
    notifyListeners();
  }

  /// Removes the current PIN.
  void removePin() {
    _userPin = null;
    notifyListeners();
  }

  /// Verifies if the input matches the stored PIN.
  bool verifyPin(String input) {
    return _userPin == input;
  }

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

    try {
      _subscriptions =
          await sl<TransactionLocalDataSource>().getSubscriptions();
    } catch (e) {
      debugPrint("Sub load error: $e");
    }

    _currencySymbol = sl<TransactionLocalDataSource>().getCurrency();
    _userName = sl<TransactionLocalDataSource>().getUserName() ?? 'Usuario';
    // _isDarkMode = sl<TransactionLocalDataSource>().getTheme() ?? true; // Future implementation

    // Goals Init
    // _goals is memory-only for now, so it starts empty.

    _isLoading = false;
    notifyListeners();
  }

  /// Actualiza el límite de presupuesto mensual.
  /// Afecta cómo se calcula el progreso del presupuesto en el Home.
  void setBudgetLimit(double newLimit) {
    _budgetLimit = newLimit;
    notifyListeners();
    // TODO: En una app real, deberíamos persistir este valor aquí (SharedPrefs)
    // For now we simulate persistence
    // sl<TransactionLocalDataSource>().saveMonthlyBudget(newLimit);
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    notifyListeners();
    await sl<TransactionLocalDataSource>().saveUserName(name);
  }

  void toggleTheme(bool value) {
    _isDarkMode = value;
    notifyListeners();
    // Persist if needed
  }

  void toggleNotifications(bool value) {
    _enableNotifications = value;
    notifyListeners();
  }

  void toggleBiometrics(bool value) {
    _enableBiometrics = value;
    notifyListeners();
  }

  Future<void> resetAllData() async {
    _isLoading = true;
    notifyListeners();

    // 1. Clear Preferences
    final dataSource = sl<TransactionLocalDataSource>();
    await dataSource.clearAllData();

    // 2. Clear SQL Database (Critical Fix)
    await LocalDatabase().clearAllTables();

    // 3. Reset Memory State
    resetState();
    _isLoading = false;
  }

  void setStatsMonth(DateTime date) {
    _currentStatsDate = date;
    notifyListeners();
  }

  void setStatsPeriod(PeriodType type) {
    _currentStatsPeriod = type;
    notifyListeners();
  }

  /// Obtiene el gasto total por categoría para el mes actual.
  /// Retorna un mapa: {'Comida': 150.0, 'Transporte': 50.0}
  Map<String, double> get spendingByCategory {
    final now = _currentStatsDate;
    final period = _currentStatsPeriod;

    final expenses = _transactions.where((t) {
      if (t.amount >= 0) return false; // Solo gastos
      if (t.type == TransactionType.transfer)
        return false; // Ignorar transferencias

      if (period == PeriodType.week) {
        // Week Logic: Monday to Sunday
        final startOfWeek =
            now.subtract(Duration(days: now.weekday - 1)); // Monday
        final endOfWeek = startOfWeek
            .add(const Duration(days: 6, hours: 23, minutes: 59)); // Sunday

        // Normalize transaction date to same timezone/logic if needed,
        // but typically simple comparison works if safe.
        // Let's use Year/Month/Day comparison to avoid time issues.
        final tDate = t.date;
        return tDate
                .isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
            tDate.isBefore(endOfWeek.add(const Duration(seconds: 1)));
      } else if (period == PeriodType.year) {
        return t.date.year == now.year;
      } else {
        // Month (Default)
        return t.date.month == now.month && t.date.year == now.year;
      }
    });

    final Map<String, double> result = {};
    for (var t in expenses) {
      // Note: description holds the Category Name.
      final category = t.description;
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

  double get totalSpent {
    return _transactions
        .where((t) => t.amount < 0) // Solo salidas
        .where((t) => t.type != TransactionType.transfer)
        .where((t) => !t.description
            .toLowerCase()
            .contains('transferencia')) // Doble chequeo
        .fold(0.0, (sum, item) => sum + item.amount.abs());
  }

  double get totalIncome {
    return _transactions
        .where((t) => t.amount > 0)
        .where((t) => t.type != TransactionType.transfer)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  /// Get transactions for a specific day (used in HistoryPage Calendar View)
  List<TransactionEntity> getTransactionsForDay(DateTime day) {
    return _transactions
        .where((t) =>
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day)
        .toList();
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
        loadData();
      },
    );
  }

  Future<void> updateTransaction(TransactionEntity transaction) async {
    _isLoading = true;
    notifyListeners();

    final result = await updateTransactionUseCase(
        UpdateTransactionParams(transaction: transaction));

    result.fold(
      (fail) {
        _failure = fail;
        _isLoading = false;
        notifyListeners();
      },
      (_) {
        loadData();
      },
    );
  }

  Future<void> addTransfer({
    required double amount,
    required int sourceAccountId,
    required int destinationAccountId,
    String? note,
  }) async {
    _isLoading = true;
    notifyListeners();

    // Create Single Transfer Transaction
    final transaction = TransactionEntity(
      accountId: sourceAccountId,
      categoryId: 8, // System ID for Transfers
      amount: amount.abs(), // Stored as positive per request
      date: DateTime.now(),
      description: "Transferencia",
      note: note,
      type: TransactionType.transfer,
      destinationAccountId: destinationAccountId,
    );

    final result = await addTransactionUseCase(
        AddTransactionParams(transaction: transaction));

    result.fold(
      (fail) {
        _failure = fail;
        _isLoading = false;
        notifyListeners();
      },
      (_) {
        loadData();
      },
    );
  }

  String getAccountName(int id) {
    // Basic Map based on established IDs
    switch (id) {
      case 1:
        return 'Efectivo';
      case 2:
        return 'Bancaria';
      case 3:
        return 'Ahorros';
      default:
        return 'Cuenta $id';
    }
  }

  Future<void> deleteTransaction(int id) async {
    // Optimistic Update
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();

    final result =
        await deleteTransactionUseCase(DeleteTransactionParams(id: id));

    result.fold(
      (fail) {
        _failure = fail;
        _isLoading = false;
        notifyListeners();
      },
      (_) {
        loadData();
      },
    );
  }

  Future<void> addSubscription(Subscription subscription) async {
    _subscriptions.add(subscription);
    notifyListeners();
    await sl<TransactionLocalDataSource>().cacheSubscriptions(_subscriptions);
  }

  Future<void> removeSubscription(String id) async {
    _subscriptions.removeWhere((s) => s.id == id);
    notifyListeners();
    await sl<TransactionLocalDataSource>().cacheSubscriptions(_subscriptions);
  }

  Future<void> markSubscriptionAsPaid(Subscription subscription) async {
    // 1. Create Expense Transaction
    final transaction = TransactionEntity(
        accountId: subscription.accountToCharge,
        categoryId: 9, // Suscripciones (Using ID 9 from AddTransactionPage)
        amount: -subscription.amount,
        date: DateTime.now(),
        description: subscription.name,
        note: "Pago de suscripción mensual",
        type: TransactionType.expense);

    await addTransaction(transaction);

    // 2. Update Subscription State
    final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (index != -1) {
      _subscriptions[index] = subscription.copyWith(isPaidThisMonth: true);
      notifyListeners();
      await sl<TransactionLocalDataSource>().cacheSubscriptions(_subscriptions);
    }
  }

  double get totalFixedExpenses =>
      _subscriptions.fold(0.0, (sum, item) => sum + item.amount);

  Future<void> setCurrency(String symbol) async {
    _currencySymbol = symbol;
    notifyListeners();
    await sl<TransactionLocalDataSource>().saveCurrency(symbol);
  }

  List<GoalEntity> _goals = [];
  List<GoalEntity> get goals => _goals;

  // Goals Management

  void addGoal(String name, double targetAmount, int iconCode, int colorValue) {
    final newGoal = GoalEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        targetAmount: targetAmount,
        currentAmount: 0,
        iconCode: iconCode,
        colorValue: colorValue);
    _goals.add(newGoal);
    notifyListeners();
  }

  void updateGoal(GoalEntity updatedGoal) {
    final index = _goals.indexWhere((g) => g.id == updatedGoal.id);
    if (index != -1) {
      _goals[index] = updatedGoal;
      notifyListeners();
    }
  }

  void deleteGoal(String id) {
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  Future<void> depositToGoal(
      String goalId, double amount, int sourceAccountId) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return;

    // 1. Create Real Transfer (Source -> Savings)
    // Savings Account ID is 3
    await addTransfer(
        amount: amount,
        sourceAccountId: sourceAccountId,
        destinationAccountId: 3,
        note: "Depósito a Meta: ${_goals[index].name}");

    // 2. Update Goal Local State
    final goal = _goals[index];
    final updatedGoal = GoalEntity(
        id: goal.id,
        name: goal.name,
        targetAmount: goal.targetAmount,
        currentAmount: goal.currentAmount + amount,
        iconCode: goal.iconCode,
        colorValue: goal.colorValue,
        isCompleted: (goal.currentAmount + amount) >= goal.targetAmount);

    _goals[index] = updatedGoal;
    notifyListeners();
  }

  Future<void> purchaseGoal(String goalId) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return;

    final goal = _goals[index];

    // 1. Create Real Expense (Savings -> Shopping/Other)
    // Savings ID = 3
    // Category 3 = Compras (Default) or 8 = Otros
    final transaction = TransactionEntity(
        accountId: 3, // Savings
        categoryId: 3, // Shopping
        amount: -goal.targetAmount, // Negative for Expense
        date: DateTime.now(),
        description: "Meta Cumplida: ${goal.name}",
        note: "Compra realizada con éxito 🏆",
        type: TransactionType.expense);

    await addTransaction(transaction);

    // 2. Remove Goal (or archive)
    _goals.removeAt(index);
    notifyListeners();
  }

  void resetState() {
    _transactions = [];
    _subscriptions = [];
    _goals = [];
    _balanceBreakdown = null;
    _budgetLimit = 2400.00;
    _budgetMood = BudgetMood.neutral;
    _currencySymbol = 'S/';
    notifyListeners();
  }
}
