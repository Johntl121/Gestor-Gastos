import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/errors/failure.dart';
import 'package:gestor_gastos/core/services/notification_coordinator.dart';
import 'package:gestor_gastos/domain/entities/reminder.dart';
import 'package:gestor_gastos/domain/repositories/reminder_repository.dart';
import 'package:gestor_gastos/presentation/providers/reminder_provider.dart';

class MockReminderRepository implements ReminderRepository {
  List<Reminder> reminders = [];
  bool shouldFail = false;

  @override
  Future<Either<Failure, List<Reminder>>> getAllReminders() async {
    if (shouldFail) return const Left(DatabaseFailure('Error'));
    return Right(reminders);
  }

  @override
  Future<Either<Failure, Reminder?>> getReminderById(String id) async {
    if (shouldFail) return const Left(DatabaseFailure('Error'));
    final index = reminders.indexWhere((r) => r.id == id);
    if (index == -1) return const Right(null);
    return Right(reminders[index]);
  }

  @override
  Future<Either<Failure, void>> createReminder(Reminder reminder) async {
    if (shouldFail) return const Left(DatabaseFailure('Error'));
    reminders.add(reminder);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateReminder(Reminder reminder) async {
    if (shouldFail) return const Left(DatabaseFailure('Error'));
    final index = reminders.indexWhere((r) => r.id == reminder.id);
    if (index == -1) return const Left(DatabaseFailure('Not found'));
    reminders[index] = reminder;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteReminder(String id) async {
    if (shouldFail) return const Left(DatabaseFailure('Error'));
    reminders.removeWhere((r) => r.id == id);
    return const Right(null);
  }
}

class MockNotificationCoordinator implements NotificationCoordinator {
  NotificationStatus status = NotificationStatus.scheduled;

  @override
  Future<NotificationStatus> init() async {
    return status;
  }

  @override
  Future<NotificationStatus> scheduleReminder(Reminder reminder) async {
    return status;
  }

  @override
  Future<NotificationStatus> cancelReminder(String reminderId) async {
    return status;
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ReminderProvider provider;
  late MockReminderRepository mockRepository;
  late MockNotificationCoordinator mockCoordinator;

  setUp(() {
    mockRepository = MockReminderRepository();
    mockCoordinator = MockNotificationCoordinator();
    
    // We instantiate after mock setup, loadReminders is called in constructor
    provider = ReminderProvider(
      repository: mockRepository,
      notificationCoordinator: mockCoordinator,
    );
  });

  group('ReminderProvider', () {
    final now = DateTime.now();

    final activeOneTimeFuture = Reminder(
      id: '1', title: 'Future OneTime', type: ReminderType.general,
      date: now.add(const Duration(days: 2)), hour: 9, minute: 0,
      recurrence: ReminderRecurrence.none, createdAt: now, updatedAt: now, active: true
    );
    final activeOneTimePast = Reminder(
      id: '2', title: 'Past OneTime', type: ReminderType.general,
      date: now.subtract(const Duration(days: 2)), hour: 9, minute: 0,
      recurrence: ReminderRecurrence.none, createdAt: now, updatedAt: now, active: true
    );
    final completedOneTime = Reminder(
      id: '3', title: 'Completed', type: ReminderType.general,
      date: now.subtract(const Duration(days: 2)), hour: 9, minute: 0,
      recurrence: ReminderRecurrence.none, createdAt: now, updatedAt: now, active: false,
      completedAt: now.subtract(const Duration(days: 1))
    );
    final inactiveReminder = Reminder(
      id: '4', title: 'Inactive', type: ReminderType.general,
      date: now.add(const Duration(days: 2)), hour: 9, minute: 0,
      recurrence: ReminderRecurrence.none, createdAt: now, updatedAt: now, active: false
    );
    final recurrentReminder = Reminder(
      id: '5', title: 'Recurrent', type: ReminderType.general,
      date: now.subtract(const Duration(days: 2)), hour: 9, minute: 0,
      recurrence: ReminderRecurrence.daily, createdAt: now, updatedAt: now, active: true
    );

    test('loadReminders populates lists correctly', () async {
      mockRepository.reminders = [
        activeOneTimeFuture,
        activeOneTimePast,
        completedOneTime,
        inactiveReminder,
        recurrentReminder
      ];

      await provider.loadReminders();

      expect(provider.reminders.length, 5);
      expect(provider.upcoming.length, 2); // activeOneTimeFuture, recurrentReminder
      expect(provider.overdue.length, 1); // activeOneTimePast
      expect(provider.completed.length, 1); // completedOneTime
      expect(provider.inactive.length, 1); // inactiveReminder
    });

    test('createReminder updates cache and scheduler', () async {
      final result = await provider.createReminder(activeOneTimeFuture);
      
      expect(result.isRight(), true);
      result.fold((l) => null, (r) => expect(r, NotificationStatus.scheduled));
      
      expect(provider.reminders.length, 1);
      expect(mockRepository.reminders.length, 1);
    });

    test('createReminder handles persistence failure correctly (no cache update)', () async {
      mockRepository.shouldFail = true;
      final result = await provider.createReminder(activeOneTimeFuture);
      
      expect(result.isLeft(), true);
      expect(provider.reminders.length, 0); // No actualizó caché falso
    });

    test('createReminder handles scheduling failure but keeps persistence', () async {
      mockCoordinator.status = NotificationStatus.permissionDenied;
      final result = await provider.createReminder(activeOneTimeFuture);
      
      expect(result.isRight(), true); // Operación de DB exitosa
      result.fold((l) => null, (r) => expect(r, NotificationStatus.permissionDenied));
      
      // Permaneció guardado
      expect(provider.reminders.length, 1);
    });

    test('updateReminder updates cache', () async {
      mockRepository.reminders = [activeOneTimeFuture];
      await provider.loadReminders();

      final updated = activeOneTimeFuture.copyWith(title: 'Updated');
      final result = await provider.updateReminder(updated);

      expect(result.isRight(), true);
      expect(provider.reminders.first.title, 'Updated');
    });

    test('deleteReminder removes from cache and calls cancel', () async {
      mockRepository.reminders = [activeOneTimeFuture];
      await provider.loadReminders();

      final result = await provider.deleteReminder(activeOneTimeFuture.id);
      expect(result.isRight(), true);
      expect(provider.reminders.length, 0);
    });

    test('toggleActive deactivates and activates successfully', () async {
      mockRepository.reminders = [activeOneTimeFuture];
      await provider.loadReminders();

      // Deactivate
      final deactivateResult = await provider.toggleActive(activeOneTimeFuture.id, false);
      expect(deactivateResult.isRight(), true);
      expect(provider.reminders.first.active, false);

      // Reactivate
      final activateResult = await provider.toggleActive(activeOneTimeFuture.id, true);
      expect(activateResult.isRight(), true);
      expect(provider.reminders.first.active, true);
    });

    test('toggleActive prevents activating a completed one-time reminder', () async {
      mockRepository.reminders = [completedOneTime];
      await provider.loadReminders();

      final result = await provider.toggleActive(completedOneTime.id, true);
      expect(result.isLeft(), true);
      result.fold((l) => expect(l is ValidationFailure, true), (r) => null);
    });

    test('completeOneTime completes successfully', () async {
      mockRepository.reminders = [activeOneTimePast];
      await provider.loadReminders();

      final result = await provider.completeOneTime(activeOneTimePast.id);
      expect(result.isRight(), true);
      expect(provider.reminders.first.active, false);
      expect(provider.reminders.first.completedAt, isNotNull);
    });

    test('completeOneTime rejects recurrent reminders', () async {
      mockRepository.reminders = [recurrentReminder];
      await provider.loadReminders();

      final result = await provider.completeOneTime(recurrentReminder.id);
      expect(result.isLeft(), true);
      result.fold((l) => expect(l is ValidationFailure, true), (r) => null);
    });

    test('order logic: upcoming are ordered by nextOccurrence ASC', () async {
      final rem1 = Reminder(
        id: '1', title: 'R1', type: ReminderType.general,
        date: now.add(const Duration(days: 5)), hour: 9, minute: 0,
        recurrence: ReminderRecurrence.none, createdAt: now, updatedAt: now, active: true
      );
      final rem2 = Reminder(
        id: '2', title: 'R2', type: ReminderType.general,
        date: now.add(const Duration(days: 2)), hour: 9, minute: 0,
        recurrence: ReminderRecurrence.none, createdAt: now, updatedAt: now, active: true
      );
      mockRepository.reminders = [rem1, rem2];
      await provider.loadReminders();

      final upcoming = provider.upcoming;
      expect(upcoming[0].id, '2'); // The one in 2 days comes first
      expect(upcoming[1].id, '1');
    });

    test('order logic: overdue are ordered by date DESC (más recientes primero)', () async {
      final rem1 = Reminder(
        id: '1', title: 'R1', type: ReminderType.general,
        date: now.subtract(const Duration(days: 5)), hour: 9, minute: 0,
        recurrence: ReminderRecurrence.none, createdAt: now, updatedAt: now, active: true
      );
      final rem2 = Reminder(
        id: '2', title: 'R2', type: ReminderType.general,
        date: now.subtract(const Duration(days: 2)), hour: 9, minute: 0,
        recurrence: ReminderRecurrence.none, createdAt: now, updatedAt: now, active: true
      );
      mockRepository.reminders = [rem1, rem2];
      await provider.loadReminders();

      final overdue = provider.overdue;
      expect(overdue[0].id, '2'); // -2 days is more recent than -5 days
      expect(overdue[1].id, '1');
    });
  });
}
