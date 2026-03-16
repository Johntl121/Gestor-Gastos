import '../../domain/entities/goal_entity.dart';

class GoalModel extends GoalEntity {
  GoalModel({
    required super.id,
    required super.name,
    required super.targetAmount,
    required super.currentAmount,
    required super.iconCode,
    required super.colorValue,
    super.isCompleted,
    super.deadline,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'],
      name: json['name'],
      targetAmount: (json['targetAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num).toDouble(),
      iconCode: json['iconCode'],
      colorValue: json['colorValue'],
      isCompleted: json['isCompleted'] == null ? false : (json['isCompleted'] == 1 || json['isCompleted'] == true),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'isCompleted': isCompleted ? 1 : 0,
      'deadline': deadline?.toIso8601String(),
    };
  }

  factory GoalModel.fromEntity(GoalEntity entity) {
    return GoalModel(
      id: entity.id,
      name: entity.name,
      targetAmount: entity.targetAmount,
      currentAmount: entity.currentAmount,
      iconCode: entity.iconCode,
      colorValue: entity.colorValue,
      isCompleted: entity.isCompleted,
      deadline: entity.deadline,
    );
  }
}
