import 'package:flutter/material.dart';
import '../../core/constants/app_categories.dart';
import '../../domain/usecases/get_budget_mood_usecase.dart';
import '../../domain/entities/budget_mood.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../data/models/subscription.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/usecases/get_transactions_by_date_range_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/preferences_local_data_source.dart';
import '../../data/datasources/subscription_local_data_source.dart';
import '../../data/datasources/goal_local_data_source.dart';

// Enums for Stats
enum PeriodType { week, month, year }

enum StatsType { expense, income }

class CategoryGroup {
  final String name;
  final double amount;
  final Color color;
  final IconData icon;

  CategoryGroup({
    required this.name,
    required this.amount,
    required this.color,
    required this.icon,
  });
}

class _InternalGroup {
  final String name;
  double amount;
  final Color color;
  final IconData icon;
  _InternalGroup(this.name, this.amount, this.color, this.icon);
}

class StatsProvider extends ChangeNotifier {
  final GetBudgetMoodUseCase getBudgetMood;
  final GetTransactionsByDateRangeUseCase getTransactionsByDateRange;
  final PreferencesLocalDataSource preferencesLocalDataSource;
  final SubscriptionLocalDataSource subscriptionLocalDataSource;
  final GoalLocalDataSource goalLocalDataSource;

  StatsProvider({
    required this.getBudgetMood,
    required this.getTransactionsByDateRange,
    required this.preferencesLocalDataSource,
    required this.subscriptionLocalDataSource,
    required this.goalLocalDataSource,
  }) {
    loadStatsData();
  }

  BudgetMood _budgetMood = BudgetMood.neutral;
  BudgetMood get budgetMood => _budgetMood;

  // Stats Controls
  DateTime _currentStatsDate = DateTime.now();
  PeriodType _currentStatsPeriod = PeriodType.month;
  StatsType _currentStatsType = StatsType.expense;

  DateTime get currentStatsDate => _currentStatsDate;
  PeriodType get currentStatsPeriod => _currentStatsPeriod;
  StatsType get currentStatsType => _currentStatsType;

  List<TransactionEntity> _allTransactions = [];
  List<TransactionEntity> _currentPeriodTransactions = [];
  bool _isLoadingTransactions = false;

  List<TransactionEntity> get transactions => _allTransactions;
  List<TransactionEntity> get currentPeriodTransactions =>
      _currentPeriodTransactions;
  bool get isLoadingTransactions => _isLoadingTransactions;

  /// Sincroniza todas las transacciones desde el TransactionProvider
  void setAllTransactions(List<TransactionEntity> transactions) {
    _allTransactions = transactions;
    // Si ya cargamos stats antes, refrescamos el periodo actual con la nueva data
    _loadTransactionsForPeriodInternal();
  }

  // AI & Advice State
  bool _isAdviceLoading = false;
  String? _weeklyAdvice;
  String? _monthlyAdvice;
  DateTime? _lastWeeklyAnalysis;
  DateTime? _lastMonthlyAnalysis;

  bool get isAdviceLoading => _isAdviceLoading;
  String? get weeklyAdvice => _weeklyAdvice;
  String? get monthlyAdvice => _monthlyAdvice;

  // Currency Support
  String get currencySymbol => preferencesLocalDataSource.getCurrency();

  /// Devuelve el advice correspondiente al modo seleccionado en el Sheet
  String? currentAdvice(String mode) =>
      mode == 'weekly' ? _weeklyAdvice : _monthlyAdvice;

  Future<void> loadStatsData() async {
    final result = await getBudgetMood(NoParams());
    result.fold(
      (fail) => null,
      (mood) => _budgetMood = mood,
    );
    await _loadCoachPersistence();
    // No llamamos a loadTransactionsForPeriod aquí porque ahora depende de setAllTransactions (ProxyProvider)
    notifyListeners();
  }

  Future<void> loadTransactionsForPeriod() async {
    // Si no tenemos transacciones aún, intentamos cargar desde BD (fallback o primer inicio)
    if (_allTransactions.isEmpty) {
      _isLoadingTransactions = true;
      notifyListeners();

      DateTime start;
      DateTime end;

      if (_currentStatsPeriod == PeriodType.week) {
        start = _currentStatsDate
            .subtract(Duration(days: _currentStatsDate.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = start
            .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      } else if (_currentStatsPeriod == PeriodType.year) {
        start = DateTime(_currentStatsDate.year, 1, 1);
        end = DateTime(_currentStatsDate.year, 12, 31, 23, 59, 59);
      } else {
        start = DateTime(_currentStatsDate.year, _currentStatsDate.month, 1);
        end = DateTime(
            _currentStatsDate.year, _currentStatsDate.month + 1, 0, 23, 59, 59);
      }

      final result = await getTransactionsByDateRange(
          DateRangeParams(start: start, end: end));

      result.fold(
        (fail) => _currentPeriodTransactions = [],
        (list) => _currentPeriodTransactions = list,
      );

      _isLoadingTransactions = false;
    } else {
      // Filtrado en memoria (más rápido y siempre sincronizado)
      _loadTransactionsForPeriodInternal();
    }
    notifyListeners();
  }

  void _loadTransactionsForPeriodInternal() {
    DateTime start;
    DateTime end;

    if (_currentStatsPeriod == PeriodType.week) {
      start = _currentStatsDate
          .subtract(Duration(days: _currentStatsDate.weekday - 1));
      start = DateTime(start.year, start.month, start.day);
      end = start
          .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    } else if (_currentStatsPeriod == PeriodType.year) {
      start = DateTime(_currentStatsDate.year, 1, 1);
      end = DateTime(_currentStatsDate.year, 12, 31, 23, 59, 59);
    } else {
      start = DateTime(_currentStatsDate.year, _currentStatsDate.month, 1);
      end = DateTime(
          _currentStatsDate.year, _currentStatsDate.month + 1, 0, 23, 59, 59);
    }

    _currentPeriodTransactions = _allTransactions.where((t) {
      return t.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          t.date.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();
  }

  void setStatsDate(DateTime date) {
    _currentStatsDate = date;
    loadTransactionsForPeriod();
  }

  void setStatsPeriod(PeriodType type) {
    _currentStatsPeriod = type;
    loadTransactionsForPeriod();
  }

  void setStatsType(StatsType type) {
    _currentStatsType = type;
    notifyListeners();
  }

  // --- Calculation Logic (Sincronizada con Coach IA) ---

  List<CategoryGroup> getSpendingByCategory(List<Subscription> subscriptions) {
    final Map<String, _InternalGroup> groups = {};

    // 1. Usar Transacciones ya filtradas por la base de datos
    final filteredTransactions = _currentPeriodTransactions
        .where((t) => t.type != TransactionType.transfer);

    for (var t in filteredTransactions) {
      if (_currentStatsType == StatsType.expense && t.amount >= 0) continue;
      if (_currentStatsType == StatsType.income && t.amount <= 0) continue;

      // REGLA: Excluir Saldo Inicial estrictamente (descripcion que lo contenga)
      if (t.description.toLowerCase().contains("saldo inicial")) continue;

      // 1. Obtener Metadatos de Categoría Estandarizados
      // Priorizamos los datos vinculados al ID de categoría de la semilla maestra
      final String name = AppCategories.getName(t.categoryId);
      final Color color = AppCategories.getColor(t.categoryId);
      final IconData icon = AppCategories.getIcon(t.categoryId);

      if (groups.containsKey(name)) {
        groups[name]!.amount += t.amount.abs();
      } else {
        groups[name] = _InternalGroup(name, t.amount.abs(), color, icon);
      }
    }

    final result = groups.values
        .map((g) => CategoryGroup(
              name: g.name,
              amount: g.amount,
              color: g.color,
              icon: g.icon,
            ))
        .toList();

    // Ordenar por monto descendente
    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  List<TransactionEntity> filterTransactionsByDate(
      List<TransactionEntity> transactions, DateTime date, PeriodType period) {
    return transactions.where((t) {
      if (t.type == TransactionType.transfer) return false;

      final tDate = t.date;

      if (period == PeriodType.week) {
        final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
        final endOfWeek =
            startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59));
        return tDate
                .isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
            tDate.isBefore(endOfWeek.add(const Duration(seconds: 1)));
      } else if (period == PeriodType.year) {
        return tDate.year == date.year;
      } else {
        // Month
        return tDate.month == date.month && tDate.year == date.year;
      }
    }).toList();
  }

  double calculateTotalAmount(List<CategoryGroup> categories) {
    return categories.fold(0.0, (sum, c) => sum + c.amount);
  }

  // --- AI Context Builder ---

  Future<String> buildFinancialContextForAI() async {
    // unused variable removed
    final budgetLimit = preferencesLocalDataSource.getBudgetLimit();

    // 1. Totales (usando transacciones ya en memoria para el periodo seleccionado)
    double totalIncome = 0;
    double totalExpense = 0;

    for (var t in _currentPeriodTransactions) {
      if (t.type == TransactionType.income) totalIncome += t.amount.abs();
      if (t.type == TransactionType.expense) totalExpense += t.amount.abs();
    }

    final buffer = StringBuffer();
    buffer.writeln("DATOS DEL USUARIO:");
    buffer.writeln("Moneda Principal: $currencySymbol");
    buffer.writeln();
    buffer.writeln("--- RESUMEN DEL PERIODO ---");
    buffer.writeln(
        "Total Ingresos: $currencySymbol ${totalIncome.toStringAsFixed(2)}");
    buffer.writeln(
        "Total Gastos: $currencySymbol ${totalExpense.toStringAsFixed(2)}");
    buffer.writeln(
        "Presupuesto Mensual: $currencySymbol ${budgetLimit.toStringAsFixed(2)}");
    buffer.writeln();

    // 2. Gastos por Categoría (Top 5)
    buffer.writeln("--- GASTOS POR CATEGORÍA (Top 5) ---");
    final categories = getSpendingByCategory(
        []); // Sin suscripciones extra para el resumen puro
    final topCategories = categories.take(5).toList();
    for (int i = 0; i < topCategories.length; i++) {
      buffer.writeln(
          "${i + 1}. ${topCategories[i].name}: $currencySymbol ${topCategories[i].amount.toStringAsFixed(2)}");
    }
    buffer.writeln();

    // 3. Gastos Fijos (Desde SQLite)
    final subscriptions = await subscriptionLocalDataSource.getSubscriptions();
    if (subscriptions.isNotEmpty) {
      buffer.writeln("--- GASTOS FIJOS ACTIVOS ---");
      for (var s in subscriptions) {
        buffer.writeln(
            "- ${s.name}: $currencySymbol ${s.amount.toStringAsFixed(2)} | Vence el día: ${s.paymentDate.day}");
      }
      buffer.writeln();
    }

    // 4. Metas de Ahorro (Desde SQLite)
    final goals = await goalLocalDataSource.getGoals();
    if (goals.isNotEmpty) {
      buffer.writeln("--- METAS DE AHORRO ---");
      for (var g in goals) {
        buffer.writeln(
            "- ${g.name}: $currencySymbol ${g.currentAmount.toStringAsFixed(2)} / $currencySymbol ${g.targetAmount.toStringAsFixed(2)}");
      }
    }

    return buffer.toString();
  }

  // --- Coach / AI Logic ---

  Future<void> _loadCoachPersistence() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Timestamps
    final lastWeekly = prefs.getString('last_weekly_analysis_date');
    if (lastWeekly != null) _lastWeeklyAnalysis = DateTime.parse(lastWeekly);

    final lastMonthly = prefs.getString('last_monthly_analysis_date');
    if (lastMonthly != null) _lastMonthlyAnalysis = DateTime.parse(lastMonthly);

    // Load Content
    _weeklyAdvice = prefs.getString('weekly_advice_content');
    _monthlyAdvice = prefs.getString('monthly_advice_content');
  }

  bool canRequestAnalysis(String type) {
    final now = DateTime.now();
    if (type == 'weekly') {
      if (_lastWeeklyAnalysis == null) return true;
      return now.difference(_lastWeeklyAnalysis!) >= const Duration(days: 7);
    } else {
      if (_lastMonthlyAnalysis == null) return true;
      return now.difference(_lastMonthlyAnalysis!) >= const Duration(days: 30);
    }
  }

  int getDaysUntilAvailable(String type) {
    if (canRequestAnalysis(type)) return 0;
    final now = DateTime.now();
    if (type == 'weekly' && _lastWeeklyAnalysis != null) {
      return 7 - now.difference(_lastWeeklyAnalysis!).inDays;
    }
    if (type == 'monthly' && _lastMonthlyAnalysis != null) {
      return 30 - now.difference(_lastMonthlyAnalysis!).inDays;
    }
    return 0;
  }

  void setAdviceLoading(bool v) {
    _isAdviceLoading = v;
    notifyListeners();
  }

  Future<void> saveWeeklyAdvice(String text) async {
    _weeklyAdvice = text;
    _lastWeeklyAnalysis = DateTime.now();
    _isAdviceLoading = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weekly_advice_content', text);
    await prefs.setString(
        'last_weekly_analysis_date', _lastWeeklyAnalysis!.toIso8601String());

    notifyListeners();
  }

  Future<void> saveMonthlyAdvice(String text) async {
    _monthlyAdvice = text;
    _lastMonthlyAnalysis = DateTime.now();
    _isAdviceLoading = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('monthly_advice_content', text);
    await prefs.setString(
        'last_monthly_analysis_date', _lastMonthlyAnalysis!.toIso8601String());

    notifyListeners();
  }

  // --- Dev Tools ---
  Future<void> resetCoachCooldown() async {
    _lastWeeklyAnalysis = null;
    _lastMonthlyAnalysis = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_weekly_analysis_date');
    await prefs.remove('last_monthly_analysis_date');

    notifyListeners();
  }
}
