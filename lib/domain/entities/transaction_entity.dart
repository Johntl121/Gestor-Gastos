import 'package:equatable/equatable.dart';

enum TransactionType { expense, income, transfer }

class TransactionEntity extends Equatable {
  final int? id;
  final int accountId;
  final int categoryId;
  final double amount;
  final DateTime date;
  final String? categoryName;
  final String? accountName;
  final String description; // Generalmente Category Name
  final String? note; // User Note
  final TransactionType type;
  final int? destinationAccountId;
  final double? receivedAmount;
  final String? imagePath;
  final int? iconCode;
  final int? colorValue;
  final String? categoryIcon;
  final int? categoryColor;
  final String? subscriptionId;

  const TransactionEntity({
    this.id,
    required this.accountId,
    required this.categoryId,
    required this.amount,
    required this.date,
    required this.description,
    this.categoryName,
    this.accountName,
    this.note,
    this.type = TransactionType.expense, // Default
    this.destinationAccountId,
    this.receivedAmount,
    this.imagePath,
    this.iconCode,
    this.colorValue,
    this.categoryIcon,
    this.categoryColor,
    this.subscriptionId,
  });

  @override
  List<Object?> get props => [
        id,
        accountId,
        categoryId,
        amount,
        date,
        description,
        categoryName,
        accountName,
        note,
        type,
        destinationAccountId,
        receivedAmount,
        imagePath,
        iconCode,
        colorValue,
        categoryIcon,
        categoryColor,
        subscriptionId,
      ];

  TransactionEntity copyWith({
    int? id,
    int? accountId,
    int? categoryId,
    double? amount,
    DateTime? date,
    String? categoryName,
    String? accountName,
    String? description,
    String? note,
    TransactionType? type,
    int? destinationAccountId,
    double? receivedAmount,
    String? imagePath,
    int? iconCode,
    int? colorValue,
    String? categoryIcon,
    int? categoryColor,
    String? subscriptionId,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      categoryName: categoryName ?? this.categoryName,
      accountName: accountName ?? this.accountName,
      note: note ?? this.note,
      type: type ?? this.type,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      imagePath: imagePath ?? this.imagePath,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      subscriptionId: subscriptionId ?? this.subscriptionId,
    );
  }
}
