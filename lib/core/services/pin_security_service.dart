import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

class PinSecurityService {
  static const int _iterations = 100000;
  static const int _minIterations = 100000;
  static const int _maxIterations = 5000000;
  static const String _version = 'v1';
  static const String _algorithm = 'pbkdf2-sha256';

  final Random _random = Random.secure();

  Future<String> hashPin(String pin) async {
    final saltBytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    );

    final secretKey = SecretKey(utf8.encode(pin));
    final derivedKey = await pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: saltBytes,
    );

    final hashBytes = await derivedKey.extractBytes();
    final saltBase64 = base64Encode(saltBytes);
    final hashBase64 = base64Encode(hashBytes);

    return '$_version:$_algorithm:$_iterations:$saltBase64:$hashBase64';
  }

  Future<bool> verifyPin(String input, String storedData) async {
    if (!isValidFormat(storedData)) return false;

    try {
      final parts = storedData.split(':');
      final iterString = parts[2];
      final saltBase64 = parts[3];
      final storedHashBase64 = parts[4];

      final iterations = int.tryParse(iterString);
      if (iterations == null || iterations < _minIterations || iterations > _maxIterations) {
        return false;
      }

      final saltBytes = base64Decode(saltBase64);
      if (saltBytes.length != 16) return false;

      final storedHashBytes = base64Decode(storedHashBase64);
      if (storedHashBytes.length != 32) return false;

      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      );

      final secretKey = SecretKey(utf8.encode(input));
      final derivedKey = await pbkdf2.deriveKey(
        secretKey: secretKey,
        nonce: saltBytes,
      );

      final generatedHashBytes = await derivedKey.extractBytes();
      
      if (generatedHashBytes.length != 32) return false;

      return _timingSafeEquals(generatedHashBytes, storedHashBytes);
    } catch (_) {
      return false;
    }
  }

  bool isValidFormat(String data) {
    final parts = data.split(':');
    if (parts.length != 5) return false;
    if (parts[0] != _version) return false;
    if (parts[1] != _algorithm) return false;

    final iterations = int.tryParse(parts[2]);
    if (iterations == null || iterations < _minIterations || iterations > _maxIterations) {
      return false;
    }

    try {
      final saltBytes = base64Decode(parts[3]);
      if (saltBytes.length != 16) return false;

      final hashBytes = base64Decode(parts[4]);
      if (hashBytes.length != 32) return false;
    } catch (_) {
      return false;
    }

    return true;
  }

  bool isLegacyPin(String data) {
    if (data.length != 4) return false;
    return RegExp(r'^[0-9]+$').hasMatch(data);
  }

  bool _timingSafeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
