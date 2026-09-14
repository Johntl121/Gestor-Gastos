import 'package:intl/intl.dart';
import '../constants/app_currencies.dart';

class CurrencyFormatter {
  /// Retorna un String con la moneda formateada (ej: $ 1,000.00 o -S/ 50.00).
  ///
  /// Ejemplo: format(60.00, 'S/') -> "S/ 60"
  /// Ejemplo: format(60.50, '$') -> "$ 60.50"
  static String format(double amount, String symbol) {
    final currency = AppCurrencies.fromSymbol(symbol);
    final isNegative = amount < 0;
    final absAmount = amount.abs();

    String formatted;
    // Verificar si es entero para ocultar decimales si la moneda tiene decimales
    if (currency.decimals > 0 && absAmount.truncateToDouble() == absAmount) {
      final intFormat = NumberFormat.decimalPattern('en_US');
      formatted = "$symbol ${intFormat.format(absAmount.toInt())}";
    } else {
      final customFormat = NumberFormat.currency(
        locale: 'en_US',
        symbol: '',
        decimalDigits: currency.decimals,
      );
      formatted = "$symbol ${customFormat.format(absAmount)}";
    }

    return isNegative ? "-$formatted" : formatted;
  }

  /// Versión que mantiene el signo si es necesario (para listas de transacciones)
  static String formatWithSign(double amount, String symbol) {
    // Usamos el valor absoluto para evitar doble signo si format() ya incluye el negativo
    final formatted = format(amount.abs(), symbol);
    return amount < 0 ? "-$formatted" : "+$formatted";
  }
}
