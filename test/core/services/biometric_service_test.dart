import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/services/biometric_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {
  @override
  Future<bool> isDeviceSupported() =>
      super.noSuchMethod(Invocation.method(#isDeviceSupported, []),
          returnValue: Future.value(false));

  @override
  Future<bool> get canCheckBiometrics =>
      super.noSuchMethod(Invocation.getter(#canCheckBiometrics),
          returnValue: Future.value(false));

  @override
  Future<List<BiometricType>> getAvailableBiometrics() =>
      super.noSuchMethod(Invocation.method(#getAvailableBiometrics, []),
          returnValue: Future.value(<BiometricType>[]));

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) =>
      super.noSuchMethod(
          Invocation.method(#authenticate, [], {
            #localizedReason: localizedReason,
            #authMessages: authMessages,
            #biometricOnly: biometricOnly,
            #sensitiveTransaction: sensitiveTransaction,
            #persistAcrossBackgrounding: persistAcrossBackgrounding,
          }),
          returnValue: Future.value(false));
}

void main() {
  late MockLocalAuthentication mockLocalAuth;
  late BiometricServiceImpl biometricService;

  setUp(() {
    mockLocalAuth = MockLocalAuthentication();
    biometricService = BiometricServiceImpl(localAuth: mockLocalAuth);
  });

  group('BiometricService', () {
    test('isSupported', () async {
      when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
      expect(await biometricService.isSupported(), isTrue);
    });

    test('hasEnrolledBiometrics', () async {
      when(mockLocalAuth.getAvailableBiometrics())
          .thenAnswer((_) async => [BiometricType.fingerprint]);
      expect(await biometricService.hasEnrolledBiometrics(), isTrue);
    });

    test('authenticate success', () async {
      when(mockLocalAuth.authenticate(
        localizedReason: 'Test',
        biometricOnly: true,
        persistAcrossBackgrounding: false,
      )).thenAnswer((_) async => true);
      expect(
          await biometricService.authenticate(localizedReason: 'Test'), isTrue);
    });

    test('authenticate failure', () async {
      when(mockLocalAuth.authenticate(
        localizedReason: 'Test',
        biometricOnly: true,
        persistAcrossBackgrounding: false,
      )).thenAnswer((_) async => false);
      expect(await biometricService.authenticate(localizedReason: 'Test'),
          isFalse);
    });
  });
}
