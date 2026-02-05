import 'package:equatable/equatable.dart';

class BalanceBreakdown extends Equatable {
  final double total;
  final double cash;
  final double digital;
  final double savings; // Separate tracking for Savings Account

  const BalanceBreakdown({
    required this.total,
    required this.cash,
    required this.digital,
    this.savings = 0.0,
  });

  @override
  List<Object?> get props => [total, cash, digital, savings];
}
