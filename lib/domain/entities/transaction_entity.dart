import 'package:equatable/equatable.dart';

enum TransactionType { expense, income, transfer }

class TransactionEntity extends Equatable {
  final int? id;
  final int accountId;
  final int categoryId;
  final double amount;
  final DateTime date;
  final String description; // Category Name
  final String? note; // User Note
  final TransactionType type;
  final int? destinationAccountId;
  final double? receivedAmount;
  final String? imagePath;

  const TransactionEntity({
    this.id,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.date,
    required this.description,
    this.note,
    this.type = TransactionType.expense, // Default
    this.destinationAccountId,
    this.receivedAmount,
    this.imagePath,
  });

  @override
  List<Object?> get props => [
        id,
        accountId,
        categoryId,
        amount,
        date,
        description,
        note,
        type,
        destinationAccountId,
        receivedAmount,
        imagePath
      ];
}
