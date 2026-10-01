import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/services/pin_security_service.dart';

void main() {
  late PinSecurityService pinSecurityService;

  setUp(() {
    pinSecurityService = PinSecurityService();
  });

  group('PinSecurityService', () {
    test('set + verify correcto', () async {
      const pin = '1234';
      final storedData = await pinSecurityService.hashPin(pin);
      
      expect(pinSecurityService.isValidFormat(storedData), isTrue);
      
      final isVerified = await pinSecurityService.verifyPin(pin, storedData);
      expect(isVerified, isTrue);
    });

    test('PIN incorrecto', () async {
      const pin = '1234';
      final storedData = await pinSecurityService.hashPin(pin);
      
      final isVerified = await pinSecurityService.verifyPin('4321', storedData);
      expect(isVerified, isFalse);
    });

    test('mismo PIN con salts diferentes produce hashes diferentes', () async {
      const pin = '1234';
      final storedData1 = await pinSecurityService.hashPin(pin);
      final storedData2 = await pinSecurityService.hashPin(pin);
      
      expect(storedData1, isNot(equals(storedData2)));
      
      // Both should verify correctly
      expect(await pinSecurityService.verifyPin(pin, storedData1), isTrue);
      expect(await pinSecurityService.verifyPin(pin, storedData2), isTrue);
    });

    test('PIN plano nunca queda persistido', () async {
      const pin = '1234';
      final storedData = await pinSecurityService.hashPin(pin);
      
      expect(storedData.contains(pin), isFalse);
    });

    test('formato corrupto -> false', () async {
      final isVerified = await pinSecurityService.verifyPin('1234', 'corrupt:format:data');
      expect(isVerified, isFalse);
    });

    test('Base64 inválido -> false', () async {
      const storedData = 'v1:pbkdf2-sha256:100000:invalid_base64:invalid_base64';
      final isVerified = await pinSecurityService.verifyPin('1234', storedData);
      expect(isVerified, isFalse);
    });

    test('iteraciones fuera de rango -> false', () async {
      const pin = '1234';
      const storedData = 'v1:pbkdf2-sha256:100:c29tZXNhbHQ=:c29tZWhhc2g=';
      final isVerified = await pinSecurityService.verifyPin(pin, storedData);
      expect(isVerified, isFalse);
    });

    test('salt con longitud inválida -> false', () async {
      const pin = '1234';
      const storedData = 'v1:pbkdf2-sha256:100000:c29tZQ==:c29tZWhhc2g='; // some bytes only
      final isVerified = await pinSecurityService.verifyPin(pin, storedData);
      expect(isVerified, isFalse);
    });

    test('hash con longitud inválida -> false', () async {
      const pin = '1234';
      const storedData = 'v1:pbkdf2-sha256:100000:c29tZXNhbHQxMjM0NTY=:c29tZWhhc2g=';
      final isVerified = await pinSecurityService.verifyPin(pin, storedData);
      expect(isVerified, isFalse);
    });
  });
}
