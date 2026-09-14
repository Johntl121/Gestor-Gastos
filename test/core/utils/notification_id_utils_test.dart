import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/utils/notification_id_utils.dart';

void main() {
  group('NotificationIdUtils', () {
    test('generateId produces positive 32-bit integer', () {
      final id = NotificationIdUtils.generateId('subscription', '12345');
      expect(id, greaterThanOrEqualTo(0));
      expect(id, lessThanOrEqualTo(0x7FFFFFFF));
    });

    test('generateId is deterministic', () {
      final id1 = NotificationIdUtils.generateId('subscription', 'abc');
      final id2 = NotificationIdUtils.generateId('subscription', 'abc');
      expect(id1, equals(id2));
    });

    test('generateId differs for different ids', () {
      final id1 = NotificationIdUtils.generateId('subscription', 'abc');
      final id2 = NotificationIdUtils.generateId('subscription', 'def');
      expect(id1, isNot(equals(id2)));
    });

    test('generateId differs for different namespaces', () {
      final id1 = NotificationIdUtils.generateId('subscription', 'abc');
      final id2 = NotificationIdUtils.generateId('reminder', 'abc');
      expect(id1, isNot(equals(id2)));
    });
  });
}
