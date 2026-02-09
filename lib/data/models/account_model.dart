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
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'],
      name: json['name'],
      initialBalance: (json['initialBalance'] as num?)?.toDouble() ?? 0.0,
      currencySymbol: json['currencySymbol'] ?? '',
      colorValue: json['colorValue'] ?? 0,
      iconCode: json['iconCode'] ?? 0,
      // Handle db optional column default
      includeInTotal:
          json['includeInTotal'] == null ? true : (json['includeInTotal'] == 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'initialBalance': initialBalance,
      'currencySymbol': currencySymbol,
      'colorValue': colorValue,
      'iconCode': iconCode,
      'includeInTotal': includeInTotal ? 1 : 0,
    };
  }
}
