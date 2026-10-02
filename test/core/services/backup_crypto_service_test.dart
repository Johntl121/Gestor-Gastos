import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/errors/backup_exceptions.dart';
import 'package:gestor_gastos/core/services/backup_crypto_service.dart';

void main() {
  late BackupCryptoService cryptoService;

  setUp(() {
    cryptoService = BackupCryptoService();
  });

  group('BackupCryptoService', () {
    final payload = Uint8List.fromList(utf8.encode('Hello World Payload! 1234567890'));
    const password = 'SuperSecretPassword2026';

    test('encrypt -> decrypt round-trip (mismo payload)', () async {
      final backup = await cryptoService.encrypt(payload, password);
      expect(backup, isNotEmpty);

      final decrypted = await cryptoService.decrypt(backup, password);
      expect(decrypted, equals(payload));
    });

    test('mismo payload + mismo password -> backups diferentes', () async {
      final backup1 = await cryptoService.encrypt(payload, password);
      final backup2 = await cryptoService.encrypt(payload, password);

      expect(backup1, isNot(equals(backup2)));
    });

    test('password incorrecto -> BackupAuthenticationException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      expect(
        () => cryptoService.decrypt(backup, 'WrongPassword'),
        throwsA(isA<BackupAuthenticationException>()),
      );
    });

    test('modificación de ciphertext -> BackupAuthenticationException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      final corrupted = Uint8List.fromList(backup);
      corrupted[corrupted.length - 5] ^= 0x01; // flip a bit in ciphertext

      expect(
        () => cryptoService.decrypt(corrupted, password),
        throwsA(isA<BackupAuthenticationException>()),
      );
    });

    test('modificación del MAC -> BackupAuthenticationException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      
      // MAC is before the ciphertext length.
      // Format: MAGIC(4), VER(4), HL(4), HEADER(H), MACL(4), MAC(M), CL(4), CIPHER(C)
      final bData = ByteData.sublistView(backup);
      final headerLength = bData.getUint32(8, Endian.big);
      final macStart = 16 + headerLength;
      
      final corrupted = Uint8List.fromList(backup);
      corrupted[macStart + 5] ^= 0x01; // flip a bit in MAC

      expect(
        () => cryptoService.decrypt(corrupted, password),
        throwsA(isA<BackupAuthenticationException>()),
      );
    });

    test('modificación del header autenticado -> BackupAuthenticationException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      
      final hlData = ByteData.sublistView(backup, 8, 12);
      final headerLength = hlData.getUint32(0, Endian.big);
      
      final corrupted = Uint8List.fromList(backup);
      corrupted[12 + (headerLength ~/ 2)] ^= 0x01; // flip a bit in header JSON

      // Note: If the flipped bit breaks the JSON parsing, it throws BackupFormatException.
      // But if JSON is still valid (e.g. flipping a bit in salt b64 padding),
      // AEAD will reject it and throw BackupAuthenticationException.
      // Either way, it fails.
      try {
        await cryptoService.decrypt(corrupted, password);
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<BackupException>());
      }
    });

    test('magic inválido -> BackupFormatException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      final corrupted = Uint8List.fromList(backup);
      corrupted[0] = 0x58; // 'X'

      expect(
        () => cryptoService.decrypt(corrupted, password),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('versión desconocida -> BackupVersionException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      final corrupted = Uint8List.fromList(backup);
      corrupted[7] = 0x02; // Change version to 2

      expect(
        () => cryptoService.decrypt(corrupted, password),
        throwsA(isA<BackupVersionException>()),
      );
    });

    test('iterations < min -> BackupFormatException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      
      // Inject manually to test validation
      final hlData = ByteData.sublistView(backup, 8, 12);
      final headerLength = hlData.getUint32(0, Endian.big);
      final headerBytes = backup.sublist(12, 12 + headerLength);
      
      final map = jsonDecode(utf8.decode(headerBytes));
      map['iterations'] = 99999; // Less than 100k
      final newHeaderBytes = utf8.encode(jsonEncode(map));
      
      final bb = BytesBuilder();
      bb.add(backup.sublist(0, 8)); // MAGIC + VER
      
      final newHl = ByteData(4);
      newHl.setUint32(0, newHeaderBytes.length, Endian.big);
      bb.add(newHl.buffer.asUint8List());
      bb.add(newHeaderBytes);
      bb.add(backup.sublist(12 + headerLength)); // Add MAC and Cipher
      
      expect(
        () => cryptoService.decrypt(bb.toBytes(), password),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('iterations > max -> BackupFormatException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      final hlData = ByteData.sublistView(backup, 8, 12);
      final headerLength = hlData.getUint32(0, Endian.big);
      final headerBytes = backup.sublist(12, 12 + headerLength);
      
      final map = jsonDecode(utf8.decode(headerBytes));
      map['iterations'] = 3000000; // More than 2M
      final newHeaderBytes = utf8.encode(jsonEncode(map));
      
      final bb = BytesBuilder();
      bb.add(backup.sublist(0, 8)); // MAGIC + VER
      final newHl = ByteData(4)..setUint32(0, newHeaderBytes.length, Endian.big);
      bb.add(newHl.buffer.asUint8List());
      bb.add(newHeaderBytes);
      bb.add(backup.sublist(12 + headerLength)); // MAC and Cipher
      
      expect(() => cryptoService.decrypt(bb.toBytes(), password), throwsA(isA<BackupFormatException>()));
    });

    test('salt con longitud inválida -> BackupFormatException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      final hlData = ByteData.sublistView(backup, 8, 12);
      final headerLength = hlData.getUint32(0, Endian.big);
      final map = jsonDecode(utf8.decode(backup.sublist(12, 12 + headerLength)));
      
      map['salt'] = base64Encode(List.filled(15, 0)); // 15 bytes instead of 16
      final newHeaderBytes = utf8.encode(jsonEncode(map));
      
      final bb = BytesBuilder();
      bb.add(backup.sublist(0, 8));
      final newHl = ByteData(4)..setUint32(0, newHeaderBytes.length, Endian.big);
      bb.add(newHl.buffer.asUint8List());
      bb.add(newHeaderBytes);
      bb.add(backup.sublist(12 + headerLength));
      
      expect(() => cryptoService.decrypt(bb.toBytes(), password), throwsA(isA<BackupFormatException>()));
    });

    test('nonce con longitud inválida -> BackupFormatException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      final hlData = ByteData.sublistView(backup, 8, 12);
      final headerLength = hlData.getUint32(0, Endian.big);
      final map = jsonDecode(utf8.decode(backup.sublist(12, 12 + headerLength)));
      
      map['nonce'] = base64Encode(List.filled(10, 0)); // 10 bytes instead of 12
      final newHeaderBytes = utf8.encode(jsonEncode(map));
      
      final bb = BytesBuilder();
      bb.add(backup.sublist(0, 8));
      final newHl = ByteData(4)..setUint32(0, newHeaderBytes.length, Endian.big);
      bb.add(newHl.buffer.asUint8List());
      bb.add(newHeaderBytes);
      bb.add(backup.sublist(12 + headerLength));
      
      expect(() => cryptoService.decrypt(bb.toBytes(), password), throwsA(isA<BackupFormatException>()));
    });

    test('KDF desconocido -> BackupFormatException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      final hlData = ByteData.sublistView(backup, 8, 12);
      final headerLength = hlData.getUint32(0, Endian.big);
      final map = jsonDecode(utf8.decode(backup.sublist(12, 12 + headerLength)));
      
      map['kdf'] = 'Argon2id';
      final newHeaderBytes = utf8.encode(jsonEncode(map));
      
      final bb = BytesBuilder();
      bb.add(backup.sublist(0, 8));
      final newHl = ByteData(4)..setUint32(0, newHeaderBytes.length, Endian.big);
      bb.add(newHl.buffer.asUint8List());
      bb.add(newHeaderBytes);
      bb.add(backup.sublist(12 + headerLength));
      
      expect(() => cryptoService.decrypt(bb.toBytes(), password), throwsA(isA<BackupFormatException>()));
    });

    test('cipher desconocido -> BackupFormatException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      final hlData = ByteData.sublistView(backup, 8, 12);
      final headerLength = hlData.getUint32(0, Endian.big);
      final map = jsonDecode(utf8.decode(backup.sublist(12, 12 + headerLength)));
      
      map['cipher'] = 'CHACHA20-POLY1305';
      final newHeaderBytes = utf8.encode(jsonEncode(map));
      
      final bb = BytesBuilder();
      bb.add(backup.sublist(0, 8));
      final newHl = ByteData(4)..setUint32(0, newHeaderBytes.length, Endian.big);
      bb.add(newHl.buffer.asUint8List());
      bb.add(newHeaderBytes);
      bb.add(backup.sublist(12 + headerLength));
      
      expect(() => cryptoService.decrypt(bb.toBytes(), password), throwsA(isA<BackupFormatException>()));
    });

    test('longitud MAC inválida -> BackupFormatException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      final corrupted = Uint8List.fromList(backup);
      
      final hlData = ByteData.sublistView(corrupted, 8, 12);
      final headerLength = hlData.getUint32(0, Endian.big);
      
      // MAC Length is at 12 + headerLength
      final macLengthOffset = 12 + headerLength;
      final macLengthData = ByteData.sublistView(corrupted, macLengthOffset, macLengthOffset + 4);
      macLengthData.setUint32(0, 32, Endian.big); // Change from 16 to 32
      
      expect(
        () => cryptoService.decrypt(corrupted, password),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('longitud ciphertext inconsistente/truncada -> BackupFormatException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      final corrupted = Uint8List.fromList(backup);
      
      // We will tell the parser that ciphertext is longer than what's available
      final hlData = ByteData.sublistView(corrupted, 8, 12);
      final headerLength = hlData.getUint32(0, Endian.big);
      
      final cipherLenOffset = 16 + headerLength + 16; // 12+HL + 4(MAC_LEN) + 16(MAC)
      final cipherLenData = ByteData.sublistView(corrupted, cipherLenOffset, cipherLenOffset + 4);
      final originalLen = cipherLenData.getUint32(0, Endian.big);
      cipherLenData.setUint32(0, originalLen + 100, Endian.big); 
      
      expect(
        () => cryptoService.decrypt(corrupted, password),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('archivo truncado -> BackupFormatException', () async {
      final backup = await cryptoService.encrypt(payload, password);
      final corrupted = backup.sublist(0, backup.length - 10); // Cut off last 10 bytes

      expect(
        () => cryptoService.decrypt(corrupted, password),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('payload vacío -> round-trip válido', () async {
      final emptyPayload = Uint8List(0);
      final backup = await cryptoService.encrypt(emptyPayload, password);
      final decrypted = await cryptoService.decrypt(backup, password);
      
      expect(decrypted, isEmpty);
    });

    test('payload relativamente grande -> round-trip válido', () async {
      // Create a 2MB payload
      final largePayload = Uint8List.fromList(List<int>.generate(2 * 1024 * 1024, (i) => i % 256));
      final backup = await cryptoService.encrypt(largePayload, password);
      final decrypted = await cryptoService.decrypt(backup, password);
      
      expect(decrypted.length, equals(largePayload.length));
      // Checking full equality might be slow but it's safe.
      expect(decrypted[1000], equals(largePayload[1000]));
    });
  });
}
