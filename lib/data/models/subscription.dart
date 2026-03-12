enum ExpenseFrequency { monthly, yearly }

class Subscription {
  final String id;
  final String name;
  final double amount;
  final DateTime paymentDate;
  final ExpenseFrequency frequency;
  final bool isPaid;
  final int iconCode;
  final int colorValue;
  final int accountToCharge; // 1: Cash, 2: Bank, 3: Savings

  Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.paymentDate,
    required this.frequency,
    this.isPaid = false,
    this.iconCode = 0xe57f, // Icons.subscriptions default
    this.colorValue = 0xFF9E9E9E, // Colors.grey default
    this.accountToCharge = 2, // Default to Bank
  });

  // Getter inteligente: nextDueDate
  DateTime get nextDueDate {
    final now = DateTime.now();

    if (frequency == ExpenseFrequency.monthly) {
      // Caso Mensual
      final paymentDay = paymentDate.day;

      if (isPaid) {
        // Si ya se pagó este mes, el próximo vencimiento es el mes siguiente
        return DateTime(now.year, now.month + 1, paymentDay);
      } else {
        // Si NO se ha pagado, el vencimiento es en ESTE mes (puede estar vencido o estar por vencer)
        return DateTime(now.year, now.month, paymentDay);
      }
    } else {
      // Caso Anual
      if (isPaid) {
        return DateTime(now.year + 1, paymentDate.month, paymentDate.day);
      } else {
        return DateTime(now.year, paymentDate.month, paymentDate.day);
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'paymentDate': paymentDate.toIso8601String(),
      'frequency': frequency.index, // Store as int index
      'isPaid': isPaid,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'accountToCharge': accountToCharge,
    };
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'],
      name: json['name'],
      amount: json['amount'],
      paymentDate: DateTime.parse(json['paymentDate']),
      frequency: ExpenseFrequency.values[json['frequency'] ?? 0],
      isPaid: json['isPaid'] ??
          false, // Mapped from old isPaidThisMonth key if needed? No, purely new.
      iconCode: json['iconCode'] ?? 0xe57f,
      colorValue: json['colorValue'] ?? 0xFF9E9E9E,
      accountToCharge: json['accountToCharge'] ?? 2,
    );
  }

  Subscription copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? paymentDate,
    ExpenseFrequency? frequency,
    bool? isPaid,
    int? iconCode,
    int? colorValue,
    int? accountToCharge,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      frequency: frequency ?? this.frequency,
      isPaid: isPaid ?? this.isPaid,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      accountToCharge: accountToCharge ?? this.accountToCharge,
    );
  }
}
