import 'package:flutter/material.dart';
import '../../data/models/subscription.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import '../../domain/usecases/delete_transaction_usecase.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/update_transaction_usecase.dart';
import '../../data/datasources/preferences_local_data_source.dart';
import '../../data/datasources/subscription_local_data_source.dart';
import '../../core/services/notification_service.dart';
import '../../domain/usecases/get_transactions_by_date_range_usecase.dart';
import '../../core/constants/app_categories.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/icon_mapper.dart';

class TransactionProvider extends ChangeNotifier {
  final GetTransactionsUseCase getTransactionsUseCase;
  final AddTransactionUseCase addTransactionUseCase;
  final UpdateTransactionUseCase updateTransactionUseCase;
  final DeleteTransactionUseCase deleteTransactionUseCase;
  final GetTransactionsByDateRangeUseCase getTransactionsByDateRange;
  final PreferencesLocalDataSource preferencesLocalDataSource;
  final SubscriptionLocalDataSource subscriptionLocalDataSource;

  TransactionProvider({
    required this.getTransactionsUseCase,
    required this.addTransactionUseCase,
    required this.updateTransactionUseCase,
    required this.deleteTransactionUseCase,
    required this.getTransactionsByDateRange,
    required this.preferencesLocalDataSource,
    required this.subscriptionLocalDataSource,
  }) {
    loadTransactions();
  }

  List<TransactionEntity> _transactions = [];
  List<Subscription> _subscriptions = [];
  bool _isLoading = false;
  String? errorMessage;

  // Paginación
  int _offset = 0;
  final int _limit = 50;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  List<TransactionEntity> get transactions => _transactions;
  List<Subscription> get subscriptions => _subscriptions;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    _offset = 0;
    _hasMore = true;

    final result = await getTransactionsUseCase(
        GetTransactionsParams(limit: _limit, offset: _offset));
    result.fold(
      (fail) => debugPrint("Error loading transactions: $fail"),
      (list) {
        _transactions = list;
        _transactions.sort((a, b) => b.date.compareTo(a.date));
        if (list.length < _limit) _hasMore = false;
      },
    );

    // Migrar datos de SharedPreferences a SQLite si existen
    // Migrar datos (removed)
    await _loadSubscriptions();

    // Validar status (revisar si ya se pagó este ciclo) con optimización O(N+M)
    _checkSubscriptionStatuses();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreTransactions() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    _offset += _limit;
    final result = await getTransactionsUseCase(
        GetTransactionsParams(limit: _limit, offset: _offset));

    result.fold(
      (fail) {
        debugPrint("Error loading more transactions: $fail");
        _offset -= _limit; // revert offset
      },
      (list) {
        if (list.length < _limit) {
          _hasMore = false;
        }
        _transactions.addAll(list);
        _transactions.sort((a, b) => b.date.compareTo(a.date));
      },
    );

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Refresca los datos del provider (útil tras Factory Reset)
  Future<void> refreshData() async {
    _transactions = [];
    _subscriptions = [];
    await loadTransactions();
  }

  Future<void> _loadSubscriptions() async {
    try {
      _subscriptions = await subscriptionLocalDataSource.getSubscriptions();
    } catch (e) {
      debugPrint("Sub load error: $e");
    }
  }

  void _checkSubscriptionStatuses() {
    bool changed = false;
    final now = DateTime.now();

    // Set para suscripciones mensuales pagadas en el mes/año actual
    final Set<String> paidMonthlyNames = {};
    // Set para suscripciones anuales pagadas en el año actual
    final Set<String> paidYearlyNames = {};

    // Escaneo O(N) único sobre las transacciones
    for (var tx in _transactions) {
      if (tx.type == TransactionType.expense) {
        if (tx.date.year == now.year) {
          paidYearlyNames.add(tx.description);
          if (tx.date.month == now.month) {
            paidMonthlyNames.add(tx.description);
          }
        }
      }
    }

    // Escaneo O(M) sobre las suscripciones
    for (int i = 0; i < _subscriptions.length; i++) {
      final sub = _subscriptions[i];
      final bool isPaid = sub.frequency == ExpenseFrequency.monthly
          ? paidMonthlyNames.contains(sub.name)
          : paidYearlyNames.contains(sub.name);

      if (sub.isPaid != isPaid) {
        _subscriptions[i] = sub.copyWith(isPaid: isPaid);
        changed = true;
      }
    }

    if (changed) {
      _saveAllSubscriptionsToDb();
    }
  }

  Future<void> _saveAllSubscriptionsToDb() async {
    for (var sub in _subscriptions) {
      await subscriptionLocalDataSource.saveSubscription(sub);
    }
  }

  Future<void> addTransaction(TransactionEntity transaction) async {
    _isLoading = true;
    notifyListeners();

    final result = await addTransactionUseCase(
        AddTransactionParams(transaction: transaction, updateBalance: true));

    result.fold(
      (fail) {
        debugPrint("❌ ERROR AL GUARDAR TRANSACCIÓN: ${fail.message}");
        errorMessage = fail.message;
        _isLoading = false;
        notifyListeners();
      },
      (_) => loadTransactions(), // Reload (will re-check subs)
    );
  }

  Future<void> updateTransaction(TransactionEntity transaction) async {
    _isLoading = true;
    notifyListeners();

    final result = await updateTransactionUseCase(
        UpdateTransactionParams(transaction: transaction));

    result.fold(
      (fail) {
        errorMessage = fail.message;
        _isLoading = false;
        notifyListeners();
      },
      (_) => loadTransactions(),
    );
  }

  Future<void> deleteTransaction(int id) async {
    _transactions.removeWhere((t) => t.id == id); // Optimistic
    notifyListeners();

    final result =
        await deleteTransactionUseCase(DeleteTransactionParams(id: id));
    result.fold(
      (fail) {
        errorMessage = fail.message;
        loadTransactions();
      },
      (_) => loadTransactions(),
    );
  }

  Future<void> addTransfer({
    required double amount,
    required int sourceAccountId,
    required int destinationAccountId,
    double? receivedAmount,
    String? note,
  }) async {
    final transaction = TransactionEntity(
      accountId: sourceAccountId,
      categoryId: AppConstants.transferCategoryId,
      amount: amount.abs(),
      date: DateTime.now(),
      description: "Transferencia",
      note: note,
      type: TransactionType.transfer,
      destinationAccountId: destinationAccountId,
      receivedAmount: receivedAmount,
    );

    await addTransaction(transaction);
  }

  // --- Subscription Logic ---

  Future<void> addSubscription(Subscription subscription) async {
    final idx = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (idx != -1) {
      _subscriptions[idx] = subscription;
      await subscriptionLocalDataSource.saveSubscription(subscription);
    } else {
      final subWithOrder =
          subscription.copyWith(orderIndex: _subscriptions.length);
      _subscriptions.add(subWithOrder);
      await subscriptionLocalDataSource.saveSubscription(subWithOrder);
    }
    notifyListeners();

    // Schedule notification based on frequency
    if (subscription.frequency == ExpenseFrequency.monthly) {
      await NotificationService().scheduleMonthlyNotification(
        id: subscription.id.hashCode,
        title: "Recordatorio de Pago",
        body: "¡Hoy vence tu pago mensual de ${subscription.name}! 📅",
        dayOfMonth: subscription.paymentDate.day,
        time: const TimeOfDay(hour: 9, minute: 0),
      );
    } else {
      await NotificationService().scheduleYearlyNotification(
        id: subscription.id.hashCode,
        title: "Recordatorio de Pago Anual",
        body: "¡Hoy vence tu pago anual de ${subscription.name}! 📅",
        month: subscription.paymentDate.month,
        day: subscription.paymentDate.day,
        time: const TimeOfDay(hour: 9, minute: 0),
      );
    }
  }

  Future<void> removeSubscription(String id) async {
    _subscriptions.removeWhere((s) => s.id == id);
    notifyListeners();
    await subscriptionLocalDataSource.deleteSubscription(id);
    await NotificationService().cancelNotification(id.hashCode);
  }

  Future<void> markSubscriptionAsPaid(Subscription subscription) async {
    final transaction = TransactionEntity(
        accountId: subscription.accountToCharge,
        categoryId: subscription.categoryId,
        amount: -subscription.amount,
        date: DateTime.now(),
        description: subscription.name,
        note: subscription.frequency == ExpenseFrequency.monthly
            ? "Pago mensual"
            : "Pago anual",
        type: TransactionType.expense,
        iconCode: subscription.customIcon != null
            ? IconMapper.getIcon(subscription.customIcon).codePoint
            : AppCategories.getIcon(subscription.categoryId).codePoint,
        colorValue: subscription.customColor ??
            AppCategories.getColor(subscription.categoryId).toARGB32());

    // Optimistic Update manual para bloqueo INMEDIATO en la UI
    final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (index != -1) {
      final updatedSub = subscription.copyWith(isPaid: true);
      _subscriptions[index] = updatedSub;
      // Guardar en SQLite inmediatamente
      await subscriptionLocalDataSource.saveSubscription(updatedSub);
      notifyListeners();
    }

    // Agregar la transacción y recargar (re-calculando status automáticamente)
    await addTransaction(transaction);
  }

  void reorderSubscriptions(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _subscriptions.removeAt(oldIndex);
    _subscriptions.insert(newIndex, item);

    for (int i = 0; i < _subscriptions.length; i++) {
      _subscriptions[i] = _subscriptions[i].copyWith(orderIndex: i);
      subscriptionLocalDataSource.saveSubscription(_subscriptions[i]);
    }

    notifyListeners();
  }

  Future<List<TransactionEntity>> getTransactionsForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day, 0, 0, 0);
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59);

    final result = await getTransactionsByDateRange(
        DateRangeParams(start: start, end: end));
    return result.fold(
      (fail) => [],
      (list) => list,
    );
  }

  // --- Dev Tools ---
  Future<void> generateFakeData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final fakeTransactions = [
      TransactionEntity(
          accountId: 1, // Cash
          categoryId: 1, // Food? (Assuming IDs)
          amount: -15.00,
          date: now,
          description: "Almuerzo",
          note: "Menu ejecutivo",
          type: TransactionType.expense),
      TransactionEntity(
          accountId: 2, // Bank
          categoryId: 5, // Salary?
          amount: 1500.00,
          date: yesterday,
          description: "Sueldo",
          note: "Pago de nómina",
          type: TransactionType.income),
      TransactionEntity(
          accountId: 2,
          categoryId: 3,
          amount: -5.90,
          date: now,
          description: "Yape",
          type: TransactionType.expense),
    ];

    for (var t in fakeTransactions) {
      await addTransaction(t);
    }
  }
}
