import 'package:flutter/material.dart';
import '../../core/constants/icon_mapper.dart';

class GoalEntity {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final int iconCode; // Store icon as codePoint (fallback)
  final String? iconName; // Store icon as string name for IconMapper
  final int colorValue; // Store color as int
  final bool isCompleted;
  final DateTime? deadline;
  final int? accountId; // Cuenta "Alcancía" destino
  final int? categoryId; // Categoría inferida por Smart Icon

  GoalEntity({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.iconCode,
    this.iconName,
    required this.colorValue,
    this.isCompleted = false,
    this.deadline,
    this.accountId,
    this.categoryId,
  });

  /// Resuelve el ícono: prioriza `iconName` (Smart Icon) sobre `iconCode` (legacy)
  IconData get icon {
    if (iconName != null && iconName!.isNotEmpty) {
      return IconMapper.getIcon(iconName);
    }
    return IconData(iconCode, fontFamily: 'MaterialIcons');
  }

  Color get color => Color(colorValue);

  /// Progreso como fracción (0.0 a 1.0)
  double get progress => targetAmount > 0
      ? (currentAmount / targetAmount).clamp(0.0, 1.0)
      : 0.0;

  /// Monto restante para completar la meta
  double get remainingAmount => (targetAmount - currentAmount).clamp(0.0, targetAmount);

  /// Días restantes hasta el deadline (null si no hay deadline)
  int? get daysRemaining {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now()).inDays;
  }

  /// Ahorro mensual sugerido para llegar a tiempo al deadline
  double? get suggestedMonthlySavings {
    if (deadline == null || remainingAmount <= 0) return null;
    final months = deadline!.difference(DateTime.now()).inDays / 30.0;
    if (months <= 0) return null;
    return remainingAmount / months;
  }
}
