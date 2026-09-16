import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    bool skipCurrentMonth = false,
  }) async {
    monthlyScheduled.add(
        {'id': id, 'day': dayOfMonth, 'skipCurrentMonth': skipCurrentMonth});
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationCoordinator', () {
    late NotificationCoordinator coordinator;
    late MockNotificationService mockNotifService;
    late MockPreferences mockPrefs;
    late MockSubscriptionDataSource mockSubSource;

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

      // Extract generated months to verify sequence
      final months = mockNotifService.absoluteScheduled.map((e) {
        final d = e['date'] as DateTime;
        return d.month;
      }).toList();

      // Verify sequence: Jan, Feb, Mar, Apr, May (assuming run anytime, it projects next 40 months)
      // At least verify we get 5 consecutive months 1, 2, 3, 4, 5
      expect(months.toSet().containsAll([1, 2, 3, 4, 5]), true);

      // Verify that Feb is mapped to 28 or 29
      final febDate = mockNotifService.absoluteScheduled
              .firstWhere((occ) => (occ['date'] as DateTime).month == 2)['date']
          as DateTime;
      expect(febDate.day == 28 || febDate.day == 29, true);

      // Verify that March restores to 31
      final marDate = mockNotifService.absoluteScheduled
              .firstWhere((occ) => (occ['date'] as DateTime).month == 3)['date']
          as DateTime;
      expect(marDate.day, 31);

      // Verify that April adjusts to 30
      final aprDate = mockNotifService.absoluteScheduled
              .firstWhere((occ) => (occ['date'] as DateTime).month == 4)['date']
          as DateTime;
      expect(aprDate.day, 30);
    });

    test('init runs migration exactly once', () async {
      mockPrefs.migrationVersion = 0; // Trigger migration

      final status1 = await coordinator.init();
      expect(status1, NotificationStatus.scheduled);
      // cancelAll is called twice: once for migration, once inside _rescheduleAllActive
      expect(mockNotifService.cancelAllCount, 2);
      expect(mockPrefs.migrationVersion, 1);

      // Second init
      final status2 = await coordinator.init();
      expect(status2, NotificationStatus.scheduled);
      // Only called once by _rescheduleAllActive this time
      expect(mockNotifService.cancelAllCount, 3);
    });

    test('markSubscriptionAsPaid reconcile scheduling (skip current month)',
        () async {
      final sub = Subscription(
        id: 'sub-skip',
        name: 'Netflix',
        amount: 15.0,
        paymentDate: DateTime(2023, 1, 15),
        frequency: ExpenseFrequency.monthly,
        accountToCharge: 1,
        categoryId: 1,
        isPaid: false,
      );

      mockSubSource.subs = [sub];
      await coordinator.enableNotifications();

      expect(mockNotifService.monthlyScheduled.length, 1);
      expect(
          mockNotifService.monthlyScheduled.first['skipCurrentMonth'], false);

      // Mark as paid
      mockNotifService.monthlyScheduled.clear();
      mockSubSource.subs = [sub.copyWith(isPaid: true)];
      await coordinator.scheduleSubscription(sub.copyWith(isPaid: true));

      expect(mockNotifService.monthlyScheduled.length, 1);
      expect(mockNotifService.monthlyScheduled.first['skipCurrentMonth'], true);
    });

    test('init with collision does not complete migration', () async {
      mockPrefs.migrationVersion = 0; // Trigger migration
      
      // Setup collision by providing two subscriptions with the exact same ID
      mockSubSource.subs = [
         Subscription(
          id: 'col1',
          name: 'Gym',
          amount: 50.0,
          paymentDate: DateTime(2023, 1, 15),
          frequency: ExpenseFrequency.monthly,
          accountToCharge: 1,
          categoryId: 1,
        ),
         Subscription(
          id: 'col1', // Same ID -> collision
          name: 'Gym',
          amount: 50.0,
          paymentDate: DateTime(2023, 1, 15),
          frequency: ExpenseFrequency.monthly,
          accountToCharge: 1,
          categoryId: 1,
        ),
      ];
      
      final status = await coordinator.init();
      expect(status, NotificationStatus.collisionError);
      
      // Verify migration was NOT saved
      expect(mockPrefs.migrationVersion, 0);
    });

    test('markSubscriptionAsPaid for days 29-31 skips current month', () async {
       final sub = Subscription(
          id: 'sub31-paid',
          name: 'Netflix',
          amount: 15.0,
          paymentDate: DateTime(2023, 1, 31),
          frequency: ExpenseFrequency.monthly,
          accountToCharge: 1,
          categoryId: 1,
          isPaid: false, // Not paid yet
        );
        
        mockSubSource.subs = [sub];
        await coordinator.enableNotifications();
        
        expect(mockNotifService.absoluteScheduled.isNotEmpty, true);
        final firstDateNotPaid = mockNotifService.absoluteScheduled.first['date'] as DateTime;
        final currentMonth = DateTime.now().month;
        expect(firstDateNotPaid.month, currentMonth); // It schedules for the current month
        
        // Mark as paid
        mockNotifService.absoluteScheduled.clear();
        mockSubSource.subs = [sub.copyWith(isPaid: true)];
        await coordinator.scheduleSubscription(sub.copyWith(isPaid: true));
        
        expect(mockNotifService.absoluteScheduled.isNotEmpty, true);
        final firstDatePaid = mockNotifService.absoluteScheduled.first['date'] as DateTime;
        final expectedNextMonth = currentMonth == 12 ? 1 : currentMonth + 1;
        expect(firstDatePaid.month, expectedNextMonth); // The first occurrence is now NEXT month
    });
  });
}
