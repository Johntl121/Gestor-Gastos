import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../errors/backup_exceptions.dart';

class BackupCryptoService {
  static const String _magicString = 'GGBK';
  static const int _formatVersion = 1;
  static const int _minIterations = 100000;
  static const int _maxIterations = 2000000;
  static const int _defaultIterations = 600000;

  final Cipher _cipher = AesGcm.with256bits();

  Future<Uint8List> encrypt(Uint8List payloadBytes, String password) async {
    final salt = _generateRandomBytes(16);
    final nonce = _generateRandomBytes(12);

    final headerMap = {
      'formatVersion': _formatVersion,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': _defaultIterations,
      'salt': base64Encode(salt),
      'cipher': 'AES-256-GCM',
      'nonce': base64Encode(nonce)
    };

    final headerJson = jsonEncode(headerMap);
    final headerBytes = Uint8List.fromList(utf8.encode(headerJson));

    final secretKey = await _deriveKey(password, salt, _defaultIterations);

    final secretBox = await _cipher.encrypt(
      payloadBytes,
      secretKey: secretKey,
      nonce: nonce,
      aad: headerBytes,
    );

    final macBytes = Uint8List.fromList(secretBox.mac.bytes);
    final cipherTextBytes = Uint8List.fromList(secretBox.cipherText);

    final bb = BytesBuilder();
    
    // MAGIC
    bb.add(ascii.encode(_magicString));
    
    // FORMAT_VERSION
    bb.add(_encodeUInt32BE(_formatVersion));
    
    // HEADER_LENGTH
    bb.add(_encodeUInt32BE(headerBytes.length));
    // HEADER_BYTES
    bb.add(headerBytes);
    
    // MAC_LENGTH
    bb.add(_encodeUInt32BE(macBytes.length));
    // MAC_BYTES
    bb.add(macBytes);
    
    // CIPHERTEXT_LENGTH
    bb.add(_encodeUInt32BE(cipherTextBytes.length));
    // CIPHERTEXT_BYTES
    bb.add(cipherTextBytes);
    
    return bb.toBytes();
  }

  Future<Uint8List> decrypt(Uint8List backupBytes, String password) async {
    int offset = 0;
    
    if (backupBytes.length < 4) throw BackupFormatException('Archivo demasiado pequeño.');
    final magicBytes = backupBytes.sublist(offset, offset + 4);
    if (ascii.decode(magicBytes) != _magicString) {
      throw BackupFormatException('Magic inválido.');
    }
    offset += 4;

    if (backupBytes.length < offset + 4) throw BackupFormatException('Truncado en versión.');
    final formatVersion = _decodeUInt32BE(backupBytes.sublist(offset, offset + 4));
    if (formatVersion != _formatVersion) {
      throw BackupVersionException('Versión desconocida: $formatVersion');
    }
    offset += 4;

    if (backupBytes.length < offset + 4) throw BackupFormatException('Truncado en longitud de header.');
    final headerLength = _decodeUInt32BE(backupBytes.sublist(offset, offset + 4));
    offset += 4;

    // Prevención básica de OOM si el headerLength es absurdo
    if (headerLength > 10 * 1024 * 1024) throw BackupFormatException('Longitud de header absurda.');

    if (backupBytes.length < offset + headerLength) throw BackupFormatException('Header truncado.');
    final headerBytes = backupBytes.sublist(offset, offset + headerLength);
    offset += headerLength;

    Map<String, dynamic> headerMap;
    try {
      final headerJson = utf8.decode(headerBytes);
      headerMap = jsonDecode(headerJson);
    } catch (e) {
      throw BackupFormatException('JSON inválido.');
    }

    final iterations = headerMap['iterations'] as int?;
    if (iterations == null || iterations < _minIterations || iterations > _maxIterations) {
      throw BackupFormatException('Iteraciones fuera de rango.');
    }

    final kdf = headerMap['kdf'] as String?;
    if (kdf != 'PBKDF2-HMAC-SHA256') throw BackupFormatException('KDF desconocido.');

    final cipherAlgo = headerMap['cipher'] as String?;
    if (cipherAlgo != 'AES-256-GCM') throw BackupFormatException('Algoritmo desconocido.');

    final saltB64 = headerMap['salt'] as String?;
    final nonceB64 = headerMap['nonce'] as String?;
    if (saltB64 == null || nonceB64 == null) throw BackupFormatException('Salt o Nonce inválidos.');

    Uint8List salt;
    Uint8List nonce;
    try {
      salt = base64Decode(saltB64);
      nonce = base64Decode(nonceB64);
    } catch (e) {
      throw BackupFormatException('Base64 inválido en salt/nonce.');
    }
    
    if (salt.length != 16) throw BackupFormatException('Longitud de salt inválida.');
    if (nonce.length != 12) throw BackupFormatException('Longitud de nonce inválida.');
    
    if (backupBytes.length < offset + 4) throw BackupFormatException('Truncado en longitud de MAC.');
    final macLength = _decodeUInt32BE(backupBytes.sublist(offset, offset + 4));
    offset += 4;

    if (macLength != 16) throw BackupFormatException('Longitud de MAC inválida para AES-GCM.');

    if (backupBytes.length < offset + macLength) throw BackupFormatException('MAC truncado.');
    final macBytes = backupBytes.sublist(offset, offset + macLength);
    offset += macLength;

    if (backupBytes.length < offset + 4) throw BackupFormatException('Truncado en longitud de ciphertext.');
    final cipherTextLength = _decodeUInt32BE(backupBytes.sublist(offset, offset + 4));
    offset += 4;

    if (backupBytes.length < offset + cipherTextLength) throw BackupFormatException('Ciphertext truncado.');
    final cipherText = backupBytes.sublist(offset, offset + cipherTextLength);
    offset += cipherTextLength;

    final secretKey = await _deriveKey(password, salt, iterations);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    try {
      final payloadBytes = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: headerBytes,
      );
      return Uint8List.fromList(payloadBytes);
    } catch (e) {
      // SecretBoxAuthenticationError u otros errores criptográficos
      throw BackupAuthenticationException('No se pudo desbloquear la copia de seguridad.');
    }
  }

  Future<SecretKey> _deriveKey(String password, Uint8List salt, int iterations) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
  }

  Uint8List _generateRandomBytes(int length) {
    final r = math.Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => r.nextInt(256)));
  }

  Uint8List _encodeUInt32BE(int value) {
    final bData = ByteData(4);
    bData.setUint32(0, value, Endian.big);
    return bData.buffer.asUint8List();
  }

  int _decodeUInt32BE(Uint8List bytes) {
    final bData = ByteData.sublistView(bytes);
    return bData.getUint32(0, Endian.big);
  }
}
