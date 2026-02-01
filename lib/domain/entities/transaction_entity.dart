import 'package:equatable/equatable.dart';

class TransactionEntity extends Equatable {
  final int? id;
  final int accountId;
  final int categoryId;
  final double amount;
  final DateTime date;
  final String description;

  const TransactionEntity({
    this.id,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.date,
    required this.description,
  });

  @override
  List<Object?> get props => [id, accountId, categoryId, amount, date, description];
}
