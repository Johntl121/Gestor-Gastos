import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:gestor_gastos/core/services/notification_service.dart';
import 'package:gestor_gastos/core/utils/notification_id_utils.dart';
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';
import 'package:gestor_gastos/domain/repositories/subscription_repository.dart';
import 'package:gestor_gastos/domain/repositories/reminder_repository.dart';
import 'package:gestor_gastos/data/models/subscription.dart';
import 'package:gestor_gastos/domain/entities/reminder.dart';

enum NotificationStatus {
  scheduled,
  notificationsDisabled,
  permissionDenied,
  timezoneUnavailable,
  collisionError
}

enum _SchedulingType {
  absolute,
  recurringDaily,
  recurringWeekly,
  recurringMonthly,
  recurringYearly,
}

class _NotificationCandidate {
  final int notificationId;
  final String title;
  final String body;
  final DateTime nextFireDate;
  final String channelId;
  final String channelName;
  final _SchedulingType schedulingType;

  _NotificationCandidate({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.nextFireDate,
    required this.channelId,
    required this.channelName,
    required this.schedulingType,
  });
}

class NotificationCoordinator {
  final NotificationService _notificationService;
  final PreferencesLocalDataSource _preferences;
  final SubscriptionRepository _subscriptionRepository;
  final ReminderRepository _reminderRepository;

  static const int maxPendingNotifications = 50;

  NotificationCoordinator({
    required NotificationService notificationService,
    required PreferencesLocalDataSource preferences,
    required SubscriptionRepository subscriptionRepository,
    required ReminderRepository reminderRepository,
  })  : _notificationService = notificationService,
        _preferences = preferences,
        _subscriptionRepository = subscriptionRepository,
        _reminderRepository = reminderRepository;

  Future<NotificationStatus> init() async {
    String? timezoneName;
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      timezoneName = tzInfo.identifier;
      if (timezoneName.isEmpty) throw Exception("Empty timezone");
    } catch (e) {
      debugPrint("❌ Failed to get timezone: $e");
      return NotificationStatus.timezoneUnavailable;
    }

    _notificationService.setupTimezone(timezoneName);

    final lastTimezone = _preferences.getLastKnownTimezone();
    bool tzChanged = lastTimezone != null && lastTimezone != timezoneName;
    if (tzChanged) {
      debugPrint("🔄 Timezone changed from $lastTimezone to $timezoneName");
    }
    await _preferences.saveLastKnownTimezone(timezoneName);

    bool needsMigration = _preferences.getSchedulerMigrationVersion() < 1;

    if (needsMigration || tzChanged) {
      await _notificationService.cancelAll();
      final status = await _rescheduleAllActive();
      if (needsMigration && status != NotificationStatus.collisionError) {
        await _preferences.saveSchedulerMigrationVersion(1);
      }
      return status;
    }

    return await _rescheduleAllActive();
  }

  Future<NotificationStatus> enableNotifications() async {
    final granted = await _notificationService.requestPermissions();
    if (!granted) {
      await _preferences.saveEnableNotifications(false);
      return NotificationStatus.permissionDenied;
    }
    await _preferences.saveEnableNotifications(true);
    return await _rescheduleAllActive();
  }

  Future<NotificationStatus> disableNotifications() async {
    await _preferences.saveEnableNotifications(false);
    await _notificationService.cancelAll();
    return NotificationStatus.notificationsDisabled;
  }

  // --- Suscripciones ---
  Future<NotificationStatus> scheduleSubscription(Subscription sub) async {
    return await _rescheduleAllActive();
  }

  Future<NotificationStatus> cancelSubscription(String subId) async {
    return await _rescheduleAllActive();
  }

  // --- Recordatorios ---
  Future<NotificationStatus> scheduleReminder(Reminder reminder) async {
    return await _rescheduleAllActive();
  }

  Future<NotificationStatus> cancelReminder(String reminderId) async {
    return await _rescheduleAllActive();
  }

  Future<NotificationStatus> _rescheduleAllActive() async {
    if (!_preferences.getEnableNotifications()) {
      return NotificationStatus.notificationsDisabled;
    }
    final hasPermission = await _notificationService.checkPermissions();
    if (!hasPermission) {
      await _preferences.saveEnableNotifications(false);
      return NotificationStatus.permissionDenied;
    }

    final now = DateTime.now();
    List<_NotificationCandidate> allCandidates = [];

    // 1. Recopilar candidatos de Suscripciones
    final subResult = await _subscriptionRepository.getSubscriptions();
    final subs = subResult.getOrElse(() => []);
    for (var sub in subs) {
      allCandidates.addAll(_generateSubscriptionCandidates(sub, now));
    }

    // 2. Recopilar candidatos de Recordatorios
    final remindersResult = await _reminderRepository.getAllReminders();
    final reminders = remindersResult.getOrElse(() => []);
    for (var rem in reminders) {
      allCandidates.addAll(_generateReminderCandidates(rem, now));
    }

    // 3. Validar colisiones lógicas pre-programación
    final usedIds = <int>{};
    for (var cand in allCandidates) {
      if (usedIds.contains(cand.notificationId)) {
        debugPrint(
            "🚨 Collision detected in notification IDs: ${cand.notificationId}");
        return NotificationStatus.collisionError;
      }
      usedIds.add(cand.notificationId);
    }

    // 4. Cancelar todo en OS
    await _notificationService.cancelAll();

    // 5. Ordenar por nextFireDate (ascendente)
    // Desempate determinista por notificationId
    allCandidates.sort((a, b) {
      int dateCmp = a.nextFireDate.compareTo(b.nextFireDate);
      if (dateCmp != 0) return dateCmp;
      return a.notificationId.compareTo(b.notificationId);
    });

    // 6. Seleccionar hasta el límite global
    final budget = allCandidates.take(maxPendingNotifications);

    // 7. Programar en OS
    for (var cand in budget) {
      switch (cand.schedulingType) {
        case _SchedulingType.absolute:
          await _notificationService.scheduleAbsoluteNotification(
            id: cand.notificationId,
            title: cand.title,
            body: cand.body,
            date: cand.nextFireDate,
            channelId: cand.channelId,
            channelName: cand.channelName,
          );
          break;
        case _SchedulingType.recurringDaily:
          await _notificationService.scheduleRecurringDaily(
            id: cand.notificationId,
            title: cand.title,
            body: cand.body,
            startDate: cand.nextFireDate,
            channelId: cand.channelId,
            channelName: cand.channelName,
          );
          break;
        case _SchedulingType.recurringWeekly:
          await _notificationService.scheduleRecurringWeekly(
            id: cand.notificationId,
            title: cand.title,
            body: cand.body,
            startDate: cand.nextFireDate,
            channelId: cand.channelId,
            channelName: cand.channelName,
          );
          break;
        case _SchedulingType.recurringMonthly:
          await _notificationService.scheduleRecurringMonthlyFromDate(
            id: cand.notificationId,
            title: cand.title,
            body: cand.body,
            startDate: cand.nextFireDate,
            channelId: cand.channelId,
            channelName: cand.channelName,
          );
          break;
        case _SchedulingType.recurringYearly:
          // Tratado como absoluto en OS
          await _notificationService.scheduleAbsoluteNotification(
            id: cand.notificationId,
            title: cand.title,
            body: cand.body,
            date: cand.nextFireDate,
            channelId: cand.channelId,
            channelName: cand.channelName,
          );
          break;
      }
    }

    return NotificationStatus.scheduled;
  }

  List<_NotificationCandidate> _generateSubscriptionCandidates(
      Subscription sub, DateTime now) {
    List<_NotificationCandidate> candidates = [];
    const title = "Recordatorio de Pago";
    final body = "¡Hoy vence tu pago de ${sub.name}! 📅";
    const channelId = "fixed_expenses_channel";
    const channelName = "Gastos Fijos";

    if (sub.frequency == ExpenseFrequency.yearly) {
      DateTime target =
          DateTime(now.year, sub.paymentDate.month, sub.paymentDate.day, 9, 0);
      if (target.isBefore(now)) {
        target = DateTime(
            now.year + 1, sub.paymentDate.month, sub.paymentDate.day, 9, 0);
      }
      final notifId = NotificationIdUtils.generateId('subscription', sub.id);
      candidates.add(_NotificationCandidate(
        notificationId: notifId,
        title: title,
        body: body,
        nextFireDate: target,
        channelId: channelId,
        channelName: channelName,
        schedulingType: _SchedulingType.recurringYearly,
      ));
    } else {
      if (sub.paymentDate.day <= 28) {
        DateTime target =
            DateTime(now.year, now.month, sub.paymentDate.day, 9, 0);
        if (target.isBefore(now) || sub.isPaid) {
          target = DateTime(now.year, now.month + 1, sub.paymentDate.day, 9, 0);
        }
        final notifId = NotificationIdUtils.generateId('subscription', sub.id);
        candidates.add(_NotificationCandidate(
          notificationId: notifId,
          title: title,
          body: body,
          nextFireDate: target,
          channelId: channelId,
          channelName: channelName,
          schedulingType: _SchedulingType.recurringMonthly,
        ));
      } else {
        for (int i = 0; i < maxPendingNotifications; i++) {
          DateTime target =
              _calculateAbsoluteOccurrence(sub.paymentDate, i, sub.isPaid, now);
          if (target.isBefore(now)) continue;
          final dateStr = '${target.year}-${target.month}-${target.day}';
          final occId = NotificationIdUtils.generateId(
              'subscription_occ', '${sub.id}_$dateStr');
          candidates.add(_NotificationCandidate(
            notificationId: occId,
            title: title,
            body: body,
            nextFireDate: target,
            channelId: channelId,
            channelName: channelName,
            schedulingType: _SchedulingType.absolute,
          ));
        }
      }
    }
    return candidates;
  }

  List<_NotificationCandidate> _generateReminderCandidates(
      Reminder rem, DateTime now) {
    if (!rem.active) return [];

    List<_NotificationCandidate> candidates = [];
    final channelId = rem.type == ReminderType.payment
        ? "payments_channel"
        : "reminders_channel";
    final channelName =
        rem.type == ReminderType.payment ? "Pagos" : "Recordatorios";
    final body = rem.description ?? "Recordatorio programado";

    if (rem.recurrence == ReminderRecurrence.none) {
      if (rem.completedAt != null) return [];
      final target = rem.getNextOccurrence(now);
      if (target != null && target.isAfter(now)) {
        final notifId = NotificationIdUtils.generateId('reminder', rem.id);
        candidates.add(_NotificationCandidate(
          notificationId: notifId,
          title: rem.title,
          body: body,
          nextFireDate: target,
          channelId: channelId,
          channelName: channelName,
          schedulingType: _SchedulingType.absolute,
        ));
      }
    } else {
      if (rem.recurrence == ReminderRecurrence.daily ||
          rem.recurrence == ReminderRecurrence.weekly ||
          rem.recurrence == ReminderRecurrence.yearly ||
          (rem.recurrence == ReminderRecurrence.monthly &&
              rem.date.day <= 28)) {
        final target = rem.getNextOccurrence(now);
        if (target != null) {
          final notifId = NotificationIdUtils.generateId('reminder', rem.id);
          _SchedulingType type;
          switch (rem.recurrence) {
            case ReminderRecurrence.daily:
              type = _SchedulingType.recurringDaily;
              break;
            case ReminderRecurrence.weekly:
              type = _SchedulingType.recurringWeekly;
              break;
            case ReminderRecurrence.monthly:
              type = _SchedulingType.recurringMonthly;
              break;
            case ReminderRecurrence.yearly:
              type = _SchedulingType.recurringYearly;
              break;
            default:
              type = _SchedulingType.absolute;
          }
          candidates.add(_NotificationCandidate(
            notificationId: notifId,
            title: rem.title,
            body: body,
            nextFireDate: target,
            channelId: channelId,
            channelName: channelName,
            schedulingType: type,
          ));
        }
      } else if (rem.recurrence == ReminderRecurrence.monthly &&
          rem.date.day > 28) {
        DateTime iterNow = now;
        for (int i = 0; i < maxPendingNotifications; i++) {
          final target = rem.getNextOccurrence(iterNow);
          if (target == null) break;

          final dateStr = '${target.year}-${target.month}-${target.day}';
          final occId = NotificationIdUtils.generateId(
              'reminder_occ', '${rem.id}_$dateStr');
          candidates.add(_NotificationCandidate(
            notificationId: occId,
            title: rem.title,
            body: body,
            nextFireDate: target,
            channelId: channelId,
            channelName: channelName,
            schedulingType: _SchedulingType.absolute,
          ));

          iterNow = target.add(const Duration(seconds: 1));
        }
      }
    }
    return candidates;
  }

  DateTime _calculateAbsoluteOccurrence(
      DateTime originalDate, int monthsToAdd, bool isPaid, DateTime now) {
    int startOffset = isPaid ? 1 : 0;
    int paymentDay = originalDate.day;
    int targetYear = now.year;
    int targetMonth = now.month + startOffset + monthsToAdd;
    while (targetMonth > 12) {
      targetMonth -= 12;
      targetYear += 1;
    }
    int maxDaysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    int validDay =
        (paymentDay > maxDaysInTargetMonth) ? maxDaysInTargetMonth : paymentDay;
    return DateTime(targetYear, targetMonth, validDay, 9, 0);
  }
}
