import 'package:flutter/material.dart';
import '../../core/constants/app_categories.dart';
import '../../domain/usecases/get_budget_mood_usecase.dart';
import '../../domain/entities/budget_mood.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../data/models/subscription.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/usecases/get_transactions_by_date_range_usecase.dart';
import '../../data/datasources/preferences_local_data_source.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../data/datasources/goal_local_data_source.dart';
import 'wallet_provider.dart';
import '../../domain/entities/category_group.dart';

// Enums for Stats
enum PeriodType { week, month, year }

enum StatsType { expense, income }

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
  final SubscriptionRepository subscriptionRepository;
  final GoalLocalDataSource goalLocalDataSource;

  StatsProvider({
    required this.getBudgetMood,
    required this.getTransactionsByDateRange,
    required this.preferencesLocalDataSource,
    required this.subscriptionRepository,
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
  WalletProvider? _walletProvider;
  bool _isLoadingTransactions = false;

  void updateWalletProvider(WalletProvider wp) {
    _walletProvider = wp;
    notifyListeners();
  }

  // Set transactions from external source;

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

  // Currency Support
  String get currencySymbol => preferencesLocalDataSource.getCurrency();

  Future<void> loadStatsData() async {
    final result = await getBudgetMood(NoParams());
    result.fold(
      (fail) => null,
      (mood) => _budgetMood = mood,
    );
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

  // --- Calculation Logic ---

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

      double convertedAmount = t.amount.abs();
      if (_walletProvider != null && _walletProvider!.accounts.isNotEmpty) {
        final account = _walletProvider!.accounts.firstWhere(
            (a) => a.id == t.accountId,
            orElse: () => _walletProvider!.accounts.first);
        convertedAmount = _walletProvider!.currencyConverter.convert(
            t.amount.abs(),
            account.currencySymbol,
            _walletProvider!.currencySymbol);
      }

      if (groups.containsKey(name)) {
        groups[name]!.amount += convertedAmount;
      } else {
        groups[name] = _InternalGroup(name, convertedAmount, color, icon);
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
}

