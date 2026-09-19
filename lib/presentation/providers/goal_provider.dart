import 'package:flutter/material.dart';
import '../../domain/entities/goal_entity.dart';
import '../../domain/usecases/goal_operations_usecases.dart';
import '../../domain/repositories/goal_operations_repository.dart';

class GoalProvider extends ChangeNotifier {
  final GoalOperationsRepository goalOperationsRepository;
  final DepositToGoalUseCase depositToGoalUseCase;
  final PurchaseGoalUseCase purchaseGoalUseCase;
  final DeleteGoalAtomicUseCase deleteGoalAtomicUseCase;

  GoalProvider({
    required this.goalOperationsRepository,
    required this.depositToGoalUseCase,
    required this.purchaseGoalUseCase,
    required this.deleteGoalAtomicUseCase,
  });

  List<GoalEntity> _goals = [];
  String? errorMessage;

  List<GoalEntity> get goals => _goals;

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<void> loadGoals() async {
    final result = await goalOperationsRepository.getGoals();
    result.fold(
      (fail) => debugPrint("Error loading goals: $fail"),
      (goals) {
        _goals = List<GoalEntity>.from(goals);
        notifyListeners();
      },
    );
  }

  void addGoal(String name, double targetAmount, int iconCode, int colorValue,
      {String? iconName,
      DateTime? deadline,
      int? accountId,
      int? categoryId}) async {
    final newGoal = GoalEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      targetAmount: targetAmount,
      currentAmount: 0,
      iconCode: iconCode,
      iconName: iconName,
      colorValue: colorValue,
      deadline: deadline,
      accountId: accountId,
      categoryId: categoryId,
      orderIndex: _goals.length,
    );
    _goals.add(newGoal);
    notifyListeners();
    await goalOperationsRepository.saveGoal(newGoal);
  }

  void updateGoal(GoalEntity updatedGoal) async {
    final index = _goals.indexWhere((g) => g.id == updatedGoal.id);
    if (index != -1) {
      _goals[index] = updatedGoal;
      notifyListeners();
      await goalOperationsRepository.saveGoal(updatedGoal);
    }
  }

  Future<bool> deleteGoal(String id, {bool refund = false, int? refundAccountId}) async {
    final result = await deleteGoalAtomicUseCase(
      DeleteGoalAtomicParams(
        goalId: id,
        refund: refund,
        refundAccountId: refundAccountId,
      ),
    );

    return result.fold(
      (fail) {
        debugPrint("Error deleting goal: $fail");
        errorMessage = fail.message;
        notifyListeners();
        return false;
      },
      (_) {
        loadGoals();
        return true;
      },
    );
  }

  void reorderGoals(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final GoalEntity item = _goals.removeAt(oldIndex);
    _goals.insert(newIndex, item);

    for (int i = 0; i < _goals.length; i++) {
      _goals[i] = _goals[i].copyWith(orderIndex: i);
      goalOperationsRepository.saveGoal(_goals[i]);
    }
    notifyListeners();
  }

  Future<bool> depositToGoal(
      String goalId, double amount, int sourceAccountId) async {
    final result = await depositToGoalUseCase(
      DepositToGoalParams(
        goalId: goalId,
        amount: amount,
        sourceAccountId: sourceAccountId,
      ),
    );

    return result.fold(
      (fail) {
        debugPrint("Error depositing to goal: $fail");
        errorMessage = fail.message;
        notifyListeners();
        return false;
      },
      (_) {
        loadGoals();
        return true;
      },
    );
  }

  Future<bool> purchaseGoal(String goalId, {int? categoryId}) async {
    final result = await purchaseGoalUseCase(
      PurchaseGoalParams(
        goalId: goalId,
        categoryId: categoryId,
      ),
    );

    return result.fold(
      (fail) {
        debugPrint("Error processing goal purchase: $fail");
        errorMessage = fail.message;
        notifyListeners();
        return false;
      },
      (_) {
        loadGoals();
        return true;
      },
    );
  }
}
