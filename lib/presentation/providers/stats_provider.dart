import 'package:flutter/material.dart';
import '../../domain/usecases/get_budget_mood_usecase.dart';
import '../../domain/entities/budget_mood.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../core/usecases/usecase.dart';
import '../../core/services/gemini_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enums for Stats
enum PeriodType { week, month, year }

enum StatsType { expense, income }

class StatsProvider extends ChangeNotifier {
  final GetBudgetMoodUseCase getBudgetMood;

  StatsProvider({required this.getBudgetMood}) {
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

  // AI & Advice State
  bool _isAdviceLoading = false;
  String? _weeklyAdvice;
  String? _monthlyAdvice;
  String? _financialAdvice; // Generic/Transient
  DateTime? _lastWeeklyAnalysis;
  DateTime? _lastMonthlyAnalysis;

  bool get isAdviceLoading => _isAdviceLoading;
  String? get weeklyAdvice => _weeklyAdvice;
  String? get monthlyAdvice => _monthlyAdvice;
  String? get financialAdvice => _financialAdvice;

  Future<void> loadStatsData() async {
    final result = await getBudgetMood(NoParams());
    result.fold(
      (fail) => null,
      (mood) => _budgetMood = mood,
    );
    await _loadCoachPersistence();
    notifyListeners();
  }

  void setStatsDate(DateTime date) {
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

  // --- Calculation Logic (Moved from DashboardProvider but requires Data) ---

  Map<String, double> getSpendingByCategory(
      List<TransactionEntity> transactions) {
    final now = _currentStatsDate;
    final period = _currentStatsPeriod;

    final filtered = transactions.where((t) {
      if (_currentStatsType == StatsType.expense) {
        if (t.amount >= 0) return false;
      } else {
        if (t.amount <= 0) return false;
      }

      if (t.type == TransactionType.transfer) return false;

      if (period == PeriodType.week) {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23));
        return t.date
                .isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
            t.date.isBefore(endOfWeek.add(const Duration(seconds: 1)));
      } else if (period == PeriodType.year) {
        return t.date.year == now.year;
      } else {
        return t.date.month == now.month && t.date.year == now.year;
      }
    });

    final Map<String, double> result = {};
    for (var t in filtered) {
      final category =
          t.description; // Description is Category Name in current logic
      if (result.containsKey(category)) {
        result[category] = result[category]! + t.amount.abs();
      } else {
        result[category] = t.amount.abs();
      }
    }
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

  double calculateTotalAmount(List<TransactionEntity> transactions) {
    if (transactions.isEmpty) return 0.0;

    return transactions.where((t) {
      if (t.type == TransactionType.transfer) return false;
      if (_currentStatsType == StatsType.expense) {
        return t.amount < 0;
      } else {
        return t.amount > 0;
      }
    }).fold(0.0, (sum, t) => sum + t.amount.abs());
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
      final diff = now.difference(_lastWeeklyAnalysis!).inDays;
      return diff >= 7;
    } else {
      if (_lastMonthlyAnalysis == null) return true;
      final diff = now.difference(_lastMonthlyAnalysis!).inDays;
      return diff >= 30;
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

  void setFinancialAdvice(String text) {
    _financialAdvice = text;
    notifyListeners();
  }

  Future<void> saveWeeklyAdvice(String text) async {
    _weeklyAdvice = text;
    _lastWeeklyAnalysis = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('weekly_advice_content', text);
    await prefs.setString(
        'last_weekly_analysis_date', _lastWeeklyAnalysis!.toIso8601String());

    setAdviceLoading(false);
  }

  Future<void> saveMonthlyAdvice(String text) async {
    _monthlyAdvice = text;
    _lastMonthlyAnalysis = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('monthly_advice_content', text);
    await prefs.setString(
        'last_monthly_analysis_date', _lastMonthlyAnalysis!.toIso8601String());

    setAdviceLoading(false);
  }

  void showCachedAdvice(String type) {
    if (type == 'weekly') {
      _financialAdvice = _weeklyAdvice;
    } else {
      _financialAdvice = _monthlyAdvice;
    }
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
