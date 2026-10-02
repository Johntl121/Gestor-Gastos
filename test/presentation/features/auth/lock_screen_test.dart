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
  Future<bool> authenticate({required String? localizedReason}) =>
      super.noSuchMethod(
          Invocation.method(#authenticate, [], {#localizedReason: localizedReason}),
          returnValue: Future.value(false));
}

class MockPreferencesLocalDataSource extends Mock implements PreferencesLocalDataSource {
  @override
  Future<bool> get isBiometricEnabledAsync => super.noSuchMethod(
      Invocation.getter(#isBiometricEnabledAsync),
      returnValue: Future.value(false));
      
  @override
  bool get isBiometricEnabled => super.noSuchMethod(
      Invocation.getter(#isBiometricEnabled),
      returnValue: false, returnValueForMissingStub: false);
      
  @override
  bool get isNotificationsEnabled => super.noSuchMethod(
      Invocation.getter(#isNotificationsEnabled),
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

class MockPinSecurityService extends Mock implements PinSecurityService {
  @override
  Future<bool> hasPinEnrolled() => super.noSuchMethod(
      Invocation.method(#hasPinEnrolled, []),
      returnValue: Future.value(false));
}

void main() {
  late MockBiometricService mockBiometricService;
  late UiProvider uiProvider;
  late MockPreferencesLocalDataSource mockPrefs;

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

    sl.sl.allowReassignment = true;
    sl.sl.registerLazySingleton<BiometricService>(() => mockBiometricService);
    sl.sl.registerLazySingleton<PreferencesLocalDataSource>(() => mockPrefs);
  });

  Widget buildLockScreen(VoidCallback onUnlocked) {
    return MaterialApp(
      home: ChangeNotifierProvider<UiProvider>.value(
        value: uiProvider,
        child: LockScreen(onUnlocked: onUnlocked),
      ),
    );
  }

  testWidgets('disabled -> authenticate no se llama', (WidgetTester tester) async {
    uiProvider.toggleBiometrics(false);
    
    await tester.pumpWidget(buildLockScreen(() {}));
    await tester.pumpAndSettle();

    verifyNever(mockBiometricService.authenticate(localizedReason: anyNamed('localizedReason')));
  });

  testWidgets('success -> onUnlock', (WidgetTester tester) async {
    uiProvider.toggleBiometrics(true);
    when(mockBiometricService.isSupported()).thenAnswer((_) async => true);
    when(mockBiometricService.hasEnrolledBiometrics()).thenAnswer((_) async => true);
    when(mockBiometricService.authenticate(localizedReason: anyNamed('localizedReason')))
        .thenAnswer((_) async => true);

    bool unlocked = false;
    await tester.pumpWidget(buildLockScreen(() { unlocked = true; }));
    await tester.pumpAndSettle();

    verify(mockBiometricService.authenticate(localizedReason: anyNamed('localizedReason'))).called(1);
    expect(unlocked, isTrue);
  });

  testWidgets('failure -> LockScreen permanece, onUnlock no se llama', (WidgetTester tester) async {
    uiProvider.toggleBiometrics(true);
    when(mockBiometricService.isSupported()).thenAnswer((_) async => true);
    when(mockBiometricService.hasEnrolledBiometrics()).thenAnswer((_) async => true);
    when(mockBiometricService.authenticate(localizedReason: anyNamed('localizedReason')))
        .thenAnswer((_) async => false);

    bool unlocked = false;
    await tester.pumpWidget(buildLockScreen(() { unlocked = true; }));
    await tester.pumpAndSettle();

    verify(mockBiometricService.authenticate(localizedReason: anyNamed('localizedReason'))).called(1);
    expect(unlocked, isFalse);
    expect(find.text('Ingresa tu PIN'), findsOneWidget);
  });

  testWidgets('unsupported -> no prompt', (WidgetTester tester) async {
    uiProvider.toggleBiometrics(true);
    when(mockBiometricService.isSupported()).thenAnswer((_) async => false);

    await tester.pumpWidget(buildLockScreen(() {}));
    await tester.pumpAndSettle();

    verifyNever(mockBiometricService.authenticate(localizedReason: anyNamed('localizedReason')));
  });

  testWidgets('no enrolled -> no prompt', (WidgetTester tester) async {
    uiProvider.toggleBiometrics(true);
    when(mockBiometricService.isSupported()).thenAnswer((_) async => true);
    when(mockBiometricService.hasEnrolledBiometrics()).thenAnswer((_) async => false);

    await tester.pumpWidget(buildLockScreen(() {}));
    await tester.pumpAndSettle();

    verifyNever(mockBiometricService.authenticate(localizedReason: anyNamed('localizedReason')));
  });

  testWidgets('múltiples rebuilds -> authenticate una sola vez', (WidgetTester tester) async {
    uiProvider.toggleBiometrics(true);
    when(mockBiometricService.isSupported()).thenAnswer((_) async => true);
    when(mockBiometricService.hasEnrolledBiometrics()).thenAnswer((_) async => true);
    when(mockBiometricService.authenticate(localizedReason: anyNamed('localizedReason')))
        .thenAnswer((_) async => false);

    await tester.pumpWidget(buildLockScreen(() {}));
    await tester.pumpAndSettle();
    
    // Trigger rebuilds
    await tester.pump();
    await tester.pumpWidget(buildLockScreen(() {}));
    await tester.pumpAndSettle();

    verify(mockBiometricService.authenticate(localizedReason: anyNamed('localizedReason'))).called(1);
  });
}
