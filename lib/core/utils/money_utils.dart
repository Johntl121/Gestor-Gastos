import 'dart:math';
import '../constants/app_currencies.dart';

class MoneyUtils {
  /// Normaliza un monto de acuerdo a los decimales de la moneda (ISO code o símbolo).
  static double normalize(double amount, String currencyCodeOrSymbol) {
    final currency = AppCurrencies.fromCodeOrSymbol(currencyCodeOrSymbol);
    final factor = pow(10, currency.decimals).toDouble();
    return (amount * factor).roundToDouble() / factor;
  }

  /// Compara si dos montos son equivalentes considerando la precisión de su moneda.
  static bool equals(double a, double b, String currencyCodeOrSymbol) {
    final currency = AppCurrencies.fromCodeOrSymbol(currencyCodeOrSymbol);
    final factor = pow(10, currency.decimals).toDouble();
    return (a * factor).round() == (b * factor).round();
  }

  /// Compara si 'a' es mayor o igual a 'b', considerando la precisión de su moneda.
  static bool greaterOrEqual(double a, double b, String currencyCodeOrSymbol) {
    final currency = AppCurrencies.fromCodeOrSymbol(currencyCodeOrSymbol);
    final factor = pow(10, currency.decimals).toDouble();
    return (a * factor).round() >= (b * factor).round();
  }

  /// Compara si 'a' es menor o igual a 'b', considerando la precisión de su moneda.
  static bool lessOrEqual(double a, double b, String currencyCodeOrSymbol) {
    final currency = AppCurrencies.fromCodeOrSymbol(currencyCodeOrSymbol);
    final factor = pow(10, currency.decimals).toDouble();
    return (a * factor).round() <= (b * factor).round();
  }

  /// Formatea el monto agregando los decimales que requiera la moneda, junto al símbolo.
  static String format(double amount, String currencyCodeOrSymbol) {
    final currency = AppCurrencies.fromCodeOrSymbol(currencyCodeOrSymbol);
    final normalized = normalize(amount, currencyCodeOrSymbol);
    return '${currency.symbol} ${normalized.toStringAsFixed(currency.decimals)}';
  }
}
