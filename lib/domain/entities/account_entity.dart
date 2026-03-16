import 'package:flutter/material.dart';
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

  /// Determines if this is a Cash account or Digital
  final bool isCash;

  // Calculated at runtime, not stored
  final double currentBalance;

  // Helper for dynamic UI icons
  IconData get displayIcon {
    if (name.toLowerCase() == 'efectivo' &&
        (iconCode == Icons.money.codePoint ||
            iconCode == Icons.wallet_rounded.codePoint ||
            iconCode == Icons.account_balance_wallet.codePoint)) {
      return Icons.payments_rounded; // Specific icon for Efectivo
    }
    return IconData(iconCode, fontFamily: 'MaterialIcons');
  }

  const AccountEntity({
    required this.id,
    required this.name,
    required this.initialBalance,
    required this.currencySymbol,
    required this.colorValue,
    required this.iconCode,
    this.includeInTotal = true,
    this.isCash = false,
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
    bool? isCash,
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
      isCash: isCash ?? this.isCash,
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
        isCash,
        currentBalance
      ];
}
