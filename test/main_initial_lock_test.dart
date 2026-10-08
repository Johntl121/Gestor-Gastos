import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gestor_gastos/main.dart';
import 'package:gestor_gastos/injection_container.dart' as di;
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';
import 'package:gestor_gastos/presentation/providers/ui_provider.dart';
import 'package:gestor_gastos/presentation/providers/wallet_provider.dart';
import 'package:gestor_gastos/presentation/providers/transaction_provider.dart';
import 'package:gestor_gastos/presentation/providers/subscription_provider.dart';
import 'package:gestor_gastos/presentation/providers/reminder_provider.dart';
import 'package:gestor_gastos/presentation/providers/goal_provider.dart';
import 'package:gestor_gastos/presentation/providers/coach_provider.dart';
import 'package:gestor_gastos/presentation/providers/stats_provider.dart';

class MockPreferences extends Mock implements PreferencesLocalDataSource {}
class MockUiProvider extends Mock with ChangeNotifier implements UiProvider {}
class MockWalletProvider extends Mock with ChangeNotifier implements WalletProvider {}
class MockTransactionProvider extends Mock with ChangeNotifier implements TransactionProvider {}
class MockSubscriptionProvider extends Mock with ChangeNotifier implements SubscriptionProvider {}
class MockReminderProvider extends Mock with ChangeNotifier implements ReminderProvider {}
class MockGoalProvider extends Mock with ChangeNotifier implements GoalProvider {}
class MockCoachProvider extends Mock with ChangeNotifier implements CoachProvider {}
class MockStatsProvider extends Mock with ChangeNotifier implements StatsProvider {}

void main() {
  setUpAll(() {
    registerFallbackValue(MockWalletProvider());
  });

  late MockPreferences mockPrefs;

  setUp(() async {
    await di.sl.reset();
    mockPrefs = MockPreferences();
    when(() => mockPrefs.getEnableBiometrics()).thenReturn(false);

    final ui = MockUiProvider();
    when(() => ui.isDarkMode).thenReturn(false);
    when(() => ui.enableBiometrics).thenReturn(false);
    when(() => ui.currentIndex).thenReturn(0);
    when(() => ui.isPinEnabled).thenReturn(false);
    when(() => ui.userAvatar).thenReturn('');
    when(() => ui.userName).thenReturn('Usuario');

    final wp = MockWalletProvider();
    when(() => wp.initApp()).thenAnswer((_) => Future.value());
    when(() => wp.loadWalletData()).thenAnswer((_) => Future.value());
    when(() => wp.accounts).thenReturn([]);
    when(() => wp.currencySymbol).thenReturn('S/');
    when(() => wp.budgetLimit).thenReturn(0.0);
    when(() => wp.totalBalance).thenReturn(0.0);

    final tp = MockTransactionProvider();
    when(() => tp.transactions).thenReturn([]);
    when(() => tp.loadTransactions()).thenAnswer((_) => Future.value());

    final sub = MockSubscriptionProvider();
    when(() => sub.subscriptions).thenReturn([]);

    final rem = MockReminderProvider();
    when(() => rem.overdue).thenReturn([]);
    when(() => rem.upcoming).thenReturn([]);
    when(() => rem.isLoading).thenReturn(false);

    final goal = MockGoalProvider();
    when(() => goal.goals).thenReturn([]);
    final coach = MockCoachProvider();
    when(() => coach.canRequestAnalysis(any())).thenReturn(false);

    final stats = MockStatsProvider();
    when(() => stats.setAllTransactions(any())).thenReturn(null);
    when(() => stats.updateWalletProvider(any())).thenReturn(null);
    when(() => stats.getSpendingByCategory(any())).thenReturn([]);
    when(() => stats.calculateTotalAmount(any())).thenReturn(0.0);
    when(() => stats.currencySymbol).thenReturn('S/');
    when(() => stats.currentStatsType).thenReturn(StatsType.expense);
    when(() => stats.currentStatsPeriod).thenReturn(PeriodType.month);
    when(() => stats.currentStatsDate).thenReturn(DateTime.now());

    di.sl.registerLazySingleton<PreferencesLocalDataSource>(() => mockPrefs);
    di.sl.registerLazySingleton<UiProvider>(() => ui);
    di.sl.registerLazySingleton<WalletProvider>(() => wp);
    di.sl.registerLazySingleton<TransactionProvider>(() => tp);
    di.sl.registerLazySingleton<SubscriptionProvider>(() => sub);
    di.sl.registerLazySingleton<ReminderProvider>(() => rem);
    di.sl.registerLazySingleton<GoalProvider>(() => goal);
    di.sl.registerLazySingleton<CoachProvider>(() => coach);
    di.sl.registerLazySingleton<StatsProvider>(() => stats);
  });

  tearDown(() async {
    await di.sl.reset();
  });

  testWidgets('mientras getSecurityPinAsync está pendiente -> MainPage NO aparece', (tester) async {
    final completer = Completer<String?>();
    when(() => mockPrefs.getSecurityPinAsync()).thenAnswer((_) => completer.future);

    await tester.pumpWidget(const MyApp(isFirstTime: false));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text("Balance Actual"), findsNothing);
  });

  testWidgets('PIN existe -> después de resolver aparece LockScreen', (tester) async {
    final completer = Completer<String?>();
    when(() => mockPrefs.getSecurityPinAsync()).thenAnswer((_) => completer.future);

    await tester.pumpWidget(const MyApp(isFirstTime: false));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete("1234");
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text("Error de seguridad local."), findsNothing);
  });

  testWidgets('PIN no existe -> después de resolver aparece MainPage', (tester) async {
    final completer = Completer<String?>();
    when(() => mockPrefs.getSecurityPinAsync()).thenAnswer((_) => completer.future);

    await tester.pumpWidget(const MyApp(isFirstTime: false));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text("Error de seguridad local."), findsNothing);
  });

  testWidgets('lectura de seguridad falla -> MainPage NO aparece, falla seguro', (tester) async {
    when(() => mockPrefs.getSecurityPinAsync()).thenAnswer((_) => Future.error(Exception("Simulated error")));

    await tester.pumpWidget(const MyApp(isFirstTime: false));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text("Error de seguridad local."), findsOneWidget);
  });
}
