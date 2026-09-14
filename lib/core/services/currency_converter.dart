import '../utils/money_utils.dart';

class CurrencyConverter {
  final Map<String, double> rates;

  CurrencyConverter({required this.rates});

  /// Converts an amount from one currency to another.
  /// Throws an exception if the rate for either currency is not found.
  double convert(double amount, String fromSymbol, String toSymbol) {
    if (fromSymbol == toSymbol) {
      return amount;
    }

    final sourceRate = rates[fromSymbol];
    final targetRate = rates[toSymbol];

    if (sourceRate == null) {
      throw Exception("Rate not found for source currency: $fromSymbol");
    }
    if (targetRate == null) {
      throw Exception("Rate not found for target currency: $toSymbol");
    }

    double result = (amount * sourceRate) / targetRate;
    return MoneyUtils.normalize(result, toSymbol);
  }
}
