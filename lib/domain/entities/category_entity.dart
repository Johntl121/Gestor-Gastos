import 'package:equatable/equatable.dart';

class CategoryEntity extends Equatable {
  final int? id;
  final String name;
  final String icon; // Icon identifier (e.g. font awesome code or asset path)
  final int color; // Hex color value
  final bool isExpense; // true for Expense, false for Income

  const CategoryEntity({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isExpense,
  });

  @override
  List<Object?> get props => [id, name, icon, color, isExpense];
}
