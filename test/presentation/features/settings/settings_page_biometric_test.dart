import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/services/biometric_service.dart';
import 'package:gestor_gastos/presentation/features/settings/settings_page.dart';
import 'package:gestor_gastos/presentation/providers/ui_provider.dart';
import 'package:gestor_gastos/presentation/providers/wallet_provider.dart';
import 'package:gestor_gastos/presentation/providers/transaction_provider.dart';
import 'package:provider/provider.dart';
import 'package:gestor_gastos/data/datasources/preferences_local_data_source.dart';
import 'package:gestor_gastos/core/services/notification_coordinator.dart';
import 'package:gestor_gastos/core/services/pin_security_service.dart';
import 'package:gestor_gastos/injection_container.dart' as sl;
import 'package:mockito/mockito.dart';

class MockBiometricService extends Mock implements BiometricService {
  @override
  Future<bool> isSupported() => super.noSuchMethod(
      Invocation.method(#isSupported, []),
      returnValue: Future.value(false));

  @override
  Future<bool> hasEnrolledBiometrics() => super.noSuchMethod(
      Invocation.method(#hasEnrolledBiometrics, []),
      returnValue: Future.value(false));
}

class MockPreferencesLocalDataSource extends Mock implements PreferencesLocalDataSource {
  @override
  Future<String?> getSecurityPinAsync() => super.noSuchMethod(
      Invocation.method(#getSecurityPinAsync, []),
      returnValue: Future.value(null));
      
  bool get isBiometricEnabled => super.noSuchMethod(
      Invocation.getter(#isBiometricEnabled),
      returnValue: false, returnValueForMissingStub: false);
      
@override
  String getCurrency() => super.noSuchMethod(
      Invocation.method(#getCurrency, []),
      returnValue: 'PEN');
      
  @override
  bool getEnableBiometrics() => super.noSuchMethod(
      Invocation.method(#getEnableBiometrics, []),
      returnValue: false, returnValueForMissingStub: false);
      
  @override
  bool getEnableNotifications() => super.noSuchMethod(
      Invocation.method(#getEnableNotifications, []),
      returnValue: false, returnValueForMissingStub: false);

  @override
  Future<void> migratePinIfNeeded() => super.noSuchMethod(
      Invocation.method(#migratePinIfNeeded, []),
      returnValue: Future<void>.value(), returnValueForMissingStub: Future<void>.value());

  @override
  Future<void> saveEnableBiometrics(bool enable) => super.noSuchMethod(
      Invocation.method(#saveEnableBiometrics, [enable]),
      returnValue: Future<void>.value(), returnValueForMissingStub: Future<void>.value());

  @override
  String? getUserName() => super.noSuchMethod(
      Invocation.method(#getUserName, []),
      returnValue: null);

  @override
  String getUserAvatar() => super.noSuchMethod(
      Invocation.method(#getUserAvatar, []),
      returnValue: 'assets/images/avatars/avatar1.png', returnValueForMissingStub: 'assets/images/avatars/avatar1.png');

  @override
  String? getProfileImagePath() => super.noSuchMethod(
      Invocation.method(#getProfileImagePath, []),
      returnValue: null);

  @override
  bool getThemeMode() => super.noSuchMethod(
      Invocation.method(#getThemeMode, []),
      returnValue: false, returnValueForMissingStub: false);
}

class MockWalletProvider extends Mock implements WalletProvider {
  @override
  String get currencySymbol => super.noSuchMethod(
      Invocation.getter(#currencySymbol),
      returnValue: '\$', returnValueForMissingStub: '\$');

  @override
  double get budgetLimit => super.noSuchMethod(
      Invocation.getter(#budgetLimit),
      returnValue: 1000.0, returnValueForMissingStub: 1000.0);
}
class MockTransactionProvider extends Mock implements TransactionProvider {}

class MockNotificationCoordinator extends Mock implements NotificationCoordinator {}
class MockPinSecurityService extends Mock implements PinSecurityService {
}

void main() {
  late MockBiometricService mockBiometricService;
  late UiProvider uiProvider;
  late MockPreferencesLocalDataSource mockPrefs;
  late MockWalletProvider mockWalletProvider;
  late MockTransactionProvider mockTransactionProvider;

  setUp(() {
    mockBiometricService = MockBiometricService();
    mockPrefs = MockPreferencesLocalDataSource();
    
    sl.sl.allowReassignment = true;
    when(mockPrefs.saveEnableBiometrics(true)).thenAnswer((_) async {});
    when(mockPrefs.saveEnableBiometrics(false)).thenAnswer((_) async {});
    when(mockPrefs.migratePinIfNeeded()).thenAnswer((_) async {});
    when(mockPrefs.getSecurityPinAsync()).thenAnswer((_) async => null);
    when(mockPrefs.getThemeMode()).thenReturn(false);
    when(mockPrefs.getEnableBiometrics()).thenReturn(false);
    when(mockPrefs.getEnableNotifications()).thenReturn(false);
    when(mockPrefs.getUserAvatar()).thenReturn('assets/images/avatars/avatar1.png');
    when(mockPrefs.getUserName()).thenReturn('Usuario');
    when(mockPrefs.getProfileImagePath()).thenReturn(null);
    
    uiProvider = UiProvider(
      preferencesLocalDataSource: mockPrefs,
      notificationCoordinator: MockNotificationCoordinator(),
      pinSecurityService: MockPinSecurityService(),
    );
    mockWalletProvider = MockWalletProvider();
    mockTransactionProvider = MockTransactionProvider();

    sl.sl.allowReassignment = true;
    sl.sl.registerLazySingleton<BiometricService>(() => mockBiometricService);
    sl.sl.registerLazySingleton<PreferencesLocalDataSource>(() => mockPrefs);
  });

  Widget buildSettingsPage() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<UiProvider>.value(value: uiProvider),
          ChangeNotifierProvider<WalletProvider>.value(value: mockWalletProvider),
          ChangeNotifierProvider<TransactionProvider>.value(value: mockTransactionProvider),
        ],
        child: const SettingsPage(),
      ),
    );
  }

  testWidgets('settings sin PIN -> no habilita', (WidgetTester tester) async {
    uiProvider.toggleBiometrics(false);
    when(mockPrefs.getSecurityPinAsync()).thenAnswer((_) async => null);

    await tester.pumpWidget(buildSettingsPage());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Face ID / Touch ID'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Face ID / Touch ID'));
    await tester.pump();

    expect(uiProvider.enableBiometrics, isFalse);
    expect(find.text('❌ Configure un PIN de seguridad primero'), findsOneWidget);
  });

  testWidgets('unsupported -> no habilita', (WidgetTester tester) async {
    uiProvider.toggleBiometrics(false);
    when(mockPrefs.getSecurityPinAsync()).thenAnswer((_) async => '1234');
    when(mockBiometricService.isSupported()).thenAnswer((_) async => false);

    await tester.pumpWidget(buildSettingsPage());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Face ID / Touch ID'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Face ID / Touch ID'));
    await tester.pump();

    expect(uiProvider.enableBiometrics, isFalse);
    expect(find.text('❌ Dispositivo no compatible con biometría'), findsOneWidget);
  });

  testWidgets('no enrolled -> no habilita', (WidgetTester tester) async {
    uiProvider.toggleBiometrics(false);
    when(mockPrefs.getSecurityPinAsync()).thenAnswer((_) async => '1234');
    when(mockBiometricService.isSupported()).thenAnswer((_) async => true);
    when(mockBiometricService.hasEnrolledBiometrics()).thenAnswer((_) async => false);

    await tester.pumpWidget(buildSettingsPage());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Face ID / Touch ID'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Face ID / Touch ID'));
    await tester.pump();

    expect(uiProvider.enableBiometrics, isFalse);
    expect(find.text('❌ Debe enrolar su huella/rostro en los ajustes del dispositivo'), findsOneWidget);
  });

  testWidgets('condiciones válidas -> habilita', (WidgetTester tester) async {
    uiProvider.toggleBiometrics(false);
    when(mockPrefs.getSecurityPinAsync()).thenAnswer((_) async => '1234');
    when(mockBiometricService.isSupported()).thenAnswer((_) async => true);
    when(mockBiometricService.hasEnrolledBiometrics()).thenAnswer((_) async => true);

    await tester.pumpWidget(buildSettingsPage());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Face ID / Touch ID'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Face ID / Touch ID'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Face ID / Touch ID'));
    await tester.pump();

    expect(uiProvider.enableBiometrics, isTrue);
  });

  testWidgets('desactivar -> funciona directamente sin validación', (WidgetTester tester) async {
    uiProvider.toggleBiometrics(true);

    await tester.pumpWidget(buildSettingsPage());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Face ID / Touch ID'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Face ID / Touch ID'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Face ID / Touch ID'));
    await tester.pump();

    expect(uiProvider.enableBiometrics, isFalse);
     
  });
}
