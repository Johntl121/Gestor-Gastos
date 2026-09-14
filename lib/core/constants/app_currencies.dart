class AppCurrency {
  final String code;
  final String symbol;
  final String name;
  final int decimals;
  final double defaultRate; // Rate: How many PEN equals 1 unit of this currency

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.defaultRate,
  });
}

class AppCurrencies {
  static const List<AppCurrency> all = [
    AppCurrency(
        code: 'PEN', symbol: 'S/', name: 'Sol', decimals: 2, defaultRate: 1.0),
    AppCurrency(
        code: 'USD',
        symbol: '\$',
        name: 'Dólar',
        decimals: 2,
        defaultRate: 3.75),
    AppCurrency(
        code: 'EUR', symbol: '€', name: 'Euro', decimals: 2, defaultRate: 4.10),
    AppCurrency(
        code: 'MXN',
        symbol: 'mx\$',
        name: 'Peso',
        decimals: 2,
        defaultRate: 0.188),
    AppCurrency(
        code: 'RUB',
        symbol: '₽',
        name: 'Rublo',
        decimals: 2,
        defaultRate: 0.040),
    AppCurrency(
        code: 'GBP',
        symbol: '£',
        name: 'Libra',
        decimals: 2,
        defaultRate: 4.76),
    AppCurrency(
        code: 'JPY', symbol: '¥', name: 'Yen', decimals: 0, defaultRate: 0.025),
    AppCurrency(
        code: 'BRL',
        symbol: 'R\$',
        name: 'Real',
        decimals: 2,
        defaultRate: 0.74),
  ];

  static AppCurrency fromSymbol(String symbol) {
    return all.firstWhere(
      (c) => c.symbol == symbol,
      orElse: () => all
          .first, // Fallback to PEN if unknown, though shouldn't happen for known ones
    );
  }

  static double defaultRateFor(String symbol) {
    return fromSymbol(symbol).defaultRate;
  }
}
