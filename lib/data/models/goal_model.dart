import '../../domain/entities/goal_entity.dart';

class GoalModel extends GoalEntity {
  GoalModel({
    required super.id,
    required super.name,
    required super.targetAmount,
    required super.currentAmount,
    required super.iconCode,
    super.iconName,
    required super.colorValue,
    super.isCompleted,
    super.deadline,
    super.accountId,
    super.categoryId,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'],
      name: json['name'],
      targetAmount: (json['targetAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num).toDouble(),
      iconCode: json['iconCode'] ?? 0xE838, // Icons.star fallback
      iconName: json['iconName'],
      colorValue: json['colorValue'] ?? 0xFF00BCD4, // Colors.cyan fallback
      isCompleted: json['isCompleted'] == null
          ? false
          : (json['isCompleted'] == 1 || json['isCompleted'] == true),
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'])
          : null,
      accountId: json['accountId'],
      categoryId: json['categoryId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'iconCode': iconCode,
      'iconName': iconName,
      'colorValue': colorValue,
      'isCompleted': isCompleted ? 1 : 0,
      'deadline': deadline?.toIso8601String(),
      'accountId': accountId,
      'categoryId': categoryId,
    };
  }

  factory GoalModel.fromEntity(GoalEntity entity) {
    return GoalModel(
      id: entity.id,
      name: entity.name,
      targetAmount: entity.targetAmount,
      currentAmount: entity.currentAmount,
      iconCode: entity.iconCode,
      iconName: entity.iconName,
      colorValue: entity.colorValue,
      isCompleted: entity.isCompleted,
      deadline: entity.deadline,
      accountId: entity.accountId,
      categoryId: entity.categoryId,
    );
  }
}
