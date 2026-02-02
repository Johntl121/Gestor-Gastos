import '../../domain/entities/category_entity.dart';

class CategoryModel extends CategoryEntity {
  const CategoryModel({
    super.id,
    required super.name,
    required super.icon,
    required super.color,
    required super.isExpense,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      color: json['color'],
      isExpense: json['type'] == 'EXPENSE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'type': isExpense ? 'EXPENSE' : 'INCOME',
    };
  }
}
