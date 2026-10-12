import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Excepciones específicas para la gestión de claves de SQLCipher.
abstract class DatabaseKeyException implements Exception {
  final String message;
  const DatabaseKeyException(this.message);

  @override
  String toString() => 'DatabaseKeyException: $message';
}

class DatabaseKeyStorageException extends DatabaseKeyException {
  final Object? cause;
  const DatabaseKeyStorageException(super.message, [this.cause]);

  @override
  String toString() => 'DatabaseKeyStorageException: $message (cause: $cause)';
}

class DatabaseKeyNotFoundException extends DatabaseKeyException {
  const DatabaseKeyNotFoundException(super.message);
}

class DatabaseKeyAlreadyExistsException extends DatabaseKeyException {
  const DatabaseKeyAlreadyExistsException(super.message);
}

class DatabaseKeyCreationForbiddenException extends DatabaseKeyException {
  const DatabaseKeyCreationForbiddenException(super.message);
}

/// Contrato formal para la gestión segura y aislada de la clave de SQLCipher.
abstract class DatabaseKeyManager {
  /// Recupera la clave existente desde la memoria o desde almacenamiento seguro.
  /// Retorna `null` si legítimamente no existe una clave registrada.
  /// Lanza [DatabaseKeyStorageException] si ocurre un fallo persistente de Keystore.
  Future<String?> getExistingKey();

  /// Comprueba si existe una clave registrada en almacenamiento seguro.
  Future<bool> hasExistingKey();

  /// Genera y persiste una nueva clave únicamente para una instalación limpia autorizada.
  ///
  /// [RESTRICTED]: Prohibido su uso desde flujos productivos generales.
  /// Restringido para pruebas y para el orquestador de migración en FASE 13B-05.
  @visibleForTesting
  Future<String> createKeyForCleanInstall({required bool dbFileExists});

  /// Genera y persiste una nueva clave únicamente para una migración validada de SQLite v24 a SQLCipher.
  ///
  /// [RESTRICTED]: Prohibido su uso desde flujos productivos generales.
  /// Restringido para pruebas y para el orquestador de migración en FASE 13B-05.
  @visibleForTesting
  Future<String> createKeyForValidatedMigration({
    required bool isSourceValidated,
    required bool isSourceUnencrypted,
  });

  /// Limpia la clave de la memoria volátil (RAM) sin alterar el almacenamiento persistente.
  void clearMemoryCache();
}

/// Implementación de producción de [DatabaseKeyManager] respaldada por [FlutterSecureStorage].
class DatabaseKeyManagerImpl implements DatabaseKeyManager {
  static const String keyStorageName = 'sqlcipher_database_key_v1';
  static const int keyLengthBytes = 32; // 256 bits
  static const int maxRetries = 3;

  /// Opciones Android estrictas y compatibles con flutter_secure_storage 10.0.0.
  /// Se fija explícitamente [resetOnError: false] para prohibir la destrucción
  /// automática de claves ante excepciones transitorias del Android Keystore.
  static const AndroidOptions androidOptions = AndroidOptions(
    resetOnError: false,
    sharedPreferencesName: 'gestor_gastos_sqlcipher_keys',
    preferencesKeyPrefix: 'db_key',
  );

  final FlutterSecureStorage _storage;
  final Random _random;

  String? _cachedKey;
  Completer<void>? _operationLock;

  DatabaseKeyManagerImpl({
    FlutterSecureStorage? storage,
    Random? random,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: androidOptions,
            ),
        _random = random ?? Random.secure();

  /// Adquiere un lock asíncrono para prevenir condiciones de carrera.
  Future<T> _synchronized<T>(Future<T> Function() action) async {
    while (_operationLock != null) {
      await _operationLock!.future;
    }
    _operationLock = Completer<void>();
    try {
      return await action();
    } finally {
      final lock = _operationLock;
      _operationLock = null;
      lock?.complete();
    }
  }

  /// Ejecuta operaciones de storage con reintentos controlados ante fallos transitorios.
  Future<T> _retryStorageOperation<T>(Future<T> Function() operation) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        return await operation();
      } catch (e) {
        if (attempts >= maxRetries) {
          throw DatabaseKeyStorageException(
            'Fallo de acceso al almacenamiento seguro tras $maxRetries intentos.',
            e,
          );
        }
        // Espera exponencial breve (50ms, 100ms)
        await Future.delayed(Duration(milliseconds: 50 * attempts));
      }
    }
  }

  @override
  Future<String?> getExistingKey() async {
    return await _synchronized(() async {
      if (_cachedKey != null) {
        return _cachedKey;
      }

      final key = await _retryStorageOperation(() async {
        return await _storage.read(
          key: keyStorageName,
          aOptions: androidOptions,
        );
      });

      if (key != null && key.isNotEmpty) {
        _validateHexKeyFormat(key);
        _cachedKey = key;
        return _cachedKey;
      }

      return null;
    });
  }

  @override
  Future<bool> hasExistingKey() async {
    final key = await getExistingKey();
    return key != null && key.isNotEmpty;
  }

  @visibleForTesting
  @override
  Future<String> createKeyForCleanInstall({required bool dbFileExists}) async {
    return await _synchronized(() async {
      if (dbFileExists) {
        throw const DatabaseKeyCreationForbiddenException(
          'No se permite generar una clave de instalación limpia porque ya existe un archivo de base de datos en disco.',
        );
      }

      final existing = await _readDirectFromStorage();
      if (existing != null && existing.isNotEmpty) {
        throw const DatabaseKeyAlreadyExistsException(
          'Ya existe una clave registrada en almacenamiento seguro. No se permite sobrescribirla.',
        );
      }

      final newKey = _generateCryptographicKeyHex();
      await _persistKeyToStorage(newKey);
      _cachedKey = newKey;
      return newKey;
    });
  }

  @visibleForTesting
  @override
  Future<String> createKeyForValidatedMigration({
    required bool isSourceValidated,
    required bool isSourceUnencrypted,
  }) async {
    return await _synchronized(() async {
      if (!isSourceValidated || !isSourceUnencrypted) {
        throw const DatabaseKeyCreationForbiddenException(
          'No se permite generar clave de migración: la base origen no ha sido validada como SQLite plana íntegra.',
        );
      }

      final existing = await _readDirectFromStorage();
      if (existing != null && existing.isNotEmpty) {
        throw const DatabaseKeyAlreadyExistsException(
          'Ya existe una clave registrada en almacenamiento seguro para la base de datos.',
        );
      }

      final newKey = _generateCryptographicKeyHex();
      await _persistKeyToStorage(newKey);
      _cachedKey = newKey;
      return newKey;
    });
  }

  @override
  void clearMemoryCache() {
    _cachedKey = null;
  }

  /// Lectura directa interna con reintentos sin modificar la caché.
  Future<String?> _readDirectFromStorage() async {
    return await _retryStorageOperation(() async {
      return await _storage.read(
        key: keyStorageName,
        aOptions: androidOptions,
      );
    });
  }

  /// Persistencia con reintentos.
  Future<void> _persistKeyToStorage(String key) async {
    await _retryStorageOperation(() async {
      await _storage.write(
        key: keyStorageName,
        value: key,
        aOptions: androidOptions,
      );
    });
  }

  /// Genera 32 bytes criptográficamente seguros y los formatea como 64 caracteres hex.
  String _generateCryptographicKeyHex() {
    final bytes = Uint8List(keyLengthBytes);
    for (int i = 0; i < keyLengthBytes; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Valida que la clave sea exactamente un string de 64 caracteres hexadecimales.
  void _validateHexKeyFormat(String key) {
    final hexRegex = RegExp(r'^[0-9a-f]{64}$');
    if (!hexRegex.hasMatch(key)) {
      throw const DatabaseKeyStorageException(
        'La clave recuperada del almacenamiento no cumple con el formato hexadecimal de 64 caracteres esperado.',
      );
    }
  }

  @override
  String toString() {
    // Protección estricta: Jamás exponer la clave en representaciones de depuración o logs.
    return 'DatabaseKeyManagerImpl(cached: ${_cachedKey != null})';
  }
}
