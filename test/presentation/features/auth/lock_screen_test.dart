import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/services/biometric_service.dart';
import 'package:gestor_gastos/presentation/features/auth/lock_screen.dart';
import 'package:gestor_gastos/presentation/providers/ui_provider.dart';
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

  @override
  Future<bool> authenticate({required String localizedReason}) =>
      super.noSuchMethod(
          Invocation.method(#authenticate, [], {#localizedReason: localizedReason}),
          returnValue: Future.value(false));
}

class MockPreferencesLocalDataSource extends Mock implements PreferencesLocalDataSource {
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
  Future<String?> getSecurityPinAsync() => super.noSuchMethod(
      Invocation.method(#getSecurityPinAsync, []),
      returnValue: Future.value(null));

  @override
  bool getThemeMode() => super.noSuchMethod(
      Invocation.method(#getThemeMode, []),
      returnValue: false, returnValueForMissingStub: false);
}

class MockNotificationCoordinator extends Mock implements NotificationCoordinator {}

void main() {
  late MockBiometricService mockBiometricService;
  late UiProvider uiProvider;
  late MockPreferencesLocalDataSource mockPrefs;
  late PinSecurityService pinSecurityService;
  late String validHash1234;

  setUp(() async {
    mockBiometricService = MockBiometricService();
    mockPrefs = MockPreferencesLocalDataSource();
    pinSecurityService = PinSecurityService();
    validHash1234 = await pinSecurityService.hashPin('1234');

    when(mockPrefs.saveEnableBiometrics(true)).thenAnswer((_) async {
      when(mockPrefs.getEnableBiometrics()).thenReturn(true);
    });
    when(mockPrefs.saveEnableBiometrics(false)).thenAnswer((_) async {
      when(mockPrefs.getEnableBiometrics()).thenReturn(false);
    });
    when(mockPrefs.getEnableBiometrics()).thenReturn(false);
    when(mockPrefs.migratePinIfNeeded()).thenAnswer((_) async {});
    when(mockPrefs.getSecurityPinAsync()).thenAnswer((_) async => null);
    when(mockPrefs.getThemeMode()).thenReturn(false);
    when(mockPrefs.getEnableNotifications()).thenReturn(false);
    when(mockPrefs.getUserAvatar()).thenReturn('assets/images/avatars/avatar1.png');
    when(mockPrefs.getUserName()).thenReturn('Usuario');
    when(mockPrefs.getProfileImagePath()).thenReturn(null);

    uiProvider = UiProvider(
      preferencesLocalDataSource: mockPrefs,
      notificationCoordinator: MockNotificationCoordinator(),
      pinSecurityService: pinSecurityService,
    );

    sl.sl.allowReassignment = true;
    sl.sl.registerLazySingleton<BiometricService>(() => mockBiometricService);
    sl.sl.registerLazySingleton<PreferencesLocalDataSource>(() => mockPrefs);
    sl.sl.registerLazySingleton<PinSecurityService>(() => pinSecurityService);
  });

  Widget buildLockScreen(VoidCallback onUnlocked) {
    return MaterialApp(
      home: ChangeNotifierProvider<UiProvider>.value(
        value: uiProvider,
        child: LockScreen(onUnlocked: onUnlocked),
      ),
    );
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (int i = 0; i < pin.length; i++) {
      await tester.tap(find.text(pin[i]));
      await tester.pump();
    }
  }

  group('Biometría en LockScreen', () {
    testWidgets('disabled -> authenticate no se llama', (WidgetTester tester) async {
      when(mockPrefs.getEnableBiometrics()).thenReturn(false);

      await tester.pumpWidget(buildLockScreen(() {}));
      await tester.pumpAndSettle();

      verifyNever(mockBiometricService.authenticate(localizedReason: 'Desbloquee para acceder a sus gastos'));
    });

    testWidgets('success -> onUnlock', (WidgetTester tester) async {
      when(mockPrefs.getEnableBiometrics()).thenReturn(true);
      when(mockBiometricService.isSupported()).thenAnswer((_) async => true);
      when(mockBiometricService.hasEnrolledBiometrics()).thenAnswer((_) async => true);
      when(mockBiometricService.authenticate(localizedReason: 'Desbloquee para acceder a sus gastos'))
          .thenAnswer((_) async => true);

      bool unlocked = false;
      await tester.pumpWidget(buildLockScreen(() { unlocked = true; }));
      await tester.pumpAndSettle();

      verify(mockBiometricService.authenticate(localizedReason: 'Desbloquee para acceder a sus gastos')).called(1);
      expect(unlocked, isTrue);
    });

    testWidgets('failure -> LockScreen permanece, onUnlock no se llama', (WidgetTester tester) async {
      when(mockPrefs.getEnableBiometrics()).thenReturn(true);
      when(mockBiometricService.isSupported()).thenAnswer((_) async => true);
      when(mockBiometricService.hasEnrolledBiometrics()).thenAnswer((_) async => true);
      when(mockBiometricService.authenticate(localizedReason: 'Desbloquee para acceder a sus gastos'))
          .thenAnswer((_) async => false);

      bool unlocked = false;
      await tester.pumpWidget(buildLockScreen(() { unlocked = true; }));
      await tester.pumpAndSettle();

      verify(mockBiometricService.authenticate(localizedReason: 'Desbloquee para acceder a sus gastos')).called(1);
      expect(unlocked, isFalse);
      expect(find.text('Ingresa tu PIN'), findsOneWidget);
    });

    testWidgets('unsupported -> no prompt', (WidgetTester tester) async {
      when(mockPrefs.getEnableBiometrics()).thenReturn(true);
      when(mockBiometricService.isSupported()).thenAnswer((_) async => false);

      await tester.pumpWidget(buildLockScreen(() {}));
      await tester.pumpAndSettle();

      verifyNever(mockBiometricService.authenticate(localizedReason: 'Desbloquee para acceder a sus gastos'));
    });

    testWidgets('no enrolled -> no prompt', (WidgetTester tester) async {
      when(mockPrefs.getEnableBiometrics()).thenReturn(true);
      when(mockBiometricService.isSupported()).thenAnswer((_) async => true);
      when(mockBiometricService.hasEnrolledBiometrics()).thenAnswer((_) async => false);

      await tester.pumpWidget(buildLockScreen(() {}));
      await tester.pumpAndSettle();

      verifyNever(mockBiometricService.authenticate(localizedReason: 'Desbloquee para acceder a sus gastos'));
    });

    testWidgets('múltiples rebuilds -> authenticate una sola vez', (WidgetTester tester) async {
      when(mockPrefs.getEnableBiometrics()).thenReturn(true);
      when(mockBiometricService.isSupported()).thenAnswer((_) async => true);
      when(mockBiometricService.hasEnrolledBiometrics()).thenAnswer((_) async => true);
      when(mockBiometricService.authenticate(localizedReason: 'Desbloquee para acceder a sus gastos'))
          .thenAnswer((_) async => false);

      await tester.pumpWidget(buildLockScreen(() {}));
      await tester.pumpAndSettle();

      // Trigger rebuilds
      await tester.pump();
      await tester.pumpWidget(buildLockScreen(() {}));
      await tester.pumpAndSettle();

      verify(mockBiometricService.authenticate(localizedReason: 'Desbloquee para acceder a sus gastos')).called(1);
    });

    testWidgets('biometría cancelada -> fallback al PIN permanece disponible y funcional', (WidgetTester tester) async {
      when(mockPrefs.getEnableBiometrics()).thenReturn(true);
      when(mockPrefs.getSecurityPinAsync()).thenAnswer((_) async => validHash1234);
      when(mockBiometricService.isSupported()).thenAnswer((_) async => true);
      when(mockBiometricService.hasEnrolledBiometrics()).thenAnswer((_) async => true);
      when(mockBiometricService.authenticate(localizedReason: 'Desbloquee para acceder a sus gastos'))
          .thenAnswer((_) async => false); // Usuario cancela biometría

      bool unlocked = false;
      await tester.pumpWidget(buildLockScreen(() { unlocked = true; }));
      await tester.pumpAndSettle();

      expect(unlocked, isFalse);
      expect(find.text('Ingresa tu PIN'), findsOneWidget);

      // Proceder con PIN manual
      await enterPin(tester, '1234');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(unlocked, isTrue);
    });
  });

  group('Verificación de PIN en LockScreen', () {
    testWidgets('PIN correcto contra hash PBKDF2 válido -> desbloquea', (WidgetTester tester) async {
      when(mockPrefs.getSecurityPinAsync()).thenAnswer((_) async => validHash1234);

      bool unlocked = false;
      await tester.pumpWidget(buildLockScreen(() { unlocked = true; }));
      await tester.pumpAndSettle();

      await enterPin(tester, '1234');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(unlocked, isTrue);
      expect(find.text("PIN Incorrecto"), findsNothing);
    });

    testWidgets('PIN incorrecto contra hash PBKDF2 válido -> permanece bloqueado y muestra error', (WidgetTester tester) async {
      when(mockPrefs.getSecurityPinAsync()).thenAnswer((_) async => validHash1234);

      bool unlocked = false;
      await tester.pumpWidget(buildLockScreen(() { unlocked = true; }));
      await tester.pumpAndSettle();

      await enterPin(tester, '9999');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(unlocked, isFalse);
      expect(find.text("PIN Incorrecto"), findsOneWidget);
    });

    testWidgets('Hash corrupto / inválido -> fail-closed: permanece bloqueado', (WidgetTester tester) async {
      when(mockPrefs.getSecurityPinAsync()).thenAnswer((_) async => 'formato:invalido:corrupto');

      bool unlocked = false;
      await tester.pumpWidget(buildLockScreen(() { unlocked = true; }));
      await tester.pumpAndSettle();

      await enterPin(tester, '1234');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(unlocked, isFalse);
      expect(find.text("PIN Incorrecto"), findsOneWidget);
    });

    testWidgets('Error al leer SecureStorage -> fail-closed: muestra error y permanece bloqueado', (WidgetTester tester) async {
      when(mockPrefs.getSecurityPinAsync()).thenThrow(Exception('Secure storage read error'));

      bool unlocked = false;
      await tester.pumpWidget(buildLockScreen(() { unlocked = true; }));
      await tester.pumpAndSettle();

      await enterPin(tester, '1234');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(unlocked, isFalse);
      expect(find.text("Error al verificar PIN"), findsOneWidget);
    });

    testWidgets('Compatibilidad con PIN legacy (4 dígitos texto plano) -> desbloquea', (WidgetTester tester) async {
      when(mockPrefs.getSecurityPinAsync()).thenAnswer((_) async => '1234');

      bool unlocked = false;
      await tester.pumpWidget(buildLockScreen(() { unlocked = true; }));
      await tester.pumpAndSettle();

      await enterPin(tester, '1234');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(unlocked, isTrue);
    });

    testWidgets('Protección contra verificaciones concurrentes y múltiples toques durante validación', (WidgetTester tester) async {
      when(mockPrefs.getSecurityPinAsync()).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return validHash1234;
      });

      bool unlocked = false;
      await tester.pumpWidget(buildLockScreen(() { unlocked = true; }));
      await tester.pumpAndSettle();

      // Ingresar los 4 dígitos
      await enterPin(tester, '1234');
      await tester.pump(const Duration(milliseconds: 160)); // Comienza _validatePin (delay 150ms)

      // Intentar presionar más teclas mientras está validando
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('6'));
      await tester.pump();

      // Completar verificación
      await tester.pumpAndSettle();

      expect(unlocked, isTrue);
    });
  });
}
