class Subscription {
  final String id;
  final String name;
  final double amount;
  final int renewalDay;

  Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.renewalDay,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'renewalDay': renewalDay,
    };
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'],
      name: json['name'],
      amount: json['amount'],
      renewalDay: json['renewalDay'],
    );
  }
}
