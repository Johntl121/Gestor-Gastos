import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
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
import '../../domain/usecases/account_usecases.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/usecases/delete_account_usecase.dart';
import '../../domain/usecases/update_account_usecase.dart';

enum PeriodType { week, month, year }

enum StatsType { expense, income }

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
  final CreateAccountUseCase createAccountUseCase;
  final GetAccountsUseCase getAccountsUseCase;
  final DeleteAccountUseCase deleteAccountUseCase;
  final UpdateAccountUseCase updateAccountUseCase;

  DashboardProvider({
    required this.getAccountBalance,
    required this.getBudgetMood,
    required this.addTransactionUseCase,
    required this.getTransactionsUseCase,
    required this.getMonthlyBudgetUseCase,
    required this.updateTransactionUseCase,
    required this.deleteTransactionUseCase,
    required this.createAccountUseCase,
    required this.getAccountsUseCase,
    required this.deleteAccountUseCase,
    required this.updateAccountUseCase,
  }) {
    _userPin = sl<TransactionLocalDataSource>().getSecurityPin();
    loadData();
  }

  BalanceBreakdown? _balanceBreakdown;
  BudgetMood _budgetMood = BudgetMood.neutral; // Estado por defecto
  bool _isLoading = false;
  Failure? _failure;
  List<TransactionEntity> _transactions = [];
  List<AccountEntity> _accounts = []; // New Accounts List
  List<Subscription> _subscriptions = [];
  String _currencySymbol = 'S/';
  String _userName = 'Usuario';
  String _userAvatar = '😎'; // Default
  String? _profileImagePath;
  DateTime _currentStatsDate = DateTime.now();
  PeriodType _currentStatsPeriod = PeriodType.month;
  StatsType _currentStatsType = StatsType.expense;

  double _budgetLimit = 2400.00;
  bool _isDarkMode = true;
  bool _enableNotifications = true;
  bool _enableBiometrics = false;

  BalanceBreakdown? get balanceBreakdown => _balanceBreakdown;
  List<AccountEntity> get accounts => _accounts;

  // Mock Exchange Rates (Base: PEN/S/)
  static const Map<String, double> _exchangeRatesToPEN = {
    'S/': 1.0,
    '\$': 3.75, // USD
    '€': 4.10, // EUR
    '¥': 0.025, // JPY
    '₽': 0.040, // RUB
    '₿': 350000.0 // BTC (Example)
  };

  // Computed Totals from Accounts List (Normalized to Base Currency)
  double get totalBalance =>
      _accounts.where((a) => a.includeInTotal).fold(0.0, (sum, acc) {
        final rate = _exchangeRatesToPEN[acc.currencySymbol] ?? 1.0;
        return sum + (acc.currentBalance * rate);
      });

  // Legacy getters for backward compatibility (mapped from simple IDs or Names)
  double get cashBalance => _accounts
      .firstWhere((a) => a.id == 1 || a.name == 'Efectivo',
          orElse: () =>
              _accounts.firstOrNull ??
              const AccountEntity(
                  id: 0,
                  name: '',
                  initialBalance: 0,
                  currencySymbol: '',
                  colorValue: 0,
                  iconCode: 0))
      .currentBalance;

  // Bank is usually ID 2
  double get bankBalance => _accounts
      .firstWhere((a) => a.id == 2 || a.name == 'Bancaria',
          orElse: () => const AccountEntity(
              id: 0,
              name: '',
              initialBalance: 0,
              currencySymbol: '',
              colorValue: 0,
              iconCode: 0))
      .currentBalance;

  // Savings is usually ID 3
  double get savingsBalance => _accounts
      .firstWhere((a) => a.id == 3 || a.name == 'Ahorros',
          orElse: () => const AccountEntity(
              id: 0,
              name: '',
              initialBalance: 0,
              currencySymbol: '',
              colorValue: 0,
              iconCode: 0))
      .currentBalance;

  BudgetMood get budgetMood => _budgetMood;
  bool get isLoading => _isLoading;
  double get budgetLimit => _budgetLimit;
  List<TransactionEntity> get transactions => _transactions;
  List<Subscription> get subscriptions => _subscriptions;
  String get currencySymbol => _currencySymbol;
  String get userName => _userName;
  String get userAvatar => _userAvatar;
  String? get profileImagePath => _profileImagePath;
  DateTime get currentStatsDate => _currentStatsDate;

  PeriodType get currentStatsPeriod => _currentStatsPeriod;
  StatsType get currentStatsType => _currentStatsType;
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
    sl<TransactionLocalDataSource>().saveSecurityPin(pin);
  }

  /// Removes the current PIN.
  void removePin() {
    _userPin = null;
    notifyListeners();
    sl<TransactionLocalDataSource>().saveSecurityPin(null);
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

    // Obtener Saldo (Legacy Breakdown)
    final balanceResult = await getAccountBalance(NoParams());
    balanceResult.fold(
      (fail) => _failure = fail,
      (balance) => _balanceBreakdown = balance,
    );

    // Obtener Cuentas (New)
    final accountsResult = await getAccountsUseCase(NoParams());
    accountsResult.fold(
      (fail) => _failure = fail,
      (accounts) => _accounts = accounts,
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
    _userAvatar = sl<TransactionLocalDataSource>().getUserAvatar();
    _profileImagePath = sl<TransactionLocalDataSource>().getProfileImagePath();
    _userPin =
        sl<TransactionLocalDataSource>().getSecurityPin(); // Load Security PIN
    // _isDarkMode = sl<TransactionLocalDataSource>().getTheme() ?? true; // Future implementation

    // Goals Init
    // _goals is memory-only for now, so it starts empty.

    await _loadCoachPersistence();

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
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    notifyListeners();
    await sl<TransactionLocalDataSource>().saveUserName(name);
  }

  Future<void> setUserAvatar(String avatar) async {
    _userAvatar = avatar;
    _profileImagePath = null; // Clear custom image if avatar is selected
    notifyListeners();
    await sl<TransactionLocalDataSource>().saveUserAvatar(avatar);
    await sl<TransactionLocalDataSource>().saveProfileImagePath(null);
  }

  Future<void> setProfileImagePath(String? path) async {
    _profileImagePath = path;
    notifyListeners();
    await sl<TransactionLocalDataSource>().saveProfileImagePath(path);
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

  Future<void> resetCoachTimers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_weekly_analysis_date');
    await prefs.remove('last_monthly_analysis_date');
    await prefs.remove('weekly_advice_content');
    await prefs.remove('monthly_advice_content');

    // Reset memory state variables related to coach logic
    _lastWeeklyAnalysis = null;
    _lastMonthlyAnalysis = null;
    _weeklyAdvice = null;
    _monthlyAdvice = null;
    _financialAdvice = null;

    notifyListeners();
  }

  Future<void> seedTestData() async {
    _isLoading = true;
    notifyListeners();

    // Insert 1 Income
    await addTransaction(
        TransactionEntity(
            id: DateTime.now().millisecondsSinceEpoch,
            accountId: 1, // Efectivo
            categoryId: 11, // Otros/Ingreso
            amount: 2000.0,
            date: DateTime.now(),
            description: "Sueldo Dev",
            type: TransactionType.income),
        updateBalance: false);

    // Insert 3 Expenses
    await addTransaction(
        TransactionEntity(
            id: DateTime.now().millisecondsSinceEpoch + 1,
            accountId: 1,
            categoryId: 1, // Comida
            amount: -50.0,
            date: DateTime.now(),
            description: "Pizza Test",
            type: TransactionType.expense),
        updateBalance: false);

    await addTransaction(
        TransactionEntity(
            id: DateTime.now().millisecondsSinceEpoch + 2,
            accountId: 1,
            categoryId: 2, // Transporte
            amount: -20.0,
            date: DateTime.now(),
            description: "Uber Test",
            type: TransactionType.expense),
        updateBalance: false);

    await addTransaction(TransactionEntity(
        id: DateTime.now().millisecondsSinceEpoch + 3,
        accountId: 1,
        categoryId: 3, // Compras
        amount: -150.0,
        date: DateTime.now().subtract(const Duration(days: 1)),
        description: "Ropa Test",
        type: TransactionType
            .expense)); // Last one updates balance triggering loadData
  }

  void setStatsMonth(DateTime date) {
    _currentStatsDate = date;
    notifyListeners();
  }

  void setStatsPeriod(PeriodType type) {
    _currentStatsPeriod = type;
    notifyListeners();
  }

  void setStatsType(StatsType type) {
    _currentStatsType = type;
    notifyListeners();
  }

  /// Obtiene el gasto total por categoría para el mes actual.
  /// Retorna un mapa: {'Comida': 150.0, 'Transporte': 50.0}
  Map<String, double> get spendingByCategory {
    final now = _currentStatsDate;
    final period = _currentStatsPeriod;

    final expenses = _transactions.where((t) {
      // 1. Filter by Type (Expense vs Income)
      if (_currentStatsType == StatsType.expense) {
        if (t.amount >= 0) return false; // Solo gastos (negativos)
      } else {
        if (t.amount <= 0) return false; // Solo ingresos (positivos)
      }

      if (t.type == TransactionType.transfer) {
        return false; // Ignorar transferencias
      }
      // ... rest of date filtering ...

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
  /// Obtiene el total de gastos (o ingresos) del mes actual según el filtro seleccionado.
  double get totalStatsAmount {
    return spendingByCategory.values.fold(0.0, (sum, item) => sum + item);
  }

  // Legacy (Keep for Home Page Budget Calculation)
  double get totalMonthlyExpenses {
    // Force specific calculation for expenses regardless of filter
    // This is a bit hacky but safe for getters without side effects if we duplicate logic
    // Better to extract logic. For now, let's just replicate the specific filter for expenses.
    final now = DateTime.now();
    return _transactions
        .where((t) =>
            t.amount < 0 &&
            t.type != TransactionType.transfer &&
            t.date.month == now.month &&
            t.date.year == now.year)
        .fold(0.0, (sum, t) => sum + t.amount.abs());
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

  Future<void> addTransaction(TransactionEntity transaction,
      {bool updateBalance = true}) async {
    _isLoading = true;
    notifyListeners();

    final result = await addTransactionUseCase(AddTransactionParams(
        transaction: transaction, updateBalance: updateBalance));

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
    double? receivedAmount,
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
      receivedAmount: receivedAmount,
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
    try {
      return _accounts.firstWhere((a) => a.id == id).name;
    } catch (e) {
      // Fallback for Legacy or Deleted Accounts
      switch (id) {
        case 1:
          return 'Efectivo'; // Legacy fallback
        case 2:
          return 'Bancaria'; // Legacy fallback
        case 3:
          return 'Ahorros'; // Legacy fallback
        default:
          return 'Cuenta Eliminada';
      }
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

    // Schedule Notification
    // Use hashCode of ID string simply
    await NotificationService().scheduleMonthlyNotification(
      id: subscription.id.hashCode,
      title: "Recordatorio de Pago",
      body: "¡Hoy vence tu pago de ${subscription.name}! 📅",
      dayOfMonth: subscription.renewalDay,
      time: const TimeOfDay(hour: 9, minute: 0),
    );
  }

  Future<void> removeSubscription(String id) async {
    _subscriptions.removeWhere((s) => s.id == id);
    notifyListeners();
    await sl<TransactionLocalDataSource>().cacheSubscriptions(_subscriptions);

    // Cancel Notification
    await NotificationService().cancelNotification(id.hashCode);
  }

  void reorderSubscriptions(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final Subscription item = _subscriptions.removeAt(oldIndex);
    _subscriptions.insert(newIndex, item);
    notifyListeners();
    // Cache new order
    sl<TransactionLocalDataSource>().cacheSubscriptions(_subscriptions);
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

  Future<void> deleteGoal(String id,
      {bool refund = false, int? refundAccountId}) async {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index == -1) return;

    final goal = _goals[index];

    if (refund && refundAccountId != null && goal.currentAmount > 0) {
      // Create Refund Transaction (Income)
      final transaction = TransactionEntity(
          accountId: refundAccountId,
          categoryId:
              14, // Using Ahorro category for consistency or 10/12 if preferred
          amount: goal.currentAmount, // Positive for Income
          date: DateTime.now(),
          description: "Reembolso Meta: ${goal.name}",
          note: "Dinero devuelto al eliminar meta",
          type: TransactionType.income); // Treat as Income to restore balance

      await addTransaction(transaction);
    }

    _goals.removeAt(index);
    notifyListeners();
  }

  void reorderGoals(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final GoalEntity item = _goals.removeAt(oldIndex);
    _goals.insert(newIndex, item);
    notifyListeners();
  }

  Future<void> depositToGoal(
      String goalId, double amount, int sourceAccountId) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return;

    final goal = _goals[index];

    // 1. Create Expense Transaction (Reduces Source Balance)
    // We categorize it as "Ahorro" generally.
    final transaction = TransactionEntity(
        accountId: sourceAccountId,
        categoryId:
            14, // Assuming 14 is 'Ahorro' based on filter list in HistoryPage, or use generic
        amount: -amount, // Negative for Expense/Outflow
        date: DateTime.now(),
        description: "Meta: ${goal.name}",
        note: "Ahorro procesado",
        type: TransactionType.expense);

    await addTransaction(transaction);

    // 2. Update Goal Local State (Only tracks progress, doesn't add to Savings Account)
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

    await addTransaction(transaction); // Call once

    _goals.removeAt(index);
    notifyListeners();
  }

  Future<void> createAccount(AccountEntity account) async {
    _isLoading = true;
    notifyListeners();

    final result =
        await createAccountUseCase(CreateAccountParams(account: account));

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

  Future<void> updateAccount(AccountEntity account) async {
    // Optimistic Update
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      _accounts[index] = account;
      notifyListeners();
    }

    final result =
        await updateAccountUseCase(UpdateAccountParams(account: account));

    result.fold((fail) {
      _failure = fail;
      notifyListeners();
      loadData();
    }, (_) => loadData());
  }

  // --- Account Deletion Logic ---
  final List<AccountEntity> _deletedAccounts = [];

  void softDeleteAccount(AccountEntity account) {
    _deletedAccounts.add(account);
    _accounts.removeWhere((a) => a.id == account.id);
    notifyListeners();
  }

  void undoDeleteAccount(AccountEntity account) {
    if (_deletedAccounts.any((a) => a.id == account.id)) {
      _deletedAccounts.removeWhere((a) => a.id == account.id);
      _accounts.add(account);
      _accounts.sort((a, b) => a.id.compareTo(b.id));
      notifyListeners();
    }
  }

  Future<void> confirmDeleteAccount(int id) async {
    _deletedAccounts.removeWhere((a) => a.id == id);

    final result = await deleteAccountUseCase(DeleteAccountParams(id: id));

    result.fold((fail) {
      _failure = fail;
      notifyListeners();
      loadData();
    }, (_) {
      loadData();
    });
  }

  void resetState() {
    _transactions = [];
    _accounts = []; // Correctly reset accounts
    _subscriptions = [];
    _goals = [];
    _financialAdvice = null;
    _balanceBreakdown = null;
    _budgetLimit = 2400.00;
    _budgetMood = BudgetMood.neutral;
    _currencySymbol = 'S/';
    notifyListeners();
  }

  // --- Financial Coach Optimization & Persistence ---
  String? _financialAdvice;
  bool _isAdviceLoading = false;

  DateTime? _lastWeeklyAnalysis;
  DateTime? _lastMonthlyAnalysis;
  String? _weeklyAdvice;
  String? _monthlyAdvice;

  String? get financialAdvice => _financialAdvice;
  bool get isAdviceLoading => _isAdviceLoading;
  DateTime? get lastWeeklyAnalysis => _lastWeeklyAnalysis;
  DateTime? get lastMonthlyAnalysis => _lastMonthlyAnalysis;
  String? get weeklyAdvice => _weeklyAdvice;
  String? get monthlyAdvice => _monthlyAdvice;

  void setFinancialAdvice(String? advice) {
    _financialAdvice = advice;
    notifyListeners();
  }

  void setAdviceLoading(bool loading) {
    _isAdviceLoading = loading;
    notifyListeners();
  }

  Future<void> _loadCoachPersistence() async {
    final prefs = await SharedPreferences.getInstance();
    final weeklyDateStr = prefs.getString('last_weekly_analysis_date');
    if (weeklyDateStr != null) {
      _lastWeeklyAnalysis = DateTime.tryParse(weeklyDateStr);
    }
    final monthlyDateStr = prefs.getString('last_monthly_analysis_date');
    if (monthlyDateStr != null) {
      _lastMonthlyAnalysis = DateTime.tryParse(monthlyDateStr);
    }

    _weeklyAdvice = prefs.getString('weekly_advice_content');
    _monthlyAdvice = prefs.getString('monthly_advice_content');
  }

  Future<void> saveWeeklyAdvice(String advice) async {
    _weeklyAdvice = advice;
    _financialAdvice = advice; // Show it immediately
    _lastWeeklyAnalysis = DateTime.now();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weekly_advice_content', advice);
    await prefs.setString(
        'last_weekly_analysis_date', _lastWeeklyAnalysis!.toIso8601String());
  }

  Future<void> saveMonthlyAdvice(String advice) async {
    _monthlyAdvice = advice;
    _financialAdvice = advice; // Show it immediately
    _lastMonthlyAnalysis = DateTime.now();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('monthly_advice_content', advice);
    await prefs.setString(
        'last_monthly_analysis_date', _lastMonthlyAnalysis!.toIso8601String());
  }

  bool canRequestAnalysis(String type) {
    if (type == 'weekly') {
      if (_lastWeeklyAnalysis == null) return true;
      final diff = DateTime.now().difference(_lastWeeklyAnalysis!);
      return diff.inDays >= 7;
    } else {
      // Monthly
      if (_lastMonthlyAnalysis == null) return true;
      final diff = DateTime.now().difference(_lastMonthlyAnalysis!);
      return diff.inDays >= 30;
    }
  }

  int getDaysUntilAvailable(String type) {
    if (type == 'weekly') {
      if (_lastWeeklyAnalysis == null) return 0;
      final diff = DateTime.now().difference(_lastWeeklyAnalysis!);
      return (7 - diff.inDays).clamp(0, 7);
    } else {
      if (_lastMonthlyAnalysis == null) return 0;
      final diff = DateTime.now().difference(_lastMonthlyAnalysis!);
      return (30 - diff.inDays).clamp(0, 30);
    }
  }

  void showCachedAdvice(String type) {
    if (type == 'weekly') {
      _financialAdvice = _weeklyAdvice ?? "No hay análisis semanal previo.";
    } else {
      _financialAdvice = _monthlyAdvice ?? "No hay balance mensual previo.";
    }
    notifyListeners();
  }
}
