import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

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
  /// If the [dayOfMonth] has already passed for the current month (or time),
  /// it schedules for the next month.
  /// Handles "Magic Hour" and short months automatically via logic.
  Future<void> scheduleMonthlyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfMonth,
    required TimeOfDay time,
  }) async {
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
  }

  /// Schedules a test notification in [seconds] seconds.
  Future<void> scheduleTestNotification({int seconds = 5}) async {
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
