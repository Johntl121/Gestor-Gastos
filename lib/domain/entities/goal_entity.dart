import 'package:flutter/material.dart';

class GoalEntity {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final int iconCode; // Store icon as codePoint
  final int colorValue; // Store color as int
  final bool isCompleted;
  final DateTime? deadline;

  GoalEntity({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.iconCode,
    required this.colorValue,
    this.isCompleted = false,
    this.deadline,
  });

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
}
