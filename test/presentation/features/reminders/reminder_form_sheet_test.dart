import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gestor_gastos/domain/entities/reminder.dart';
import 'package:gestor_gastos/core/errors/failure.dart';
import 'package:gestor_gastos/core/services/notification_coordinator.dart';
import 'package:gestor_gastos/domain/repositories/reminder_repository.dart';
import 'package:gestor_gastos/presentation/providers/reminder_provider.dart';
import 'package:gestor_gastos/presentation/providers/wallet_provider.dart';
import 'package:gestor_gastos/presentation/features/reminders/widgets/reminder_form_sheet.dart';

class MockWalletProvider extends Mock implements WalletProvider {}
class MockNotificationCoordinator extends Mock implements NotificationCoordinator {}
class MockReminderRepository extends Mock implements ReminderRepository {}

class FakeReminderProvider extends ChangeNotifier implements ReminderProvider {
  final List<Reminder> _reminders = [];
  bool shouldFailCreation = false;
  Failure? schedulerFailure;
  Reminder? lastCreatedReminder;
  Reminder? lastUpdatedReminder;

  @override
  List<Reminder> get reminders => _reminders;
  @override
  List<Reminder> get overdue => _reminders.where((r) => r.getStatus(DateTime.now()) == ReminderStatus.overdue).toList();
  @override
  List<Reminder> get upcoming => _reminders.where((r) => r.getStatus(DateTime.now()) == ReminderStatus.upcoming).toList();
  @override
  List<Reminder> get inactive => _reminders.where((r) => r.getStatus(DateTime.now()) == ReminderStatus.inactive).toList();
  @override
  List<Reminder> get completed => _reminders.where((r) => r.getStatus(DateTime.now()) == ReminderStatus.completed).toList();
  @override
  bool get isLoading => false;
  @override
  String? get error => null;
  @override
  NotificationCoordinator get notificationCoordinator => MockNotificationCoordinator();
  @override
  ReminderRepository get repository => MockReminderRepository();

  @override
  Future<void> loadReminders() async {}

  @override
  Future<Either<Failure, NotificationStatus>> createReminder(Reminder reminder) async {
    if (shouldFailCreation) {
      return const Left(CacheFailure('Error de persistencia'));
    }
    lastCreatedReminder = reminder;
    _reminders.add(reminder);
    notifyListeners();
    if (schedulerFailure != null) {
      return Left(schedulerFailure!);
    }
    return const Right(NotificationStatus.scheduled);
  }

  @override
  Future<Either<Failure, NotificationStatus>> updateReminder(Reminder reminder) async {
    lastUpdatedReminder = reminder;
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index >= 0) {
      _reminders[index] = reminder;
      notifyListeners();
    }
    return const Right(NotificationStatus.scheduled);
  }

  @override
  Future<Either<Failure, NotificationStatus>> deleteReminder(String id) async => const Right(NotificationStatus.scheduled);
  @override
  Future<Either<Failure, NotificationStatus>> toggleActive(String id, bool active) async => const Right(NotificationStatus.scheduled);
  @override
  Future<Either<Failure, NotificationStatus>> completeOneTime(String id) async => const Right(NotificationStatus.scheduled);

  @override
  Future<void> dispose() async {
    super.dispose();
  }
}

void main() {
  late FakeReminderProvider mockReminderProvider;
  late MockWalletProvider mockWalletProvider;

  setUp(() {
    mockReminderProvider = FakeReminderProvider();
    mockWalletProvider = MockWalletProvider();
    when(() => mockWalletProvider.currencySymbol).thenReturn('S/');
  });

  Widget buildTestWidget({Reminder? existingReminder}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ReminderProvider>.value(value: mockReminderProvider),
        ChangeNotifierProvider<WalletProvider>.value(value: mockWalletProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ReminderFormSheet(existingReminder: existingReminder),
        ),
      ),
    );
  }

  testWidgets('Crear mínimo válido', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    await tester.enterText(find.byType(TextFormField).first, 'Pagar Internet');
    await tester.tap(find.text('Crear Recordatorio'));
    await tester.pumpAndSettle();

    final created = mockReminderProvider.lastCreatedReminder;
    expect(created, isNotNull);
    expect(created!.title, 'Pagar Internet');
    expect(created.amount, isNull);
    expect(created.currencyCode, isNull);
  });

  testWidgets('Título vacío rechazado', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    await tester.tap(find.text('Crear Recordatorio'));
    await tester.pumpAndSettle();

    expect(mockReminderProvider.lastCreatedReminder, isNull);
    expect(find.text('Requerido'), findsOneWidget); 
  });

  testWidgets('Crear con monto + moneda preseleccionada', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    await tester.enterText(find.byType(TextFormField).first, 'Compra');
    
    final amountField = find.byType(TextFormField).at(2);
    await tester.enterText(amountField, '50.5');
    await tester.pump();

    await tester.tap(find.text('Crear Recordatorio'));
    await tester.pumpAndSettle();

    final created = mockReminderProvider.lastCreatedReminder;
    expect(created, isNotNull);
    expect(created!.amount, 50.5);
    expect(created.currencyCode, 'PEN');
  });

  testWidgets('Editar precarga valores y conserva id/createdAt', (WidgetTester tester) async {
    final now = DateTime.now();
    final existing = Reminder(
      id: '1234',
      title: 'Antiguo Titulo',
      type: ReminderType.general,
      date: now,
      hour: 10,
      minute: 30,
      recurrence: ReminderRecurrence.daily,
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
    );

    await tester.pumpWidget(buildTestWidget(existingReminder: existing));

    expect(find.text('Antiguo Titulo'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Nuevo Titulo');
    await tester.tap(find.text('Actualizar Recordatorio'));
    await tester.pumpAndSettle();

    final updated = mockReminderProvider.lastUpdatedReminder;
    expect(updated, isNotNull);
    expect(updated!.id, '1234');
    expect(updated.title, 'Nuevo Titulo');
    expect(updated.createdAt, existing.createdAt);
    expect(updated.updatedAt.isAfter(existing.updatedAt), isTrue);
  });

  testWidgets('Scheduler permissionDenied no revierte creación', (WidgetTester tester) async {
    mockReminderProvider.schedulerFailure = const DatabaseFailure('permissionDenied');
    
    await tester.pumpWidget(buildTestWidget());

    await tester.enterText(find.byType(TextFormField).first, 'Test Scheduler');
    
    await tester.tap(find.text('Crear Recordatorio'));
    await tester.pumpAndSettle();

    final created = mockReminderProvider.lastCreatedReminder;
    expect(created, isNotNull);
    expect(created!.title, 'Test Scheduler');
  });
}
