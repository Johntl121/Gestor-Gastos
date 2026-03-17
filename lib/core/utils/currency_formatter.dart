import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _numberFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: '',
    decimalDigits: 2,
  );

  /// Formatea un monto con el símbolo de moneda al inicio y espacio.
  /// Ejemplo: format(60.00, 'S/') -> "S/ 60"
  /// Ejemplo: format(60.50, '$') -> "$ 60.50"
  static String format(double amount, String symbol) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    
    String formatted;
    // Verificar si es entero para ocultar decimales
    if (absAmount.truncateToDouble() == absAmount) {
      final intFormat = NumberFormat.decimalPattern('en_US');
      formatted = "$symbol ${intFormat.format(absAmount.toInt())}";
    } else {
      formatted = "$symbol ${_numberFormat.format(absAmount)}";
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
