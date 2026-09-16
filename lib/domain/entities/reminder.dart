enum ReminderType { payment, income, general }

enum ReminderRecurrence { none, daily, weekly, monthly, yearly }

enum ReminderStatus { completed, inactive, overdue, upcoming }

class Reminder {
  final String id;
  final String title;
  final String? description;
  final ReminderType type;
  final double? amount;
  final String? currencyCode;
  final int? categoryId;
  final DateTime date;
  final int hour;
  final int minute;
  final ReminderRecurrence recurrence;
  final bool active;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reminder({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    this.amount,
    this.currencyCode,
    this.categoryId,
    required this.date,
    required this.hour,
    required this.minute,
    required this.recurrence,
    this.active = true,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  }) {
    // Validaciones de negocio
    if (amount != null) {
      assert(amount! > 0, 'El monto debe ser mayor a 0');
      assert(
          currencyCode != null, 'currencyCode es requerido si existe un monto');
    } else {
      assert(
          currencyCode == null, 'currencyCode debe ser null si no hay monto');
    }

    if (completedAt != null) {
      assert(recurrence == ReminderRecurrence.none,
          'Solo los recordatorios de una sola vez pueden completarse');
      assert(active == false, 'Un recordatorio completado debe estar inactivo');
    }
  }

  /// Calcula el estado actual del recordatorio (Precedencia: completed > inactive > overdue > upcoming)
  ReminderStatus getStatus(DateTime now) {
    if (completedAt != null) return ReminderStatus.completed;
    if (!active) return ReminderStatus.inactive;

    final nextOcc = getNextOccurrence(now);
    if (recurrence == ReminderRecurrence.none &&
        nextOcc != null &&
        nextOcc.isBefore(now)) {
      return ReminderStatus.overdue;
    }

    return ReminderStatus.upcoming;
  }

  /// Calcula la fecha y hora de la próxima ocurrencia. Retorna null si ya se completó.
  DateTime? getNextOccurrence(DateTime now) {
    if (completedAt != null) return null;

    final originalDateTime =
        DateTime(date.year, date.month, date.day, hour, minute);

    if (recurrence == ReminderRecurrence.none) {
      return originalDateTime;
    }

    if (now.isBefore(originalDateTime) ||
        now.isAtSameMomentAs(originalDateTime)) {
      return originalDateTime;
    }

    switch (recurrence) {
      case ReminderRecurrence.daily:
        DateTime nextDate =
            DateTime(now.year, now.month, now.day, hour, minute);
        if (!nextDate.isAfter(now)) {
          nextDate = DateTime(now.year, now.month, now.day + 1, hour, minute);
        }
        return nextDate;

      case ReminderRecurrence.weekly:
        DateTime nextDate =
            DateTime(now.year, now.month, now.day, hour, minute);
        while (nextDate.weekday != originalDateTime.weekday ||
            !nextDate.isAfter(now)) {
          nextDate = DateTime(
              nextDate.year, nextDate.month, nextDate.day + 1, hour, minute);
        }
        return nextDate;

      case ReminderRecurrence.monthly:
        int targetYear = now.year;
        int targetMonth = now.month;

        while (true) {
          int maxDays = DateTime(targetYear, targetMonth + 1, 0).day;
          int validDay =
              (originalDateTime.day > maxDays) ? maxDays : originalDateTime.day;

          DateTime nextDate =
              DateTime(targetYear, targetMonth, validDay, hour, minute);
          if (nextDate.isAfter(now)) {
            return nextDate;
          }

          targetMonth++;
          if (targetMonth > 12) {
            targetMonth = 1;
            targetYear++;
          }
        }

      case ReminderRecurrence.yearly:
        int targetYear = now.year;
        int targetMonth = originalDateTime.month;

        while (true) {
          int maxDays = DateTime(targetYear, targetMonth + 1, 0).day;
          int validDay =
              (originalDateTime.day > maxDays) ? maxDays : originalDateTime.day;

          DateTime nextDate =
              DateTime(targetYear, targetMonth, validDay, hour, minute);
          if (nextDate.isAfter(now)) {
            return nextDate;
          }
          targetYear++;
        }

      default:
        return originalDateTime;
    }
  }

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    ReminderType? type,
    double? amount,
    String? currencyCode,
    int? categoryId,
    DateTime? date,
    int? hour,
    int? minute,
    ReminderRecurrence? recurrence,
    bool? active,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      recurrence: recurrence ?? this.recurrence,
      active: active ?? this.active,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
