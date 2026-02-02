import 'package:equatable/equatable.dart';

class CategoryEntity extends Equatable {
  final int? id;
  final String name;
  final String icon; // Identificador de icono (ej. font awesome o ruta de asset)
  final int color; // Valor de color en Hex
  final bool isExpense; // true para Gasto, false para Ingreso

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
