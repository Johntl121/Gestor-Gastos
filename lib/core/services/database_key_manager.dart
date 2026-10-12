import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
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

/// Evidencia física verificada de una base de datos SQLite v24 apta para migración.
///
/// Vincula la ruta canónica, tamaño exacto en bytes, fecha de modificación física,
/// marca temporal efímera (≤ 120s) y huella criptográfica SHA-256 del contenido
/// para impedir que un llamador autorice la creación de claves con simples booleanos
/// o reutilice evidencias tras modificaciones del archivo en disco.
class MigrationPhysicalProof {
  final String dbPath;
  final int fileSizeBytes;
  final DateTime lastModified;
  final DateTime validationTimestamp;
  final int userVersion;
  final String sha256Fingerprint;

  const MigrationPhysicalProof({
    required this.dbPath,
    required this.fileSizeBytes,
    required this.lastModified,
    required this.validationTimestamp,
    this.userVersion = 24,
    required this.sha256Fingerprint,
  });
}

/// Evidencia física comprobada de ausencia de archivo para instalación limpia.
class CleanInstallPhysicalProof {
  final String dbPath;
  final DateTime checkTimestamp;

  const CleanInstallPhysicalProof({
    required this.dbPath,
    required this.checkTimestamp,
  });
}

/// Contrato formal para la gestión segura y aislada de la clave de SQLCipher.
abstract class DatabaseKeyManager {
  /// Recupera la clave existente desde la memoria o desde almacenamiento seguro.
  /// Retorna `null` si legítimamente no existe una clave registrada.
  /// Lanza [DatabaseKeyStorageException] si ocurre un fallo persistente de Keystore.
  Future<String?> getExistingKey();

  /// Comprueba si existe una clave registrada en almacenamiento seguro.
  Future<bool> hasExistingKey();

  /// Genera y persiste una nueva clave únicamente respaldada por una [CleanInstallPhysicalProof].
  ///
  /// Comprueba físicamente en tiempo de ejecución que el archivo objetivo no existe
  /// y que la marca temporal de comprobación es reciente (< 120s).
  Future<String> createKeyForCleanInstall({
    required CleanInstallPhysicalProof proof,
  });

  /// Genera y persiste una nueva clave únicamente respaldada por una [MigrationPhysicalProof].
  ///
  /// Comprueba físicamente en tiempo de ejecución que el archivo existe en disco,
  /// que su tamaño en bytes y fecha de modificación física coinciden de forma idéntica,
  /// y que la prueba no ha caducado (< 120s).
  Future<String> createKeyForMigration({
    required MigrationPhysicalProof proof,
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

  @override
  Future<String> createKeyForCleanInstall({
    required CleanInstallPhysicalProof proof,
  }) async {
    return await _synchronized(() async {
      final file = File(proof.dbPath);
      if (await file.exists()) {
        throw const DatabaseKeyCreationForbiddenException(
          'No se permite generar una clave de instalación limpia: ya existe un archivo de base de datos en disco.',
        );
      }

      final ageSeconds =
          DateTime.now().difference(proof.checkTimestamp).inSeconds.abs();
      if (ageSeconds > 120) {
        throw const DatabaseKeyCreationForbiddenException(
          'La evidencia de instalación limpia ha caducado (más de 120 segundos transcurridos).',
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

  @override
  Future<String> createKeyForMigration({
    required MigrationPhysicalProof proof,
  }) async {
    return await _synchronized(() async {
      final file = File(proof.dbPath);
      if (!await file.exists()) {
        throw const DatabaseKeyCreationForbiddenException(
          'No se permite generar clave de migración: el archivo origen no existe físicamente en disco.',
        );
      }

      final currentSize = await file.length();
      if (currentSize != proof.fileSizeBytes) {
        throw const DatabaseKeyCreationForbiddenException(
          'No se permite generar clave de migración: el tamaño del archivo difiere de la evidencia física inspeccionada.',
        );
      }

      final currentMod = await file.lastModified();
      if (currentMod.millisecondsSinceEpoch !=
          proof.lastModified.millisecondsSinceEpoch) {
        throw const DatabaseKeyCreationForbiddenException(
          'No se permite generar clave de migración: la fecha de modificación del archivo difiere de la evidencia.',
        );
      }

      if (proof.userVersion != 24) {
        throw const DatabaseKeyCreationForbiddenException(
          'No se permite generar clave de migración: el esquema de la evidencia no es SQLite v24.',
        );
      }

      final ageSeconds =
          DateTime.now().difference(proof.validationTimestamp).inSeconds.abs();
      if (ageSeconds > 120) {
        throw const DatabaseKeyCreationForbiddenException(
          'No se permite generar clave de migración: la evidencia física ha caducado (más de 120 segundos transcurridos).',
        );
      }

      // Verificación de integridad bit-a-bit por huella criptográfica SHA-256
      final bytes = await file.readAsBytes();
      final hash = await Sha256().hash(bytes);
      final currentFingerprint =
          hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (currentFingerprint != proof.sha256Fingerprint) {
        throw const DatabaseKeyCreationForbiddenException(
          'No se permite generar clave de migración: la huella de contenido (SHA-256) difiere de la evidencia física inspeccionada.',
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
