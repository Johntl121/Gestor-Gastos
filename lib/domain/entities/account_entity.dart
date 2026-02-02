enum AccountType {
  const accountTypeCash = 'CASH';
  const accountTypeDigital = 'DIGITAL';
}

enum AccountEnumType {
  cash,
  digital,
}

import 'package:equatable/equatable.dart';

class AccountEntity extends Equatable {
  final int? id;
  final String name;
  final AccountEnumType type; // 'CASH' o 'DIGITAL'
  final double currentBalance;
  final String? icon;
  final int color;

  const AccountEntity({
    this.id,
    required this.name,
    required this.type,
    required this.currentBalance,
    this.icon,
    required this.color,
  });

  @override
  List<Object?> get props => [id, name, type, currentBalance, icon, color];
}
