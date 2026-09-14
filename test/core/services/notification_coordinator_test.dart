import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/services/notification_coordinator.dart';
import 'package:gestor_gastos/core/services/notification_service.dart';
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';
import 'package:gestor_gastos/data/datasources/subscription_local_data_source.dart';
import 'package:gestor_gastos/data/models/subscription.dart';

class MockNotificationService implements NotificationService {
  bool permissionsGranted = true;
  int cancelAllCount = 0;
  List<int> cancelledIds = [];
  List<Map<String, dynamic>> monthlyScheduled = [];
  List<Map<String, dynamic>> yearlyScheduled = [];
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
  Future<void> scheduleRecurringMonthly({
    required int id,
    required String title,
    required String body,
    required int dayOfMonth,
    required TimeOfDay time,
    required String channelId,
    required String channelName,
  }) async {
    monthlyScheduled.add({'id': id, 'day': dayOfMonth});
  }

  @override
  Future<void> scheduleRecurringYearly({
    required int id,
    required String title,
    required String body,
    required int month,
    required int day,
    required TimeOfDay time,
    required String channelId,
    required String channelName,
  }) async {
    yearlyScheduled.add({'id': id, 'month': month, 'day': day});
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
  Future<void> cancelNotification(int id) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
  }

  @override
  get flutterLocalNotificationsPlugin => throw UnimplementedError();
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

void main() {
  group('NotificationCoordinator', () {
    late NotificationCoordinator coordinator;
    late MockNotificationService mockNotifService;
    late MockPreferences mockPrefs;
    late MockSubscriptionDataSource mockSubSource;

    setUp(() {
      mockNotifService = MockNotificationService();
      mockPrefs = MockPreferences();
      mockSubSource = MockSubscriptionDataSource();

      coordinator = NotificationCoordinator(
        notificationService: mockNotifService,
        preferences: mockPrefs,
        subscriptionDataSource: mockSubSource,
      );
    });

    // Note: init() depends on FlutterTimezone plugin which requires a native environment.
    // For unit testing without native platform, we'll test the core scheduling logic.

    test('enableNotifications sets preference and reschedules', () async {
      mockSubSource.subs = [
        Subscription(
          id: 'sub1',
          name: 'Netflix',
          amount: 15.0,
          paymentDate: DateTime(2023, 1, 15),
          frequency: ExpenseFrequency.monthly,
          accountToCharge: 1,
          categoryId: 1,
        )
      ];

      final status = await coordinator.enableNotifications();

      expect(status, NotificationStatus.scheduled);
      expect(mockPrefs.notificationsEnabled, true);
      expect(mockNotifService.cancelAllCount, 1); // 1 from _rescheduleAllActive
      expect(mockNotifService.monthlyScheduled.length, 1);
      expect(mockNotifService.monthlyScheduled.first['day'], 15);
    });

    test('enableNotifications when permissions denied reverts state', () async {
      mockNotifService.permissionsGranted = false;
      final status = await coordinator.enableNotifications();

      expect(status, NotificationStatus.permissionDenied);
      expect(mockPrefs.notificationsEnabled, false);
      expect(mockNotifService.monthlyScheduled.isEmpty, true);
    });

    test('disableNotifications cancels all and sets preference', () async {
      final status = await coordinator.disableNotifications();

      expect(status, NotificationStatus.notificationsDisabled);
      expect(mockPrefs.notificationsEnabled, false);
      expect(mockNotifService.cancelAllCount, 1);
    });

    test('Días 29-31 schedule up to 40 occurrences', () async {
      mockSubSource.subs = [
        Subscription(
          id: 'sub31',
          name: 'Gym',
          amount: 50.0,
          paymentDate: DateTime(2023, 1, 31),
          frequency: ExpenseFrequency.monthly,
          accountToCharge: 1,
          categoryId: 1,
        )
      ];

      final status = await coordinator.enableNotifications();

      expect(status, NotificationStatus.scheduled);
      expect(mockNotifService.absoluteScheduled.length, 40);

      // Verify clamping for February (month 2)
      // Since it's dynamic based on DateTime.now(), we just check some occurrences
      bool hasFeb28or29 = mockNotifService.absoluteScheduled.any((occ) {
        final date = occ['date'] as DateTime;
        return date.month == 2 && (date.day == 28 || date.day == 29);
      });
      expect(hasFeb28or29, true);
    });
  });
}
