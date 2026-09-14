import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/constants/app_currencies.dart';
import 'package:gestor_gastos/core/services/currency_converter.dart';

void main() {
  group('AppCurrencies', () {
    test('todas las monedas soportadas tienen tasa default', () {
      expect(AppCurrencies.all.length, 8);
      for (var currency in AppCurrencies.all) {
        expect(currency.defaultRate, isPositive);
        expect(currency.decimals, isNotNull);
        expect(currency.symbol, isNotEmpty);
      }
    });

    test('fromSymbol fallback to PEN for unknown', () {
      final unknown = AppCurrencies.fromSymbol('UNKNOWN');
      expect(unknown.code, 'PEN');
    });
  });

  group('CurrencyConverter', () {
    final rates = {
      'S/': 1.0,
      '\$': 3.75,
      '€': 4.0,
    };
    final converter = CurrencyConverter(rates: rates);

    test('misma moneda no cambia monto', () {
      expect(converter.convert(100, 'S/', 'S/'), 100);
      expect(converter.convert(50, '\$', '\$'), 50);
    });

    test('PEN -> USD', () {
      // 100 PEN * (1.0 / 3.75)
      expect(converter.convert(100, 'S/', '\$'), closeTo(26.67, 0.01));
    });

    test('USD -> PEN', () {
      // 100 USD * (3.75 / 1.0)
      expect(converter.convert(100, '\$', 'S/'), closeTo(375.0, 0.01));
    });

    test('USD -> EUR', () {
      // 100 USD * (3.75 / 4.0)
      expect(converter.convert(100, '\$', '€'), closeTo(93.75, 0.01));
    });

    test('moneda/tasa inexistente -> error', () {
      expect(() => converter.convert(100, 'UNKNOWN', 'S/'), throwsException);
      expect(() => converter.convert(100, 'S/', 'UNKNOWN'), throwsException);
    });
  });
}
