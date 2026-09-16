import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/domain/entities/reminder.dart';

void main() {
  group('Reminder Entity - Invariantes y Validaciones', () {
    test('amount > 0 y currencyCode obligatorio', () {
      expect(
        () => Reminder(
          id: '1',
          title: 'Test',
          type: ReminderType.payment,
          amount: 50.0,
          currencyCode: null, // Error
          date: DateTime(2023, 1, 1),
          hour: 9,
          minute: 0,
          recurrence: ReminderRecurrence.none,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => Reminder(
          id: '1',
          title: 'Test',
          type: ReminderType.payment,
          amount: -10.0,
          currencyCode: 'PEN', // Error, amount < 0
          date: DateTime(2023, 1, 1),
          hour: 9,
          minute: 0,
          recurrence: ReminderRecurrence.none,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('sin amount no debe haber currencyCode', () {
      expect(
        () => Reminder(
          id: '1',
          title: 'Test',
          type: ReminderType.general,
          amount: null,
          currencyCode: 'PEN', // Error
          date: DateTime(2023, 1, 1),
          hour: 9,
          minute: 0,
          recurrence: ReminderRecurrence.none,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('completedAt solo permitido para recurrence = none e inactivo', () {
      final now = DateTime.now();

      expect(
        () => Reminder(
          id: '1',
          title: 'Test',
          type: ReminderType.general,
          date: DateTime(2023, 1, 1),
          hour: 9,
          minute: 0,
          recurrence: ReminderRecurrence.monthly,
          completedAt: now, // Error
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => Reminder(
          id: '1',
          title: 'Test',
          type: ReminderType.general,
          date: DateTime(2023, 1, 1),
          hour: 9,
          minute: 0,
          recurrence: ReminderRecurrence.none,
          active: true, // Error, debe ser inactivo
          completedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Reminder Entity - Cálculos (One-time)', () {
    test('One-time futuro (upcoming)', () {
      final now = DateTime(2023, 5, 15, 10, 0); // May 15, 10:00
      final reminder = Reminder(
        id: '1',
        title: 'Future',
        type: ReminderType.general,
        date: DateTime(2023, 5, 15),
        hour: 18,
        minute: 0,
        recurrence: ReminderRecurrence.none,
        createdAt: now,
        updatedAt: now,
      );

      expect(reminder.getNextOccurrence(now), DateTime(2023, 5, 15, 18, 0));
      expect(reminder.getStatus(now), ReminderStatus.upcoming);
    });

    test('One-time pasado (overdue)', () {
      final now = DateTime(2023, 5, 15, 20, 0); // May 15, 20:00
      final reminder = Reminder(
        id: '1',
        title: 'Past',
        type: ReminderType.general,
        date: DateTime(2023, 5, 15),
        hour: 18,
        minute: 0,
        recurrence: ReminderRecurrence.none,
        createdAt: now,
        updatedAt: now,
      );

      expect(reminder.getNextOccurrence(now), DateTime(2023, 5, 15, 18, 0));
      expect(reminder.getStatus(now), ReminderStatus.overdue);
    });

    test('One-time completado (completed)', () {
      final now = DateTime(2023, 5, 15, 20, 0);
      final reminder = Reminder(
        id: '1',
        title: 'Completed',
        type: ReminderType.general,
        date: DateTime(2023, 5, 15),
        hour: 18,
        minute: 0,
        recurrence: ReminderRecurrence.none,
        active: false,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(reminder.getNextOccurrence(now), isNull);
      expect(reminder.getStatus(now), ReminderStatus.completed);
    });
  });

  group('Reminder Entity - Cálculos (Recurring)', () {
    test('Diario (pasado)', () {
      final original = DateTime(2023, 5, 10);
      final now = DateTime(2023, 5, 15, 20, 0); // May 15, 20:00
      final reminder = Reminder(
        id: '1',
        title: 'Daily',
        type: ReminderType.general,
        date: original,
        hour: 18,
        minute: 0,
        recurrence: ReminderRecurrence.daily,
        createdAt: original,
        updatedAt: original,
      );

      // Como ya pasó las 18:00 del May 15, el siguiente debe ser May 16, 18:00
      expect(reminder.getNextOccurrence(now), DateTime(2023, 5, 16, 18, 0));
      expect(reminder.getStatus(now), ReminderStatus.upcoming);
    });

    test('Semanal (pasado)', () {
      final original = DateTime(2023, 5, 10); // Miércoles
      final now = DateTime(2023, 5, 15, 20, 0); // Lunes
      final reminder = Reminder(
        id: '1',
        title: 'Weekly',
        type: ReminderType.general,
        date: original,
        hour: 18,
        minute: 0,
        recurrence: ReminderRecurrence.weekly,
        createdAt: original,
        updatedAt: original,
      );

      // Siguiente Miércoles es May 17
      expect(reminder.getNextOccurrence(now), DateTime(2023, 5, 17, 18, 0));
    });

    test('Mensual día 31 (enero, feb, mar, abr)', () {
      final original = DateTime(2023, 1, 31);
      final reminder = Reminder(
        id: '1',
        title: 'Monthly 31',
        type: ReminderType.payment,
        amount: 10,
        currencyCode: 'USD',
        date: original,
        hour: 9,
        minute: 0,
        recurrence: ReminderRecurrence.monthly,
        createdAt: original,
        updatedAt: original,
      );

      // Estamos a mitad de enero (todavía falta enero 31)
      var now = DateTime(2023, 1, 15, 10, 0);
      expect(reminder.getNextOccurrence(now), DateTime(2023, 1, 31, 9, 0));

      // Pasó enero 31, estamos en febrero 15. Debería ser febrero 28.
      now = DateTime(2023, 2, 15, 10, 0);
      expect(reminder.getNextOccurrence(now), DateTime(2023, 2, 28, 9, 0));

      // Pasó febrero, estamos en marzo 15. Debería ser marzo 31.
      now = DateTime(2023, 3, 15, 10, 0);
      expect(reminder.getNextOccurrence(now), DateTime(2023, 3, 31, 9, 0));

      // Pasó marzo, estamos en abril 15. Debería ser abril 30.
      now = DateTime(2023, 4, 15, 10, 0);
      expect(reminder.getNextOccurrence(now), DateTime(2023, 4, 30, 9, 0));
    });

    test('Mensual bisiesto febrero 29', () {
      final original = DateTime(2024, 1, 31);
      final reminder = Reminder(
        id: '1',
        title: 'Monthly leap year',
        type: ReminderType.general,
        date: original,
        hour: 9,
        minute: 0,
        recurrence: ReminderRecurrence.monthly,
        createdAt: original,
        updatedAt: original,
      );

      // En 2024 febrero tiene 29 días
      var now = DateTime(2024, 2, 15, 10, 0);
      expect(reminder.getNextOccurrence(now), DateTime(2024, 2, 29, 9, 0));
    });

    test('Anual febrero 29 (año bisiesto) en año común', () {
      final original = DateTime(2024, 2, 29); // Bisiesto
      final reminder = Reminder(
        id: '1',
        title: 'Yearly Leap',
        type: ReminderType.general,
        date: original,
        hour: 9,
        minute: 0,
        recurrence: ReminderRecurrence.yearly,
        createdAt: original,
        updatedAt: original,
      );

      // Para el año 2025 (común), debería ajustarse al 28 de febrero
      var now = DateTime(2025, 1, 15, 10, 0);
      expect(reminder.getNextOccurrence(now), DateTime(2025, 2, 28, 9, 0));

      // Para el año 2028 (bisiesto), debería recuperar el 29
      now = DateTime(2028, 1, 15, 10, 0);
      expect(reminder.getNextOccurrence(now), DateTime(2028, 2, 29, 9, 0));
    });

    test('Recurrente inactivo', () {
      final original = DateTime(2023, 5, 10);
      final now = DateTime(2023, 5, 15, 20, 0);
      final reminder = Reminder(
        id: '1',
        title: 'Inactive Daily',
        type: ReminderType.general,
        date: original,
        hour: 18,
        minute: 0,
        recurrence: ReminderRecurrence.daily,
        active: false,
        createdAt: original,
        updatedAt: original,
      );

      // Su ocurrencia sigue calculándose si hiciera falta
      expect(reminder.getNextOccurrence(now), DateTime(2023, 5, 16, 18, 0));
      // Pero su estatus es inactivo
      expect(reminder.getStatus(now), ReminderStatus.inactive);
    });
  });
}
