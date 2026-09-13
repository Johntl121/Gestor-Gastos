import '../../domain/entities/account_entity.dart';

class AccountModel extends AccountEntity {
  const AccountModel({
    required super.id,
    required super.name,
    required super.initialBalance,
    required super.currencySymbol,
    required super.colorValue,
    required super.iconCode,
    super.includeInTotal = true,
    super.isCash = false,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'],
      name: json['name'],
      initialBalance: (json['balance'] as num?)?.toDouble() ??
          0.0, // In standard query balance is initial
      currencySymbol: json['currencySymbol'] ?? 'S/',
      colorValue: json['color'] ?? 0, // DB column is 'color' in some parts
      iconCode: json['iconCode'] ?? 58343,
      includeInTotal:
          json['includeInTotal'] == null ? true : (json['includeInTotal'] == 1),
      isCash: json['type'] == 'CASH',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'balance': initialBalance, // DB column is 'balance'
      'currencySymbol': currencySymbol,
      'color': colorValue, // DB column is 'color'
      'iconCode': iconCode,
      'includeInTotal': includeInTotal ? 1 : 0,
      'type': isCash ? 'CASH' : 'DIGITAL',
    };
  }
}
