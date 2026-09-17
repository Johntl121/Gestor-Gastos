import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:gestor_gastos/core/errors/failure.dart';
import 'package:gestor_gastos/core/services/notification_coordinator.dart';
import 'package:gestor_gastos/domain/entities/reminder.dart';
import 'package:gestor_gastos/domain/repositories/reminder_repository.dart';

class ReminderProvider extends ChangeNotifier {
  final ReminderRepository repository;
  final NotificationCoordinator notificationCoordinator;

  List<Reminder> _reminders = [];
  bool _isLoading = false;
  String? _error;

  ReminderProvider({
    required this.repository,
    required this.notificationCoordinator,
  }) {
    loadReminders();
  }

  List<Reminder> get reminders => _reminders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Derived getters
  List<Reminder> get upcoming {
    final now = DateTime.now();
    final list = _reminders.where((r) => r.getStatus(now) == ReminderStatus.upcoming).toList();
    list.sort((a, b) {
      final aNext = a.getNextOccurrence(now);
      final bNext = b.getNextOccurrence(now);
      if (aNext == null && bNext == null) return 0;
      if (aNext == null) return 1;
      if (bNext == null) return -1;
      return aNext.compareTo(bNext);
    });
    return list;
  }

  List<Reminder> get overdue {
    final now = DateTime.now();
    final list = _reminders.where((r) => r.getStatus(now) == ReminderStatus.overdue).toList();
    list.sort((a, b) {
      final aNext = a.getNextOccurrence(now) ?? a.date;
      final bNext = b.getNextOccurrence(now) ?? b.date;
      // Más reciente primero (orden descendente)
      return bNext.compareTo(aNext);
    });
    return list;
  }

  List<Reminder> get completed {
    final now = DateTime.now();
    final list = _reminders.where((r) => r.getStatus(now) == ReminderStatus.completed).toList();
    list.sort((a, b) {
      final aDate = a.completedAt ?? a.date;
      final bDate = b.completedAt ?? b.date;
      // Más reciente primero
      return bDate.compareTo(aDate);
    });
    return list;
  }

  List<Reminder> get inactive {
    final now = DateTime.now();
    final list = _reminders.where((r) => r.getStatus(now) == ReminderStatus.inactive).toList();
    list.sort((a, b) {
      final aNext = a.getNextOccurrence(now) ?? a.date;
      final bNext = b.getNextOccurrence(now) ?? b.date;
      // Más reciente primero
      return bNext.compareTo(aNext);
    });
    return list;
  }

  Future<void> loadReminders() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await repository.getAllReminders();
    result.fold(
      (fail) => _error = fail.message,
      (list) => _reminders = list,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<Either<Failure, NotificationStatus>> createReminder(Reminder reminder) async {
    final result = await repository.createReminder(reminder);
    return result.fold(
      (fail) => Left(fail),
      (_) async {
        await loadReminders();
        final scheduleResult = await notificationCoordinator.scheduleReminder(reminder);
        return Right(scheduleResult);
      },
    );
  }

  Future<Either<Failure, NotificationStatus>> updateReminder(Reminder reminder) async {
    final result = await repository.updateReminder(reminder);
    return result.fold(
      (fail) => Left(fail),
      (_) async {
        await loadReminders();
        final scheduleResult = await notificationCoordinator.scheduleReminder(reminder);
        return Right(scheduleResult);
      },
    );
  }

  Future<Either<Failure, NotificationStatus>> toggleActive(String id, bool active) async {
    final remIndex = _reminders.indexWhere((r) => r.id == id);
    if (remIndex == -1) return const Left(CacheFailure('Reminder not found'));
    
    final rem = _reminders[remIndex];
    if (rem.completedAt != null && active) {
      return const Left(ValidationFailure('Cannot activate a completed one-time reminder'));
    }

    final updated = rem.copyWith(active: active);
    return updateReminder(updated);
  }

  Future<Either<Failure, NotificationStatus>> completeOneTime(String id) async {
    final remIndex = _reminders.indexWhere((r) => r.id == id);
    if (remIndex == -1) return const Left(CacheFailure('Reminder not found'));
    
    final rem = _reminders[remIndex];
    if (rem.recurrence != ReminderRecurrence.none) {
      return const Left(ValidationFailure('Cannot complete a recurrent reminder'));
    }

    final updated = rem.copyWith(active: false, completedAt: DateTime.now());
    return updateReminder(updated);
  }

  Future<Either<Failure, NotificationStatus>> deleteReminder(String id) async {
    final result = await repository.deleteReminder(id);
    return result.fold(
      (fail) => Left(fail),
      (_) async {
        await loadReminders();
        final scheduleResult = await notificationCoordinator.cancelReminder(id);
        return Right(scheduleResult);
      },
    );
  }
}
