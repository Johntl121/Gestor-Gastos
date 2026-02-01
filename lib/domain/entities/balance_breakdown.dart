import 'package:equatable/equatable.dart';

class BalanceBreakdown extends Equatable {
  final double total;
  final double cash;
  final double digital;

  const BalanceBreakdown({
    required this.total,
    required this.cash,
    required this.digital,
  });

  @override
  List<Object?> get props => [total, cash, digital];
}
