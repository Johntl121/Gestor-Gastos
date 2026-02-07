class Subscription {
  final String id;
  final String name;
  final double amount;
  final int renewalDay;
  final bool isPaidThisMonth;
  final int iconCode;
  final int colorValue;
  final int accountToCharge; // 1: Cash, 2: Bank, 3: Savings

  Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.renewalDay,
    this.isPaidThisMonth = false,
    this.iconCode = 0xe57f, // Icons.subscriptions default
    this.colorValue = 0xFF9E9E9E, // Colors.grey default
    this.accountToCharge = 2, // Default to Bank
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'renewalDay': renewalDay,
      'isPaidThisMonth': isPaidThisMonth,
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
      renewalDay: json['renewalDay'],
      isPaidThisMonth: json['isPaidThisMonth'] ?? false,
      iconCode: json['iconCode'] ?? 0xe57f,
      colorValue: json['colorValue'] ?? 0xFF9E9E9E,
      accountToCharge: json['accountToCharge'] ?? 2,
    );
  }

  Subscription copyWith({
    String? id,
    String? name,
    double? amount,
    int? renewalDay,
    bool? isPaidThisMonth,
    int? iconCode,
    int? colorValue,
    int? accountToCharge,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      renewalDay: renewalDay ?? this.renewalDay,
      isPaidThisMonth: isPaidThisMonth ?? this.isPaidThisMonth,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      accountToCharge: accountToCharge ?? this.accountToCharge,
    );
  }
}
