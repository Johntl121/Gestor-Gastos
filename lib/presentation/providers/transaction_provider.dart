import 'package:flutter/material.dart';
import '../../data/models/subscription.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../core/errors/failure.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import '../../domain/usecases/delete_transaction_usecase.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/update_transaction_usecase.dart';
import '../../domain/usecases/subscriptions/pay_subscription_usecase.dart';
import '../../data/datasources/preferences_local_data_source.dart';
import '../../data/datasources/subscription_local_data_source.dart';
import '../../core/services/notification_coordinator.dart';
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
  final PaySubscriptionUseCase paySubscriptionUseCase;
  final PreferencesLocalDataSource preferencesLocalDataSource;
  final SubscriptionLocalDataSource subscriptionLocalDataSource;
  final NotificationCoordinator notificationCoordinator;
  final VoidCallback? onSessionExpired;

  TransactionProvider({
    required this.getTransactionsUseCase,
    required this.addTransactionUseCase,
    required this.updateTransactionUseCase,
    required this.deleteTransactionUseCase,
    required this.getTransactionsByDateRange,
    required this.paySubscriptionUseCase,
    required this.preferencesLocalDataSource,
    required this.subscriptionLocalDataSource,
    required this.notificationCoordinator,
    this.onSessionExpired,
  }) {
    loadTransactions();
  }



  List<TransactionEntity> _transactions = [];
  bool _isLoading = false;
  String? errorMessage;

  // Paginación
  int _offset = 0;
  final int _limit = 50;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  List<TransactionEntity> get transactions => _transactions;
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

    await loadTransactions();
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

  // --- Subscription Logic (Payment) ---

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

    final result = await paySubscriptionUseCase(PaySubscriptionParams(
      subscription: subscription,
      transaction: transaction,
    ));

    result.fold(
      (Failure fail) {
        debugPrint("❌ ERROR AL PAGAR SUSCRIPCIÓN: ${fail.message}");
        errorMessage = fail.message;
        notifyListeners();
      },
      (_) async {
        final updatedSub = subscription.copyWith(isPaid: true);
        await notificationCoordinator.scheduleSubscription(updatedSub);
        await loadTransactions();
      },
    );
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
