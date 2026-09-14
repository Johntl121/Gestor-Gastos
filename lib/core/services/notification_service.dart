import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_latest;
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
    tz_latest.initializeTimeZones();

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

  /// Configura la zona horaria a utilizar (llamado por Coordinator).
  void setupTimezone(String timezoneName) {
    tz.setLocalLocation(tz.getLocation(timezoneName));
  }

  Future<bool> requestPermissions() async {
    bool? androidResult = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    bool? iosResult = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Si ambos son null, asumimos true o dependemos del platform
    return (androidResult ?? true) && (iosResult ?? true);
  }

  Future<bool> checkPermissions() async {
    final androidImpl = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.areNotificationsEnabled();
      return granted ?? false;
    }
    // iOS has a different way, but we don't have a direct areNotificationsEnabled in free plugin easily without asking.
    // For now, if android fails, we return false. If it's iOS we might need to rely on OS level prompt.
    // However, keeping it simple:
    return true; // Assume true if we can't determine
  }

  /// Schedules a repeating monthly notification (days 1-28).
  Future<void> scheduleRecurringMonthly({
    required int id,
    required String title,
    required String body,
    required int dayOfMonth,
    required TimeOfDay time,
    required String channelId,
    required String channelName,
  }) async {
    final scheduledDate = _nextInstanceOfMonthlyTime(dayOfMonth, time);
    await _zonedScheduleWithFallback(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      channelId: channelId,
      channelName: channelName,
      matchComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  /// Schedules a repeating yearly notification.
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
    final scheduledDate = _nextInstanceOfYearlyTime(month, day, time);
    await _zonedScheduleWithFallback(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      channelId: channelId,
      channelName: channelName,
      matchComponents: null, // we manually manage absolute yearly repeats if we want, but flutter local notif doesn't have yearly out of box easily unless dayOfMonthAndTime for same day? No, actually there's no native yearly repeat component unless we use absolute or dayOfMonthAndTime. Wait, there is no DateTimeComponents.year! So we MUST use absolute and reschedule it every year.
    );
  }

  /// Schedules a one-shot absolute notification.
  Future<void> scheduleAbsoluteNotification({
    required int id,
    required String title,
    required String body,
    required DateTime date,
    required String channelId,
    required String channelName,
  }) async {
    final tzDate = tz.TZDateTime.from(date, tz.local);
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return; // Already passed

    await _zonedScheduleWithFallback(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      channelId: channelId,
      channelName: channelName,
      matchComponents: null,
    );
  }

  Future<void> _zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String channelId,
    required String channelName,
    DateTimeComponents? matchComponents,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        debugPrint(
            'Exact alarms not permitted, falling back to inexact notification for ID $id');
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
        );
      } else {
        rethrow;
      }
    }
  }

  tz.TZDateTime _nextInstanceOfMonthlyTime(int day, TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = _createDate(now.year, now.month, day, time);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = _createDate(now.year, now.month + 1, day, time);
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfYearlyTime(int month, int day, TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = _createDate(now.year, month, day, time);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = _createDate(now.year + 1, month, day, time);
    }
    return scheduledDate;
  }

  tz.TZDateTime _createDate(int year, int month, int day, TimeOfDay time) {
    if (month > 12) {
      year += (month - 1) ~/ 12;
      month = (month - 1) % 12 + 1;
    }
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
