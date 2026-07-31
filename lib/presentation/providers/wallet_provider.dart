import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/balance_breakdown.dart';
import '../../domain/entities/goal_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/account_usecases.dart';
import '../../domain/usecases/delete_account_usecase.dart';
import '../../domain/usecases/get_account_balance_usecase.dart';
import '../../domain/usecases/get_monthly_budget_usecase.dart';
import '../../domain/usecases/update_account_usecase.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import '../../data/models/goal_model.dart';
import '../../data/datasources/preferences_local_data_source.dart';
import '../../data/datasources/goal_local_data_source.dart';
import '../../core/constants/app_constants.dart';

class WalletProvider extends ChangeNotifier {
  final GetAccountBalanceUseCase getAccountBalance;
  final GetAccountsUseCase getAccountsUseCase;
  final CreateAccountUseCase createAccountUseCase;
  final UpdateAccountUseCase updateAccountUseCase;
  final DeleteAccountUseCase deleteAccountUseCase;
  final GetMonthlyBudgetUseCase getMonthlyBudgetUseCase;
  final AddTransactionUseCase addTransactionUseCase;
  final PreferencesLocalDataSource preferencesLocalDataSource;
  final GoalLocalDataSource goalLocalDataSource;

  WalletProvider({
    required this.getAccountBalance,
    required this.getAccountsUseCase,
    required this.createAccountUseCase,
    required this.updateAccountUseCase,
    required this.deleteAccountUseCase,
    required this.getMonthlyBudgetUseCase,
    required this.addTransactionUseCase,
    required this.preferencesLocalDataSource,
    required this.goalLocalDataSource,
  }) {
    // Initialization is now explicit via initApp()
  }

  List<AccountEntity> _accounts = [];
  BalanceBreakdown? _balanceBreakdown;
  double _budgetLimit = 2400.00;
  List<GoalEntity> _goals = [];
  String _currencySymbol = 'S/';
  String? errorMessage;

  List<AccountEntity> get accounts => _accounts;
  BalanceBreakdown? get balanceBreakdown => _balanceBreakdown;
  double get budgetLimit => _budgetLimit;
  List<GoalEntity> get goals => _goals;
  String get currencySymbol => _currencySymbol;

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  // Mock Exchange Rates
  static const Map<String, double> exchangeRatesToPEN = {
    'S/': 1.0,
    '\$': 3.75,
    '€': 4.10,
    '¥': 0.025,
    '₽': 0.040,
    '₿': 350000.0,
  };

  /// Cálculo Dinámico: Suma los saldos convirtiéndolos a la moneda preferida del usuario
  double get totalBalance {
    final targetSymbol = _currencySymbol;
    final targetRate = exchangeRatesToPEN[targetSymbol] ?? 1.0;

    return _accounts.where((a) => a.includeInTotal).fold(0.0, (sum, acc) {
      final sourceRate = exchangeRatesToPEN[acc.currencySymbol] ?? 1.0;
      // Convertimos: (Monto * RateOrigen) / RateDestino
      final convertedAmount = (acc.currentBalance * sourceRate) / targetRate;
      return sum + convertedAmount;
    });
  }

  /// Singleton de Inicialización
  Future<void> initApp() async {
    debugPrint("🔄 Inicializando WalletProvider...");

    // Migrar datos de SharedPreferences a SQLite si existen
    // Migration check (now removed)

    // Solo cargamos datos. La creación inicial es responsabilidad del Onboarding.
    await loadWalletData();

    // Verificamos y corregimos duplicados si existen (Self-Healing)
    await fixDuplicates();

    // Persistimos que ya no es 'first run' para esta lógica local, por si acaso
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('is_first_run') ?? true) {
      await prefs.setBool('is_first_run', false);
    }
  }

  /// Limpieza de Datos (Self-Healing)
  /// Elimina cuentas duplicadas basándose en el nombre
  Future<void> fixDuplicates() async {
    // Cargamos primero para asegurar que tenemos la lista en memoria
    if (_accounts.isEmpty) {
      await loadWalletData();
    }

    // Si sigue vacía, no hay nada que limpiar
    if (_accounts.isEmpty) return;

    final seenNames = <String>{};
    final uniqueAccounts = <AccountEntity>[];
    final duplicates = <AccountEntity>[];

    for (var account in _accounts) {
      if (seenNames.contains(account.name)) {
        duplicates.add(account);
      } else {
        seenNames.add(account.name);
        uniqueAccounts.add(account);
      }
    }

    if (duplicates.isNotEmpty) {
      debugPrint(
          "⚠️ Duplicados detectados: ${duplicates.length}. Iniciando limpieza...");
      for (var duplicate in duplicates) {
        debugPrint(
            "🗑️ Eliminando duplicado: ${duplicate.name} (ID: ${duplicate.id})");
        await deleteAccountUseCase(DeleteAccountParams(id: duplicate.id));
      }
      // Recargar datos limpios
      await loadWalletData();
      debugPrint("✅ Limpieza completada.");
    } else {
      debugPrint("✨ No se encontraron duplicados.");
    }
  }

  Future<void> loadWalletData() async {
    // 1. Get Accounts
    final accountsResult = await getAccountsUseCase(NoParams());
    accountsResult.fold(
      (fail) => debugPrint("Error loading accounts: $fail"),
      (accounts) => _accounts = accounts,
    );

    // 2. Get Balance Breakdown
    final balanceResult = await getAccountBalance(NoParams());
    balanceResult.fold(
      (fail) => null,
      (balance) => _balanceBreakdown = balance,
    );

    // 3. Get Budget
    final budgetResult = await getMonthlyBudgetUseCase(NoParams());
    budgetResult.fold(
      (fail) => null,
      (budget) => _budgetLimit = budget,
    );

    // 4. Load Goals
    final cachedGoals = await goalLocalDataSource.getGoals();
    _goals = List<GoalEntity>.from(cachedGoals);

    // 5. Load Currency Symbol
    _currencySymbol = preferencesLocalDataSource.getCurrency();

    notifyListeners();
  }

  /// Refresca los datos del provider (útil tras Factory Reset)
  Future<void> refreshData() async {
    _accounts = [];
    _goals = [];
    _balanceBreakdown = null;
    await loadWalletData();
  }

  Future<int> createAccount(AccountEntity account) async {
    final result =
        await createAccountUseCase(CreateAccountParams(account: account));
    return result.fold(
      (fail) {
        debugPrint("Error creating account: $fail");
        errorMessage = fail.message;
        notifyListeners();
        return account.id;
      },
      (insertedId) {
        loadWalletData();
        return insertedId;
      },
    );
  }

  Future<void> updateAccount(AccountEntity account) async {
    final result =
        await updateAccountUseCase(UpdateAccountParams(account: account));
    result.fold(
      (fail) {
        debugPrint("Error updating account: $fail");
        errorMessage = fail.message;
        notifyListeners();
      },
      (_) => loadWalletData(),
    );
  }

  Future<void> deleteAccount(int id) async {
    final result = await deleteAccountUseCase(DeleteAccountParams(id: id));
    result.fold(
      (fail) {
        debugPrint("Error deleting account: $fail");
        errorMessage = fail.message;
        notifyListeners();
      },
      (_) => loadWalletData(),
    );
  }

  // Soft Delete Logic
  final List<AccountEntity> _temporarilyDeletedAccounts = [];

  void softDeleteAccount(AccountEntity account) {
    _accounts.removeWhere((a) => a.id == account.id);
    _temporarilyDeletedAccounts.add(account);
    notifyListeners();
  }

  void undoDeleteAccount(AccountEntity account) {
    _temporarilyDeletedAccounts.removeWhere((a) => a.id == account.id);
    _accounts.add(account);
    notifyListeners();
  }

  Future<void> confirmDeleteAccount(int id) async {
    _temporarilyDeletedAccounts.removeWhere((a) => a.id == id);
    await deleteAccount(id);
  }

  Future<void> setBudgetLimit(double newLimit) async {
    _budgetLimit = newLimit;
    notifyListeners();
    await preferencesLocalDataSource.saveBudgetLimit(newLimit);
  }

  Future<void> setCurrency(String symbol) async {
    _currencySymbol = symbol;
    notifyListeners();
    await preferencesLocalDataSource.saveCurrency(symbol);
  }

  // --- Goals Section ---

  void addGoal(String name, double targetAmount, int iconCode, int colorValue,
      {String? iconName, DateTime? deadline, int? accountId, int? categoryId}) async {
    final newGoal = GoalModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        targetAmount: targetAmount,
        currentAmount: 0,
        iconCode: iconCode,
        iconName: iconName,
        colorValue: colorValue,
        isCompleted: false,
        deadline: deadline,
        accountId: accountId,
        categoryId: categoryId);
    _goals.add(newGoal);
    notifyListeners();
    await goalLocalDataSource.saveGoal(newGoal);
  }

  // Eliminado _saveGoals ya que usaremos persistencia individual por meta-id

  void updateGoal(GoalEntity updatedGoal) async {
    final index = _goals.indexWhere((g) => g.id == updatedGoal.id);
    if (index != -1) {
      _goals[index] = updatedGoal;
      notifyListeners();
      await goalLocalDataSource.saveGoal(GoalModel.fromEntity(updatedGoal));
    }
  }

  Future<void> deleteGoal(String id,
      {bool refund = false, int? refundAccountId}) async {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index == -1) return;

    final goal = _goals[index];

    if (refund && refundAccountId != null && goal.currentAmount > 0) {
      final transaction = TransactionEntity(
          accountId: refundAccountId,
          categoryId: 14,
          amount: goal.currentAmount,
          date: DateTime.now(),
          description: "Reembolso Meta: ${goal.name}",
          note: "Dinero devuelto al eliminar meta",
          type: TransactionType.income);

      await addTransactionUseCase(
          AddTransactionParams(transaction: transaction));
      await loadWalletData(); // Refresh balances
    }

    _goals.removeAt(index);
    notifyListeners();
    await goalLocalDataSource.deleteGoal(id);
  }

  void reorderGoals(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final GoalEntity item = _goals.removeAt(oldIndex);
    _goals.insert(newIndex, item);
    notifyListeners();
    // Al igual que con subs, el orden en SQLite relacional es por ID o timestamp unless we add an order col.
  }

  Future<void> depositToGoal(
      String goalId, double amount, int sourceAccountId) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return;

    final goal = _goals[index];

    // CONTABILIDAD: TRANSFER desde la cuenta origen hacia la alcancía de la meta
    final transaction = TransactionEntity(
        accountId: sourceAccountId,
        categoryId: AppConstants.transferCategoryId,
        amount: amount,
        date: DateTime.now(),
        description: "Transferencia Meta: ${goal.name}",
        note: "Ahorro depositado a meta",
        type: TransactionType.transfer,
        destinationAccountId: goal.accountId);

    await addTransactionUseCase(AddTransactionParams(transaction: transaction));
    await loadWalletData();

    final updatedGoal = GoalEntity(
        id: goal.id,
        name: goal.name,
        targetAmount: goal.targetAmount,
        currentAmount: goal.currentAmount + amount,
        iconCode: goal.iconCode,
        iconName: goal.iconName,
        colorValue: goal.colorValue,
        isCompleted: goal.isCompleted,
        deadline: goal.deadline,
        accountId: goal.accountId,
        categoryId: goal.categoryId);

    _goals[index] = updatedGoal;
    notifyListeners();
    await goalLocalDataSource.saveGoal(GoalModel.fromEntity(updatedGoal));
  }

  Future<void> purchaseGoal(String goalId, {int? categoryId}) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return;

    final goal = _goals[index];

    // Determinar accountId: la alcancía de la meta, o la primera cuenta disponible
    final purchaseAccountId = goal.accountId ?? (_accounts.isNotEmpty ? _accounts.first.id : 1);

    // Determinar categoría: param override > meta.categoryId > default Compras
    final finalCategoryId = categoryId ?? goal.categoryId ?? AppConstants.shoppingCategoryId;

    // CONTABILIDAD: EXPENSE desde la alcancía de la meta
    final transaction = TransactionEntity(
        accountId: purchaseAccountId,
        categoryId: finalCategoryId,
        amount: -goal.currentAmount, // Gastar lo que realmente se ahorró
        date: DateTime.now(),
        description: "Meta Cumplida: ${goal.name}",
        note: "Compra realizada con éxito 🏆",
        type: TransactionType.expense);

    await addTransactionUseCase(AddTransactionParams(transaction: transaction));
    await loadWalletData();

    // Marcar como completada (NO eliminar — futuro Muro de Trofeos)
    final completedGoal = GoalEntity(
        id: goal.id,
        name: goal.name,
        targetAmount: goal.targetAmount,
        currentAmount: goal.currentAmount,
        iconCode: goal.iconCode,
        iconName: goal.iconName,
        colorValue: goal.colorValue,
        isCompleted: true,
        deadline: goal.deadline,
        accountId: goal.accountId,
        categoryId: goal.categoryId);

    _goals[index] = completedGoal;
    notifyListeners();
    await goalLocalDataSource.saveGoal(GoalModel.fromEntity(completedGoal));
  }

  String getAccountName(int id) {
    try {
      return _accounts.firstWhere((a) => a.id == id).name;
    } catch (e) {
      return 'Cuenta Desconocida';
    }
  }
}
