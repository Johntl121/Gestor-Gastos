import 'package:local_auth/local_auth.dart';

abstract class BiometricService {
  Future<bool> isSupported();
  Future<bool> hasEnrolledBiometrics();
  Future<bool> authenticate({required String localizedReason});
}

class BiometricServiceImpl implements BiometricService {
  final LocalAuthentication _localAuth;

  BiometricServiceImpl({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<bool> isSupported() async {
    try {
      return await _localAuth.isDeviceSupported() || await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> hasEnrolledBiometrics() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: false,
      );
    } catch (e) {
      return false;
    }
  }
}
