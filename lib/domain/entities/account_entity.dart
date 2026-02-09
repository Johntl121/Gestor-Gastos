import 'package:equatable/equatable.dart';

class AccountEntity extends Equatable {
  final int id;
  final String name;
  final double initialBalance;
  final String currencySymbol;
  final int colorValue;
  final int iconCode;

  /// Determines if this account's balance counts towards the total net worth
  final bool includeInTotal;

  // Calculated at runtime, not stored
  final double currentBalance;

  const AccountEntity({
    required this.id,
    required this.name,
    required this.initialBalance,
    required this.currencySymbol,
    required this.colorValue,
    required this.iconCode,
    this.includeInTotal = true,
    this.currentBalance = 0.0,
  });

  AccountEntity copyWith({
    int? id,
    String? name,
    double? initialBalance,
    String? currencySymbol,
    int? colorValue,
    int? iconCode,
    bool? includeInTotal,
    double? currentBalance,
  }) {
    return AccountEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      initialBalance: initialBalance ?? this.initialBalance,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      colorValue: colorValue ?? this.colorValue,
      iconCode: iconCode ?? this.iconCode,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      currentBalance: currentBalance ?? this.currentBalance,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        initialBalance,
        currencySymbol,
        colorValue,
        iconCode,
        includeInTotal,
        currentBalance
      ];
}
