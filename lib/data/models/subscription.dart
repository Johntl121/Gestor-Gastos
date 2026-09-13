import 'dart:math' as math;
import '../../core/constants/app_constants.dart';

enum ExpenseFrequency { monthly, yearly }

class Subscription {
  final String id;
  final String name;
  final double amount;
  final DateTime paymentDate;
  final ExpenseFrequency frequency;
  final bool isPaid;
  final String? customIcon;
  final int? customColor;
  final int accountToCharge; // 1: Cash, 2: Bank, 3: Savings
  final int categoryId;
  final int orderIndex;

  Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.paymentDate,
    required this.frequency,
    this.isPaid = false,
    this.customIcon,
    this.customColor,
    this.accountToCharge = 2, // Default to Bank
    this.categoryId =
        AppConstants.otherExpenseId, // Default to Suscripciones / Otros Gastos
    this.orderIndex = 0,
  });

  // Getter inteligente: nextDueDate
  DateTime get nextDueDate {
    final now = DateTime.now();

    if (frequency == ExpenseFrequency.monthly) {
      // Caso Mensual
      final paymentDay = paymentDate.day;

      if (isPaid) {
        // Si ya se pagó este mes, el próximo vencimiento es el mes siguiente
        int diasDelProximoMes = DateTime(now.year, now.month + 2, 0).day;
        int diaDeCobroProximo = math.min(paymentDay, diasDelProximoMes);
        return DateTime(now.year, now.month + 1, diaDeCobroProximo);
      } else {
        // Si NO se ha pagado, el vencimiento es en ESTE mes (puede estar vencido o estar por vencer)
        int diasDelMesActual = DateTime(now.year, now.month + 1, 0).day;
        int diaDeCobroReal = math.min(paymentDay, diasDelMesActual);
        return DateTime(now.year, now.month, diaDeCobroReal);
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
      'isPaid': isPaid ? 1 : 0,
      'custom_icon': customIcon,
      'custom_color': customColor,
      'accountToCharge': accountToCharge,
      'categoryId': categoryId,
      'orderIndex': orderIndex,
    };
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'],
      name: json['name'],
      amount: (json['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(json['paymentDate']),
      frequency: ExpenseFrequency.values[json['frequency'] ?? 0],
      isPaid: json['isPaid'] == 1 || json['isPaid'] == true,
      customIcon: json['custom_icon'],
      customColor: json['custom_color'],
      accountToCharge: json['accountToCharge'] ?? 2,
      categoryId: json['categoryId'] ?? AppConstants.otherExpenseId,
      orderIndex: json['orderIndex'] ?? 0,
    );
  }

  Subscription copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? paymentDate,
    ExpenseFrequency? frequency,
    bool? isPaid,
    String? customIcon,
    int? customColor,
    int? accountToCharge,
    int? categoryId,
    int? orderIndex,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      frequency: frequency ?? this.frequency,
      isPaid: isPaid ?? this.isPaid,
      customIcon: customIcon ?? this.customIcon,
      customColor: customColor ?? this.customColor,
      accountToCharge: accountToCharge ?? this.accountToCharge,
      categoryId: categoryId ?? this.categoryId,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}
