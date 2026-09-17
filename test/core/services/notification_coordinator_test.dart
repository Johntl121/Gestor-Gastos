import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:gestor_gastos/core/errors/failure.dart';
import 'package:gestor_gastos/core/services/notification_coordinator.dart';
import 'package:gestor_gastos/core/services/notification_service.dart';
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';
import 'package:gestor_gastos/data/datasources/subscription_local_data_source.dart';
import 'package:gestor_gastos/domain/repositories/reminder_repository.dart';
import 'package:gestor_gastos/data/models/subscription.dart';
import 'package:gestor_gastos/domain/entities/reminder.dart';

class MockNotificationService implements NotificationService {
  bool permissionsGranted = true;
  int cancelAllCount = 0;

  List<Map<String, dynamic>> dailyScheduled = [];
  List<Map<String, dynamic>> weeklyScheduled = [];
  List<Map<String, dynamic>> monthlyScheduled = [];
  List<Map<String, dynamic>> absoluteScheduled = [];

  @override
  Future<void> init() async {}

  @override
  void setupTimezone(String timezoneName) {}

  @override
  Future<bool> requestPermissions() async => permissionsGranted;

  @override
  Future<bool> checkPermissions() async => permissionsGranted;

  @override
  Future<void> scheduleRecurringMonthlyFromDate({
    required int id,
    required String title,
    required String body,
    required DateTime startDate,
    required String channelId,
    required String channelName,
  }) async {
    monthlyScheduled.add({'id': id, 'date': startDate});
  }

  @override
  Future<void> scheduleRecurringDaily({
    required int id,
    required String title,
    required String body,
    required DateTime startDate,
    required String channelId,
    required String channelName,
  }) async {
    dailyScheduled.add({'id': id, 'date': startDate});
  }

  @override
  Future<void> scheduleRecurringWeekly({
    required int id,
    required String title,
    required String body,
    required DateTime startDate,
    required String channelId,
    required String channelName,
  }) async {
    weeklyScheduled.add({'id': id, 'date': startDate});
  }

  @override
  Future<void> scheduleAbsoluteNotification({
    required int id,
    required String title,
    required String body,
    required DateTime date,
    required String channelId,
    required String channelName,
  }) async {
    absoluteScheduled.add({'id': id, 'date': date});
  }

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    dailyScheduled.clear();
    weeklyScheduled.clear();
    monthlyScheduled.clear();
    absoluteScheduled.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockPreferences implements PreferencesLocalDataSource {
  int migrationVersion = 1;
  String? lastTz = 'America/New_York';
  bool notificationsEnabled = true;

  @override
  int getSchedulerMigrationVersion() => migrationVersion;

  @override
  Future<void> saveSchedulerMigrationVersion(int version) async {
    migrationVersion = version;
  }

  @override
  String? getLastKnownTimezone() => lastTz;

  @override
  Future<void> saveLastKnownTimezone(String timezone) async {
    lastTz = timezone;
  }

  @override
  bool getEnableNotifications() => notificationsEnabled;

  @override
  Future<void> saveEnableNotifications(bool enable) async {
    notificationsEnabled = enable;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSubscriptionDataSource implements SubscriptionLocalDataSource {
  List<Subscription> subs = [];

  @override
  Future<List<Subscription>> getSubscriptions() async => subs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockReminderRepository implements ReminderRepository {
  List<Reminder> reminders = [];

  @override
  Future<Either<Failure, List<Reminder>>> getAllReminders() async {
    return Right(reminders);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationCoordinator - FASE 8 (Global Pool)', () {
    late NotificationCoordinator coordinator;
    late MockNotificationService mockNotifService;
    late MockPreferences mockPrefs;
    late MockSubscriptionDataSource mockSubSource;
    late MockReminderRepository mockRemRepo;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getLocalTimezone') {
            return 'America/New_York';
          }
          return null;
        },
      );
      mockNotifService = MockNotificationService();
      mockPrefs = MockPreferences();
      mockSubSource = MockSubscriptionDataSource();
      mockRemRepo = MockReminderRepository();

      coordinator = NotificationCoordinator(
        notificationService: mockNotifService,
        preferences: mockPrefs,
        subscriptionDataSource: mockSubSource,
        reminderRepository: mockRemRepo,
      );
    });

    test('global OFF -> ninguno programado', () async {
      mockPrefs.notificationsEnabled = false;
      mockSubSource.subs = [
        Subscription(
            id: '1',
            name: 'S1',
            amount: 10,
            paymentDate: DateTime.now().add(const Duration(days: 1)),
            frequency: ExpenseFrequency.monthly,
            accountToCharge: 1,
            categoryId: 1)
      ];
      mockRemRepo.reminders = [
        Reminder(
            id: 'r1',
            title: 'R1',
            type: ReminderType.general,
            date: DateTime.now().add(const Duration(days: 1)),
            hour: 9,
            minute: 0,
            recurrence: ReminderRecurrence.none,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now())
      ];

      final status = await coordinator.init();
      expect(status, NotificationStatus.notificationsDisabled);
      expect(mockNotifService.absoluteScheduled.isEmpty, true);
      expect(mockNotifService.monthlyScheduled.isEmpty, true);
    });

    test('Reminder one-time futuro -> candidato programado', () async {
      final futureDate = DateTime.now().add(const Duration(days: 2));
      mockRemRepo.reminders = [
        Reminder(
          id: 'fut',
          title: 'Future',
          type: ReminderType.general,
          date: futureDate,
          hour: 9,
          minute: 0,
          recurrence: ReminderRecurrence.none,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      ];

      await coordinator.init();
      expect(mockNotifService.absoluteScheduled.length, 1);
      final scheduled = mockNotifService.absoluteScheduled.first;
      expect((scheduled['date'] as DateTime).year, futureDate.year);
    });

    test('Reminder one-time vencido -> no se programa', () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      mockRemRepo.reminders = [
        Reminder(
          id: 'past',
          title: 'Past',
          type: ReminderType.general,
          date: pastDate,
          hour: 9,
          minute: 0,
          recurrence: ReminderRecurrence.none,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      ];

      await coordinator.init();
      expect(mockNotifService.absoluteScheduled.isEmpty, true);
    });

    test('Reminder completado -> no se programa', () async {
      final futureDate = DateTime.now().add(const Duration(days: 2));
      mockRemRepo.reminders = [
        Reminder(
          id: 'comp',
          title: 'Completed',
          type: ReminderType.general,
          date: futureDate,
          hour: 9,
          minute: 0,
          recurrence: ReminderRecurrence.none,
          active: false,
          completedAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      ];

      await coordinator.init();
      expect(mockNotifService.absoluteScheduled.isEmpty, true);
    });

    test('Reminder inactive -> no se programa', () async {
      final futureDate = DateTime.now().add(const Duration(days: 2));
      mockRemRepo.reminders = [
        Reminder(
          id: 'inact',
          title: 'Inactive',
          type: ReminderType.general,
          date: futureDate,
          hour: 9,
          minute: 0,
          recurrence: ReminderRecurrence.daily,
          active: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      ];

      await coordinator.init();
      expect(mockNotifService.absoluteScheduled.isEmpty, true);
      expect(mockNotifService.dailyScheduled.isEmpty, true);
    });

    test('Reminder daily/weekly/monthly/yearly mapeo correcto', () async {
      final now = DateTime.now();
      mockRemRepo.reminders = [
        Reminder(
            id: 'd1',
            title: 'Daily',
            type: ReminderType.general,
            date: now.add(const Duration(days: 1)),
            hour: 9,
            minute: 0,
            recurrence: ReminderRecurrence.daily,
            createdAt: now,
            updatedAt: now),
        Reminder(
            id: 'w1',
            title: 'Weekly',
            type: ReminderType.general,
            date: now.add(const Duration(days: 1)),
            hour: 9,
            minute: 0,
            recurrence: ReminderRecurrence.weekly,
            createdAt: now,
            updatedAt: now),
        Reminder(
            id: 'm1',
            title: 'Monthly',
            type: ReminderType.general,
            date: DateTime(now.year, now.month, 15),
            hour: 9,
            minute: 0,
            recurrence: ReminderRecurrence.monthly,
            createdAt: now,
            updatedAt: now),
        Reminder(
            id: 'y1',
            title: 'Yearly',
            type: ReminderType.general,
            date: now.add(const Duration(days: 5)),
            hour: 9,
            minute: 0,
            recurrence: ReminderRecurrence.yearly,
            createdAt: now,
            updatedAt: now),
      ];

      await coordinator.init();
      expect(mockNotifService.dailyScheduled.length, 1);
      expect(mockNotifService.weeklyScheduled.length, 1);
      expect(mockNotifService.monthlyScheduled.length, 1);
      expect(mockNotifService.absoluteScheduled.length, 1,
          reason: 'Yearly is absolute');
    });

    test('Reminder mensual día 31 proyecta absolutas', () async {
      final now = DateTime(2023, 1, 15);
      mockRemRepo.reminders = [
        Reminder(
            id: 'm31',
            title: 'Monthly 31',
            type: ReminderType.general,
            date: DateTime(2023, 1, 31),
            hour: 9,
            minute: 0,
            recurrence: ReminderRecurrence.monthly,
            createdAt: now,
            updatedAt: now)
      ];

      await coordinator.init();
      // Genera hasta 50 o menos absolutas
      expect(mockNotifService.absoluteScheduled.isNotEmpty, true);
      expect(mockNotifService.monthlyScheduled.isEmpty, true);
    });

    test('Pool global límite 50 y orden cronológico', () async {
      final now = DateTime.now();

      // Crear 30 suscripciones que vencen en días futuros secuenciales
      mockSubSource.subs = List.generate(30, (i) {
        return Subscription(
            id: 'sub_$i',
            name: 'Sub $i',
            amount: 10,
            paymentDate: now.add(Duration(days: i + 1)),
            frequency: ExpenseFrequency.yearly,
            accountToCharge: 1,
            categoryId: 1);
      });

      // Crear 30 recordatorios que vencen en días futuros secuenciales (+0.5 días para intercalar)
      mockRemRepo.reminders = List.generate(30, (i) {
        return Reminder(
            id: 'rem_$i',
            title: 'Rem $i',
            type: ReminderType.general,
            date: now.add(Duration(days: i + 1, hours: 12)),
            hour: 9,
            minute: 0,
            recurrence: ReminderRecurrence.none,
            createdAt: now,
            updatedAt: now);
      });

      await coordinator.init();

      // El total de candidatos es 60 absolutas (30 subs yearly + 30 rem one-time).
      // El presupuesto máximo es 50.
      expect(mockNotifService.absoluteScheduled.length,
          NotificationCoordinator.maxPendingNotifications);

      // Verificamos que estén ordenados cronológicamente
      final dates = mockNotifService.absoluteScheduled
          .map((e) => e['date'] as DateTime)
          .toList();
      for (int i = 0; i < dates.length - 1; i++) {
        expect(dates[i].compareTo(dates[i + 1]) <= 0, true);
      }
    });

    test('IDs deterministas y colisiones', () async {
      final now = DateTime.now();
      // Mismo ID '1' para Sub y Rem no debe colisionar gracias al namespace
      mockSubSource.subs = [
        Subscription(
          id: '1', name: 'Sub', amount: 10, paymentDate: now.add(const Duration(days: 1)), frequency: ExpenseFrequency.yearly, accountToCharge: 1, categoryId: 1
        )
      ];
      mockRemRepo.reminders = [
        Reminder(
          id: '1', title: 'Rem', type: ReminderType.general, date: now.add(const Duration(days: 1)), hour: 9, minute: 0, recurrence: ReminderRecurrence.none, createdAt: now, updatedAt: now
        )
      ];

      final status = await coordinator.init();
      expect(status, NotificationStatus.scheduled);
      expect(mockNotifService.absoluteScheduled.length, 2);
      final ids = mockNotifService.absoluteScheduled.map((e) => e['id'] as int).toList();
      expect(ids[0] != ids[1], true);
    });

    test('Liberación de un slot: candidato 51 entra al liberar uno', () async {
      final now = DateTime.now();
      
      // 51 records (one-time)
      mockRemRepo.reminders = List.generate(51, (i) {
        return Reminder(
          id: 'rem_$i', title: 'Rem $i', type: ReminderType.general, date: now.add(Duration(days: i + 1)), hour: 9, minute: 0, recurrence: ReminderRecurrence.none, createdAt: now, updatedAt: now
        );
      });

      await coordinator.init();
      expect(mockNotifService.absoluteScheduled.length, 50);
      
      // Encontrar el último programado
      final maxDateScheduled = mockNotifService.absoluteScheduled.map((e) => e['date'] as DateTime).reduce((a, b) => a.isAfter(b) ? a : b);
      
      // Borrar el recordatorio más próximo (día 1)
      mockRemRepo.reminders.removeAt(0);
      
      await coordinator.init();
      expect(mockNotifService.absoluteScheduled.length, 50);
      
      // Ahora el máximo debe ser mayor al anterior, confirmando que entró el 51
      final newMaxDateScheduled = mockNotifService.absoluteScheduled.map((e) => e['date'] as DateTime).reduce((a, b) => a.isAfter(b) ? a : b);
      expect(newMaxDateScheduled.isAfter(maxDateScheduled), true);
    });

    test('29 de febrero: delega en el dominio correctamente', () async {
      final leapYearDate = DateTime(2024, 2, 29); // Bisiesto
      
      mockRemRepo.reminders = [
        Reminder(
          id: 'leap', title: 'Leap', type: ReminderType.general, date: leapYearDate, hour: 9, minute: 0, recurrence: ReminderRecurrence.yearly, createdAt: leapYearDate, updatedAt: leapYearDate
        )
      ];

      // Simulamos que estamos en el año de creación antes de que suene
      final nowInLeapYear = DateTime(2024, 2, 1);
      final result1 = mockRemRepo.reminders[0].getNextOccurrence(nowInLeapYear);
      expect(result1?.year, 2024);
      expect(result1?.month, 2);
      expect(result1?.day, 29); // Primer año suena el 29
      
      // El coordinator usará esto como su próxima ocurrencia
      await coordinator.init(); // Asumiendo que el mock de DateTime.now() no se puede hacer fácilmente, verificamos que el coordinator solo usa rem.getNextOccurrence(). 
      // El test de la lógica pura ya se hizo en domain, solo validamos que el coordinator genere 1 absolute
      expect(mockNotifService.absoluteScheduled.isNotEmpty, true);
    });

    test('Mensual días 29-31: la secuencia de fechas se respeta', () async {
      final now = DateTime.now();
      mockRemRepo.reminders = [
        Reminder(
          id: 'm31_seq', title: 'Monthly 31 Seq', type: ReminderType.general, date: DateTime(2099, 1, 31), hour: 9, minute: 0, recurrence: ReminderRecurrence.monthly, createdAt: now, updatedAt: now
        )
      ];

      await coordinator.init();
      
      final dates = mockNotifService.absoluteScheduled.map((e) => e['date'] as DateTime).toList();
      expect(dates.length, greaterThanOrEqualTo(5));
      
      // La primera fecha dependerá de DateTime.now().
      // Verificaremos que el día de los próximos 5 meses respeta el clamping del final de mes.
      for (int i = 0; i < 5; i++) {
        final d = dates[i];
        final nextMonthFirstDay = DateTime(d.year, d.month + 1, 1);
        final lastDayOfMonth = nextMonthFirstDay.subtract(const Duration(days: 1)).day;
        
        // El día programado debe ser 31, o el último día del mes si el mes tiene menos de 31 días.
        final expectedDay = lastDayOfMonth < 31 ? lastDayOfMonth : 31;
        expect(d.day, expectedDay);
      }
    });
  });
}
