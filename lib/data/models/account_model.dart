import '../../domain/entities/account_entity.dart';

class AccountModel extends AccountEntity {
  const AccountModel({
    super.id,
    required super.name,
    required super.type,
    required super.currentBalance,
    super.icon,
    required super.color,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'],
      name: json['name'],
      type: json['type'] == 'CASH'
          ? AccountEnumType.cash
          : AccountEnumType.digital,
      currentBalance: (json['balance'] as num).toDouble(),
      icon: json['icon'],
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type == AccountEnumType.cash ? 'CASH' : 'DIGITAL',
      'balance': currentBalance,
      'icon': icon,
      'color': color,
    };
  }
}
