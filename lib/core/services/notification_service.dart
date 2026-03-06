import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) async {
        // Handle notification tap
      },
    );
  }

  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Schedules a monthly notification.
  Future<void> scheduleMonthlyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfMonth,
    required TimeOfDay time,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfMonthlyTime(dayOfMonth, time),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'fixed_expenses_channel',
            'Gastos Fijos',
            channelDescription: 'Recordatorios de pagos mensuales',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        debugPrint(
            'Exact alarms not permitted, falling back to inexact notification for ID $id');
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          _nextInstanceOfMonthlyTime(dayOfMonth, time),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'fixed_expenses_channel',
              'Gastos Fijos',
              channelDescription: 'Recordatorios de pagos mensuales',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );
      } else {
        rethrow;
      }
    }
  }

  /// Schedules a yearly notification.
  Future<void> scheduleYearlyNotification({
    required int id,
    required String title,
    required String body,
    required int month,
    required int day,
    required TimeOfDay time,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfYearlyTime(month, day, time),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'fixed_expenses_yearly_channel',
            'Gastos Anuales',
            channelDescription: 'Recordatorios de pagos anuales',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        debugPrint(
            'Exact alarms not permitted, falling back to inexact notification for ID $id');
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          _nextInstanceOfYearlyTime(month, day, time),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'fixed_expenses_yearly_channel',
              'Gastos Anuales',
              channelDescription: 'Recordatorios de pagos anuales',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else {
        rethrow;
      }
    }
  }

  tz.TZDateTime _nextInstanceOfYearlyTime(int month, int day, TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // Attempt to schedule for this year
    tz.TZDateTime scheduledDate = _createDate(now.year, month, day, time);

    // If passed, next year
    if (scheduledDate.isBefore(now)) {
      scheduledDate = _createDate(now.year + 1, month, day, time);
    }
    return scheduledDate;
  }

  /// Schedules a test notification in [seconds] seconds.
  Future<void> scheduleTestNotification({int seconds = 5}) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        99999, // Unique Test ID
        'Prueba de Notificación 🔔',
        'Si ves esto, las notificaciones funcionan correctamente.',
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Pruebas',
            channelDescription: 'Canal para pruebas de notificaciones',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        debugPrint('Exact alarms not permitted, falling back to inexact test');
        await flutterLocalNotificationsPlugin.zonedSchedule(
          99999,
          'Prueba de Notificación 🔔',
          'Si ves esto, las notificaciones funcionan correctamente (Modo Inexacto).',
          tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'test_channel',
              'Pruebas',
              channelDescription: 'Canal para pruebas de notificaciones',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else {
        rethrow;
      }
    }
  }

  tz.TZDateTime _nextInstanceOfMonthlyTime(int day, TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // Creates a date for the current month/year with the target day/time
    tz.TZDateTime scheduledDate = _createDate(now.year, now.month, day, time);

    // If that date is before now (already passed), schedule for next month
    if (scheduledDate.isBefore(now)) {
      scheduledDate = _createDate(now.year, now.month + 1, day, time);
    }

    return scheduledDate;
  }

  tz.TZDateTime _createDate(int year, int month, int day, TimeOfDay time) {
    // Recursive month overflow check (just in case)
    if (month > 12) {
      year += (month - 1) ~/ 12;
      month = (month - 1) % 12 + 1;
    }

    // Clamp day to max days in month (e.g. Feb 30 -> Feb 28/29)
    final int maxDays = DateTime(year, month + 1, 0).day;
    final int validDay = day > maxDays ? maxDays : day;

    return tz.TZDateTime(
        tz.local, year, month, validDay, time.hour, time.minute);
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
