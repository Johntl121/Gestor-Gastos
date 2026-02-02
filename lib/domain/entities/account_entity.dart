import 'package:equatable/equatable.dart';

class AccountType {
  static const String cash = 'CASH';
  static const String digital = 'DIGITAL';
}

enum AccountEnumType {
  cash,
  digital,
}

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
