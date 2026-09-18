import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dartz/dartz.dart';

import 'package:gestor_gastos/core/errors/failure.dart';
import 'package:gestor_gastos/core/services/notification_coordinator.dart';

import 'package:gestor_gastos/domain/entities/reminder.dart';
import 'package:gestor_gastos/presentation/providers/reminder_provider.dart';
import 'package:gestor_gastos/presentation/features/wallet/wallet_page.dart';
import 'package:gestor_gastos/presentation/features/reminders/reminders_page.dart';
import 'package:gestor_gastos/presentation/features/reminders/widgets/reminder_card.dart';

class MockReminderProvider extends ChangeNotifier implements ReminderProvider {
  @override
  bool isLoading = false;

  @override
  List<Reminder> overdue = [];

  @override
  List<Reminder> upcoming = [];

  @override
  List<Reminder> completed = [];

  @override
  List<Reminder> inactive = [];

  @override
  List<Reminder> reminders = [];

  @override
  Future<void> loadReminders() async {}

  @override
  Future<Either<Failure, NotificationStatus>> toggleActive(String id, bool active) async {
    return const Right(NotificationStatus.scheduled);
  }

  @override
  Future<Either<Failure, NotificationStatus>> completeOneTime(String id) async {
    return const Right(NotificationStatus.scheduled);
  }

  @override
  Future<Either<Failure, NotificationStatus>> deleteReminder(String id) async {
    return const Right(NotificationStatus.scheduled);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockReminderProvider mockProvider;

  setUp(() {
    mockProvider = MockReminderProvider();
  });

  Widget buildTestableWidget(Widget child) {
    return ChangeNotifierProvider<ReminderProvider>.value(
      value: mockProvider,
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  Reminder createReminder(String id, ReminderStatus status, {ReminderRecurrence rec = ReminderRecurrence.none}) {
    final now = DateTime.now();
    return Reminder(
      id: id,
      title: 'Test $id',
      type: ReminderType.general,
      date: status == ReminderStatus.overdue ? now.subtract(const Duration(days: 1)) : now.add(const Duration(days: 1)),
      hour: 10,
      minute: 0,
      recurrence: rec,
      active: status != ReminderStatus.inactive && status != ReminderStatus.completed,
      completedAt: status == ReminderStatus.completed ? now : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('RemindersSummarySection muestra máximo 3 elementos y overdue tiene prioridad sobre upcoming', (WidgetTester tester) async {
    final overdue1 = createReminder('1', ReminderStatus.overdue);
    final overdue2 = createReminder('2', ReminderStatus.overdue);
    final upcoming1 = createReminder('3', ReminderStatus.upcoming);
    final upcoming2 = createReminder('4', ReminderStatus.upcoming);

    mockProvider.overdue = [overdue1, overdue2];
    mockProvider.upcoming = [upcoming1, upcoming2];

    await tester.pumpWidget(buildTestableWidget(const RemindersSummarySection()));

    // Debería mostrar overdue1, overdue2, y upcoming1 (máximo 3)
    expect(find.byType(ReminderCard), findsNWidgets(3));
    expect(find.text('Test 1'), findsOneWidget);
    expect(find.text('Test 2'), findsOneWidget);
    expect(find.text('Test 3'), findsOneWidget);
    expect(find.text('Test 4'), findsNothing);
  });

  testWidgets('completed e inactive no aparecen en summary', (WidgetTester tester) async {
    final completed = createReminder('1', ReminderStatus.completed);
    final inactive = createReminder('2', ReminderStatus.inactive);
    final upcoming = createReminder('3', ReminderStatus.upcoming);

    mockProvider.completed = [completed];
    mockProvider.inactive = [inactive];
    mockProvider.upcoming = [upcoming];
    mockProvider.overdue = [];

    await tester.pumpWidget(buildTestableWidget(const RemindersSummarySection()));

    // Solo debe mostrar upcoming
    expect(find.byType(ReminderCard), findsOneWidget);
    expect(find.text('Test 3'), findsOneWidget);
  });

  testWidgets('ReminderCard muestra boton completar solo en one-time activo y no completado', (WidgetTester tester) async {
    final oneTime = createReminder('1', ReminderStatus.upcoming, rec: ReminderRecurrence.none);
    final recurring = createReminder('2', ReminderStatus.upcoming, rec: ReminderRecurrence.daily);
    final completed = createReminder('3', ReminderStatus.completed, rec: ReminderRecurrence.none);
    
    // Test one-time
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReminderCard(
      reminder: oneTime,
      onTap: () {},
      onComplete: () {},
      onToggleActive: () {},
      onDelete: () {},
    ))));
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    // Test recurring
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReminderCard(
      reminder: recurring,
      onTap: () {},
      onComplete: () {},
      onToggleActive: () {},
      onDelete: () {},
    ))));
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);

    // Test completed
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReminderCard(
      reminder: completed,
      onTap: () {},
      onComplete: () {},
      onToggleActive: () {},
      onDelete: () {},
    ))));
    expect(find.byIcon(Icons.check_circle_outline), findsNothing); 
  });

  testWidgets('Ver todos navega a RemindersPage', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget(const RemindersSummarySection()));
    
    mockProvider.reminders = [];

    await tester.tap(find.text('Ver todos'));
    await tester.pumpAndSettle();

    expect(find.byType(RemindersPage), findsOneWidget);
  });
}
