import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/utils/money_utils.dart';

void main() {
  group('MoneyUtils Normalization', () {
    test('PEN con 2 decimales', () {
      expect(MoneyUtils.normalize(100.123, 'PEN'), 100.12);
      expect(MoneyUtils.normalize(100.125, 'PEN'), 100.13);
    });

    test('USD con 2 decimales', () {
      expect(MoneyUtils.normalize(50.999, 'USD'), 51.00);
      expect(MoneyUtils.normalize(50.001, 'USD'), 50.00);
    });

    test('JPY con 0 decimales', () {
      expect(MoneyUtils.normalize(100.123, 'JPY'), 100.0);
      expect(MoneyUtils.normalize(100.5, 'JPY'), 101.0);
    });

    test('0.1 + 0.2 normalizado en PEN/USD', () {
      double result = 0.1 + 0.2; // Normalmente 0.30000000000000004
      expect(MoneyUtils.normalize(result, 'PEN'), 0.30);
      expect(MoneyUtils.normalize(result, 'USD'), 0.30);
    });

    test('Agregado de multiples valores se normaliza al final', () {
      List<double> values = [0.1, 0.2, 0.3, 0.4];
      double sum = 0;
      for (var v in values) {
        sum += v;
      }
      expect(MoneyUtils.normalize(sum, 'PEN'), 1.00);
    });
  });

  group('MoneyUtils Comparisons', () {
    test('Comparación 99.9999 vs 100.00 en una moneda de 2 decimales', () {
      expect(MoneyUtils.equals(99.9999, 100.00, 'PEN'), true);
      expect(MoneyUtils.greaterOrEqual(99.9999, 100.00, 'USD'), true);
      expect(MoneyUtils.lessOrEqual(100.00, 99.9999, 'EUR'), true);
    });

    test('Comparaciones estrictas con diferencias reales', () {
      expect(MoneyUtils.equals(99.98, 100.00, 'PEN'), false);
      expect(MoneyUtils.greaterOrEqual(99.98, 100.00, 'PEN'), false);
    });
  });

  group('MoneyUtils Formatting', () {
    test('Respeta los simbolos y decimales al formatear', () {
      expect(MoneyUtils.format(100.5, 'PEN'), 'S/ 100.50');
      expect(MoneyUtils.format(100.5, 'USD'), '\$ 100.50');
      expect(MoneyUtils.format(100.5, 'JPY'), '¥ 101');
    });
  });
}
