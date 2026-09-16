import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:gestor_gastos/core/services/notification_service.dart';
import 'package:gestor_gastos/core/utils/notification_id_utils.dart';
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';
import 'package:gestor_gastos/data/datasources/subscription_local_data_source.dart';
import 'package:gestor_gastos/data/models/subscription.dart';

enum NotificationStatus {
  scheduled,
  notificationsDisabled,
  permissionDenied,
  timezoneUnavailable,
  collisionError
}

class _Occurrence {
  final int id;
  final String title;
  final String body;
  final DateTime date;

  _Occurrence(this.id, this.title, this.body, this.date);
}

class NotificationCoordinator {
  final NotificationService _notificationService;
  final PreferencesLocalDataSource _preferences;
  final SubscriptionLocalDataSource _subscriptionDataSource;

  // Límite global para alarmas absolutas (29-31)
  static const int _maxAbsoluteOccurrences = 40;

  NotificationCoordinator({
    required NotificationService notificationService,
    required PreferencesLocalDataSource preferences,
    required SubscriptionLocalDataSource subscriptionDataSource,
  })  : _notificationService = notificationService,
        _preferences = preferences,
        _subscriptionDataSource = subscriptionDataSource;

  /// Initializes timezone, runs migration, and reschedules if needed.
  Future<NotificationStatus> init() async {
    String? timezoneName;
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      timezoneName = tzInfo.identifier;
      if (timezoneName.isEmpty) {
        throw Exception("Empty timezone");
      }
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
      if (needsMigration) {
        debugPrint("🚀 Executing Scheduler Migration (version 0 -> 1)");
      }
      await _notificationService.cancelAll();

      final status = await _rescheduleAllActive();

      if (needsMigration) {
        // La migración se marca completa si el proceso termina ordenadamente en cualquiera 
        // de los estados válidos (scheduled, disabled, denied).
        // Fallos transitorios inesperados arrojarían una excepción y evitarían llegar aquí.
        if (status != NotificationStatus.collisionError) {
          await _preferences.saveSchedulerMigrationVersion(1);
        }
      }
      return status;
    }

    // Reponer horizonte cada vez que arranca la app de ser necesario
    // Para no gastar en exceso procesador, lo hacemos de forma asíncrona pero lo retornaremos como success.
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

  Future<NotificationStatus> scheduleSubscription(Subscription sub) async {
    if (!_preferences.getEnableNotifications()) {
      return NotificationStatus.notificationsDisabled;
    }

    final hasPermission = await _notificationService.checkPermissions();
    if (!hasPermission) {
      await _preferences.saveEnableNotifications(false);
      return NotificationStatus.permissionDenied;
    }

    // Al añadir una suscripción, el horizonte global podría cambiar.
    // Lo más seguro es reprogramar todas.
    return await _rescheduleAllActive();
  }

  Future<void> cancelSubscription(String subId) async {
    // Al eliminar, simplemente reprogramamos todo para llenar huecos del presupuesto
    // Pero si queremos ser muy precisos, podríamos borrar la específica si no está en 29-31.
    // Como la reconstrucción total es segura y rápida, la haremos.
    final id = NotificationIdUtils.generateId('subscription', subId);
    await _notificationService.cancelNotification(id);
    await _rescheduleAllActive();
  }

  /// Reprograma el lote entero tras un evento de edición, pago, inicio o activación.
  Future<NotificationStatus> _rescheduleAllActive() async {
    if (!_preferences.getEnableNotifications()) {
      return NotificationStatus.notificationsDisabled;
    }

    final hasPermission = await _notificationService.checkPermissions();
    if (!hasPermission) {
      await _preferences.saveEnableNotifications(false);
      return NotificationStatus.permissionDenied;
    }

    final subs = await _subscriptionDataSource.getSubscriptions();
    if (_hasCollision(subs)) {
      debugPrint("🚨 Collision detected in subscription IDs!");
      return NotificationStatus.collisionError;
    }

    // 1. Cancelamos todas por seguridad, para que las que ya no entran en el presupuesto
    // no queden colgando en el OS.
    await _notificationService.cancelAll();

    List<_Occurrence> allAbsoluteOccurrences = [];

    for (var sub in subs) {
      final notifId = NotificationIdUtils.generateId('subscription', sub.id);

      const title = "Recordatorio de Pago";
      final body = "¡Hoy vence tu pago de ${sub.name}! 📅";
      const channelId = "fixed_expenses_channel";
      const channelName = "Gastos Fijos";

      if (sub.frequency == ExpenseFrequency.yearly) {
        await _notificationService.scheduleRecurringYearly(
          id: notifId,
          title: title,
          body: body,
          month: sub.paymentDate.month,
          day: sub.paymentDate.day,
          time: const TimeOfDay(hour: 9, minute: 0),
          channelId: channelId,
          channelName: channelName,
        );
      } else {
        if (sub.paymentDate.day <= 28) {
          await _notificationService.scheduleRecurringMonthly(
            id: notifId,
            title: title,
            body: body,
            dayOfMonth: sub.paymentDate.day,
            time: const TimeOfDay(hour: 9, minute: 0),
            channelId: channelId,
            channelName: channelName,
            skipCurrentMonth: sub.isPaid,
          );
        } else {
          // Generar ocurrencias futuras para el pool (proyectamos hasta el máximo por si acaso)
          for (int i = 0; i < _maxAbsoluteOccurrences; i++) {
            DateTime target =
                _calculateAbsoluteOccurrence(sub.paymentDate, i, sub.isPaid);
            // Usamos un hash derivado
            final occId =
                NotificationIdUtils.generateId('subscription_occ_$i', sub.id);
            allAbsoluteOccurrences.add(_Occurrence(occId, title, body, target));
          }
        }
      }
    }

    // Ordenamos cronológicamente y tomamos el presupuesto
    allAbsoluteOccurrences.sort((a, b) => a.date.compareTo(b.date));
    final budget = allAbsoluteOccurrences.take(_maxAbsoluteOccurrences);

    // Filtramos colisiones posibles entre ocurrencias extremas
    final usedIds = <int>{};
    for (var occ in budget) {
      if (usedIds.contains(occ.id)) continue;
      usedIds.add(occ.id);

      await _notificationService.scheduleAbsoluteNotification(
        id: occ.id,
        title: occ.title,
        body: occ.body,
        date: occ.date,
        channelId: "fixed_expenses_channel",
        channelName: "Gastos Fijos",
      );
    }

    return NotificationStatus.scheduled;
  }

  DateTime _calculateAbsoluteOccurrence(
      DateTime originalDate, int monthsToAdd, bool isPaid) {
    final now = DateTime.now();
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

    return DateTime(targetYear, targetMonth, validDay, 9, 0); // Hardcode 9 AM
  }

  bool _hasCollision(List<Subscription> subs) {
    final set = <int>{};
    for (var s in subs) {
      final id = NotificationIdUtils.generateId('subscription', s.id);
      if (set.contains(id)) {
        return true;
      }
      set.add(id);
    }
    return false;
  }
}
