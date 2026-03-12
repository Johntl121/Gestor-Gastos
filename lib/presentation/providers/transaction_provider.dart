import 'package:flutter/material.dart';
import '../../core/usecases/usecase.dart';
import '../../data/models/subscription.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import '../../domain/usecases/delete_transaction_usecase.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/update_transaction_usecase.dart';
import '../../injection_container.dart';
import '../../data/repositories/transaction_data_source.dart';
import '../../core/services/notification_service.dart';

class TransactionProvider extends ChangeNotifier {
  final GetTransactionsUseCase getTransactionsUseCase;
  final AddTransactionUseCase addTransactionUseCase;
  final UpdateTransactionUseCase updateTransactionUseCase;
  final DeleteTransactionUseCase deleteTransactionUseCase;

  TransactionProvider({
    required this.getTransactionsUseCase,
    required this.addTransactionUseCase,
    required this.updateTransactionUseCase,
    required this.deleteTransactionUseCase,
  }) {
    loadTransactions();
  }

  List<TransactionEntity> _transactions = [];
  List<Subscription> _subscriptions = [];
  bool _isLoading = false;

  List<TransactionEntity> get transactions => _transactions;
  List<Subscription> get subscriptions => _subscriptions;
  bool get isLoading => _isLoading;

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    final result = await getTransactionsUseCase(NoParams());
    result.fold(
      (fail) => debugPrint("Error loading transactions: $fail"),
      (list) {
        _transactions = list;
        _transactions.sort((a, b) => b.date.compareTo(a.date));
      },
    );

    await _loadSubscriptions();

    // Validar status (revisar si ya se pagó este ciclo)
    _checkSubscriptionStatuses();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSubscriptions() async {
    try {
      _subscriptions =
          await sl<TransactionLocalDataSource>().getSubscriptions();
    } catch (e) {
      debugPrint("Sub load error: $e");
    }
  }

  void _checkSubscriptionStatuses() {
    bool changed = false;

    for (int i = 0; i < _subscriptions.length; i++) {
      final sub = _subscriptions[i];
      // Definimos la ventana de pago:
      // Mensual: Desde el comienzo del mes de la dueDate hasta la dueDate.
      // Anual: Desde el comienzo del año de la dueDate (o mes anterior?) -> Simplifiquemos a "Este mes/año".

      bool foundPayment = false;

      // Buscamos una transacción que coincida
      // Criterio: Misma descripción (nombre) y dentro del mes/año actual.
      final now = DateTime.now();

      for (var tx in _transactions) {
        if (tx.type == TransactionType.expense && tx.description == sub.name) {
          if (sub.frequency == ExpenseFrequency.monthly) {
            // Para mensual: Debe ser del mismo MES y AÑO actual
            if (tx.date.month == now.month && tx.date.year == now.year) {
              foundPayment = true;
              break;
            }
          } else {
            // Para anual: Debe ser del mismo AÑO actual
            if (tx.date.year == now.year) {
              foundPayment = true;
              break;
            }
          }
        }
      }

      if (sub.isPaid != foundPayment) {
        // Actualizamos solo si cambió
        _subscriptions[i] = sub.copyWith(isPaid: foundPayment);
        changed = true;
      }
    }

    if (changed) {
      // Guardamos el estado actualizado (opcional, pero buena práctica para persistencia UI)
      sl<TransactionLocalDataSource>().cacheSubscriptions(_subscriptions);
      // notifyListeners se llama al final de loadTransactions
    }
  }

  Future<void> addTransaction(TransactionEntity transaction) async {
    _isLoading = true;
    notifyListeners();

    final result = await addTransactionUseCase(
        AddTransactionParams(transaction: transaction, updateBalance: true));

    result.fold(
      (fail) {
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
        loadTransactions();
      },
      (_) => loadTransactions(),
    );
  }

  Future<void> addTransfer({
    required double amount,
    required int sourceAccountId,
    required int destinationAccountId,
    String? note,
  }) async {
    final transaction = TransactionEntity(
      accountId: sourceAccountId,
      categoryId: 8,
      amount: amount.abs(),
      date: DateTime.now(),
      description: "Transferencia",
      note: note,
      type: TransactionType.transfer,
      destinationAccountId: destinationAccountId,
    );

    await addTransaction(transaction);
  }

  // --- Subscription Logic ---

  Future<void> addSubscription(Subscription subscription) async {
    final idx = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (idx != -1) {
      _subscriptions[idx] = subscription;
    } else {
      _subscriptions.add(subscription);
    }
    notifyListeners();
    await sl<TransactionLocalDataSource>().cacheSubscriptions(_subscriptions);

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
    await sl<TransactionLocalDataSource>().cacheSubscriptions(_subscriptions);
    await NotificationService().cancelNotification(id.hashCode);
  }

  Future<void> markSubscriptionAsPaid(Subscription subscription) async {
    final transaction = TransactionEntity(
        accountId: subscription.accountToCharge,
        categoryId: 9, // Let's keep 9 just in case, or change if needed.
        amount: -subscription.amount,
        date: DateTime.now(),
        description: subscription.name,
        note: subscription.frequency == ExpenseFrequency.monthly
            ? "Pago mensual"
            : "Pago anual",
        type: TransactionType.expense,
        iconCode: subscription.iconCode,
        colorValue: subscription.colorValue);

    // Optimistic Update manual para bloqueo INMEDIATO en la UI
    final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
    if (index != -1) {
      _subscriptions[index] = subscription.copyWith(isPaid: true);
      // Guardar en cache inmediatamente para que loadTransactions no pise el optimistic state
      await sl<TransactionLocalDataSource>().cacheSubscriptions(_subscriptions);
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
    notifyListeners();
    sl<TransactionLocalDataSource>().cacheSubscriptions(_subscriptions);
  }

  List<TransactionEntity> getTransactionsForDay(DateTime day) {
    return _transactions
        .where((t) =>
            t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day)
        .toList();
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
