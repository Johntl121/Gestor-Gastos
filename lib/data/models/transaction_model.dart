import '../../domain/entities/transaction_entity.dart';

class TransactionModel extends TransactionEntity {
  const TransactionModel({
    super.id,
    required super.accountId,
    required super.categoryId,
    required super.amount,
    required super.date,
    required super.description,
    super.note,
    super.type,
    super.destinationAccountId,
    super.receivedAmount,
    super.imagePath,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    String description = json['description'] ?? '';
    TransactionType type = _parseType(json['type']);

    // Legacy Fix: Force Transfer type if description contains "Transferencia", regardless of current type
    // This allows fixing past transactions that were saved as Expense OR Income.
    if (type != TransactionType.transfer &&
        description.toLowerCase().contains('transferencia')) {
      type = TransactionType.transfer;
    }

    return TransactionModel(
      id: json['id'],
      accountId: json['accountId'],
      categoryId: json['categoryId'],
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      description: description,
      note: json['note'],
      type: type,
      destinationAccountId: json['destinationAccountId'],
      receivedAmount: json['receivedAmount'] != null
          ? (json['receivedAmount'] as num).toDouble()
          : null,
      imagePath: json['imagePath'],
    );
  }

  static TransactionType _parseType(String? typeStr) {
    if (typeStr == 'TRANSFER') return TransactionType.transfer;
    if (typeStr == 'INCOME') return TransactionType.income;
    return TransactionType.expense;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'categoryId': categoryId,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'note': note,
      'type': type.name.toUpperCase(),
      'destinationAccountId': destinationAccountId,
      'receivedAmount': receivedAmount,
      'imagePath': imagePath,
    };
  }

  factory TransactionModel.fromEntity(TransactionEntity entity) {
    return TransactionModel(
      id: entity.id,
      accountId: entity.accountId,
      categoryId: entity.categoryId,
      amount: entity.amount,
      date: entity.date,
      description: entity.description,
      note: entity.note,
      type: entity.type,
      destinationAccountId: entity.destinationAccountId,
      receivedAmount: entity.receivedAmount,
      imagePath: entity.imagePath,
    );
  }
}
