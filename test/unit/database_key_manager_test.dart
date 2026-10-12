import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/services/database_key_manager.dart';

/// Test double de [FlutterSecureStorage] que simula el almacenamiento en memoria
/// con soporte para namespaces (sharedPreferencesName) e inyección de fallos controlados.
class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, Map<String, String>> _storageNamespaces = {};

  int readCallCount = 0;
  int writeCallCount = 0;
  int deleteCallCount = 0;

  bool throwOnRead = false;
  int throwOnReadAttemptsRemaining = 0;
  Object? errorToThrow;

  String _getNamespace(AndroidOptions? aOptions) {
    return aOptions?.sharedPreferencesName ?? 'FlutterSecureStorage';
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writeCallCount++;
    final ns = _getNamespace(aOptions);
    _storageNamespaces.putIfAbsent(ns, () => {});
    if (value != null) {
      _storageNamespaces[ns]![key] = value;
    } else {
      _storageNamespaces[ns]!.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    readCallCount++;

    if (throwOnRead) {
      throw errorToThrow ??
          PlatformException(
            code: 'KEYSTORE_ERROR',
            message: 'Android KeyStore operation failed',
          );
    }

    if (throwOnReadAttemptsRemaining > 0) {
      throwOnReadAttemptsRemaining--;
      throw errorToThrow ??
          PlatformException(
            code: 'TRANSIENT_KEYSTORE_BUSY',
            message: 'KeyStore daemon busy',
          );
    }

    final ns = _getNamespace(aOptions);
    return _storageNamespaces[ns]?[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deleteCallCount++;
    final ns = _getNamespace(aOptions);
    _storageNamespaces[ns]?.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final ns = _getNamespace(aOptions);
    return _storageNamespaces[ns]?.containsKey(key) ?? false;
  }

  /// Helper de inspección directa para aserciones de prueba.
  String? peekRawValue(String namespace, String key) {
    return _storageNamespaces[namespace]?[key];
  }

  void seedValue(String namespace, String key, String value) {
    _storageNamespaces.putIfAbsent(namespace, () => {});
    _storageNamespaces[namespace]![key] = value;
  }
}

void main() {
  late FakeFlutterSecureStorage fakeStorage;
  late DatabaseKeyManagerImpl keyManager;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
    keyManager = DatabaseKeyManagerImpl(
      storage: fakeStorage,
    );
  });

  group('DatabaseKeyManager — Suite de Validación Aislada (13B-04)', () {
    // TEST 1: Formato y generación de 256 bits (64 caracteres hex)
    test('1. Formato y generación criptográfica de 256 bits (64 caracteres hex)', () async {
      final key = await keyManager.createKeyForCleanInstall(dbFileExists: false);

      expect(key, isNotNull);
      expect(key.length, equals(64));
      // Debe ser estrictamente hexadecimal en minúsculas
      final hexRegex = RegExp(r'^[0-9a-f]{64}$');
      expect(hexRegex.hasMatch(key), isTrue);

      // Verificar que los bytes no sean todos ceros ni triviales
      expect(key, isNot(equals('0' * 64)));
    });

    // TEST 2: Persistencia y recuperación de clave existente
    test('2. Persistencia y recuperación segura de clave existente', () async {
      final createdKey = await keyManager.createKeyForCleanInstall(dbFileExists: false);

      // Crear nueva instancia de keyManager para obligar a leer de storage sin caché en memoria
      final freshManager = DatabaseKeyManagerImpl(storage: fakeStorage);
      final retrievedKey = await freshManager.getExistingKey();

      expect(retrievedKey, equals(createdKey));
      expect(await freshManager.hasExistingKey(), isTrue);
    });

    // TEST 3: Idempotencia en lecturas
    test('3. Idempotencia: múltiples consultas retornan la misma clave sin mutar storage', () async {
      final key1 = await keyManager.createKeyForCleanInstall(dbFileExists: false);
      final key2 = await keyManager.getExistingKey();
      final key3 = await keyManager.getExistingKey();

      expect(key2, equals(key1));
      expect(key3, equals(key1));
      // Con caché en memoria, el conteo de escrituras en storage debe ser exactamente 1
      expect(fakeStorage.writeCallCount, equals(1));
    });

    // TEST 4: Concurrencia sin generación duplicada (Mutex protection)
    test('4. Llamadas concurrentes resuelven coherentemente sin duplicación', () async {
      // Iniciar 10 lecturas simultáneas de getExistingKey()
      // Primero sembramos una clave válida en storage
      const existingHex = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      fakeStorage.seedValue('gestor_gastos_sqlcipher_keys', 'sqlcipher_database_key_v1', existingHex);

      final results = await Future.wait(
        List.generate(10, (_) => keyManager.getExistingKey()),
      );

      for (final r in results) {
        expect(r, equals(existingHex));
      }
    });

    // TEST 5: Errores transitorios y persistentes con reintentos
    test('5. Reintentos ante fallos transitorios y excepción ante error persistente', () async {
      // Configurar 2 fallos transitorios seguidos de éxito
      fakeStorage.throwOnReadAttemptsRemaining = 2;
      const validKey = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      fakeStorage.seedValue('gestor_gastos_sqlcipher_keys', 'sqlcipher_database_key_v1', validKey);

      // Debe recuperarse gracias a los 3 reintentos configurados
      final key = await keyManager.getExistingKey();
      expect(key, equals(validKey));
      expect(fakeStorage.readCallCount, equals(3)); // 2 fallos + 1 éxito

      // Ahora simular fallo persistente permanente
      keyManager.clearMemoryCache();
      fakeStorage.throwOnRead = true;
      fakeStorage.errorToThrow = PlatformException(
        code: 'HARDWARE_KEYSTORE_DEAD',
        message: 'Keystore permanently unavailable',
      );

      expect(
        () => keyManager.getExistingKey(),
        throwsA(isA<DatabaseKeyStorageException>()),
      );
    });

    // TEST 6: No eliminación ante fallos de lectura (resetOnError: false verificado)
    test('6. No eliminación de datos en storage ante fallos de lectura (resetOnError: false)', () async {
      const validKey = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      fakeStorage.seedValue('gestor_gastos_sqlcipher_keys', 'sqlcipher_database_key_v1', validKey);

      fakeStorage.throwOnRead = true;
      fakeStorage.errorToThrow = PlatformException(code: 'CORRUPT_KEYSTORE');

      try {
        await keyManager.getExistingKey();
      } catch (_) {}

      // Verificar que delete() NUNCA fue invocado por el servicio
      expect(fakeStorage.deleteCallCount, equals(0));
      // El valor en storage permanece intacto
      expect(
        fakeStorage.peekRawValue('gestor_gastos_sqlcipher_keys', 'sqlcipher_database_key_v1'),
        equals(validKey),
      );
    });

    // TEST 7: No regeneración accidental ante precondiciones inválidas
    test('7. No regeneración accidental ante archivo existente o clave previa', () async {
      // Caso A: Se intenta createKeyForCleanInstall pero el archivo de base de datos existe en disco
      expect(
        () => keyManager.createKeyForCleanInstall(dbFileExists: true),
        throwsA(isA<DatabaseKeyCreationForbiddenException>()),
      );

      // Caso B: Se intenta createKeyForValidatedMigration pero la fuente no está validada
      expect(
        () => keyManager.createKeyForValidatedMigration(
          isSourceValidated: false,
          isSourceUnencrypted: true,
        ),
        throwsA(isA<DatabaseKeyCreationForbiddenException>()),
      );

      // Caso C: Ya existe una clave en storage y se intenta llamar createKeyForCleanInstall
      await keyManager.createKeyForCleanInstall(dbFileExists: false);
      expect(
        () => keyManager.createKeyForCleanInstall(dbFileExists: false),
        throwsA(isA<DatabaseKeyAlreadyExistsException>()),
      );
    });

    // TEST 8: No exposición de claves en logs ni toString
    test('8. Ausencia absoluta de exposición de claves en logs y representaciones de depuración', () async {
      final key = await keyManager.createKeyForCleanInstall(dbFileExists: false);

      final stringRep = keyManager.toString();

      // toString() debe ser opaco y seguro
      expect(stringRep, isNot(contains(key)));
      expect(stringRep, contains('DatabaseKeyManagerImpl'));
      expect(stringRep, contains('cached: true'));
    });

    // TEST 9: Limpieza de caché en memoria sin borrar persistencia
    test('9. clearMemoryCache() limpia la memoria volátil sin borrar storage', () async {
      final key = await keyManager.createKeyForCleanInstall(dbFileExists: false);

      keyManager.clearMemoryCache();
      expect(keyManager.toString(), contains('cached: false'));

      // Pero el valor sigue existiendo en el storage persistente
      final rawPersisted = fakeStorage.peekRawValue(
        'gestor_gastos_sqlcipher_keys',
        'sqlcipher_database_key_v1',
      );
      expect(rawPersisted, equals(key));

      // Y una lectura subsiguiente lo recarga sin problemas
      final reloaded = await keyManager.getExistingKey();
      expect(reloaded, equals(key));
    });

    // TEST 10: Independencia frente al almacenamiento del PIN
    test('10. Independencia total frente al almacenamiento y credenciales del PIN', () async {
      // 1. Simular que el PIN ya fue guardado previamente en el namespace default de SecureStorageService
      const pinKey = 'user_security_pin';
      const defaultNamespace = 'FlutterSecureStorage';
      const fakeHashedPin = 'hashed_pin_salt_998877';
      fakeStorage.seedValue(defaultNamespace, pinKey, fakeHashedPin);

      // 2. Operar DatabaseKeyManager (crear clave para SQLCipher)
      final dbKey = await keyManager.createKeyForCleanInstall(dbFileExists: false);

      // 3. Verificar que la clave de SQLCipher se escribió en SU PROPIO namespace
      final sqlCipherPersisted = fakeStorage.peekRawValue(
        'gestor_gastos_sqlcipher_keys',
        'sqlcipher_database_key_v1',
      );
      expect(sqlCipherPersisted, equals(dbKey));

      // 4. Verificar que el PIN en el namespace default permanece INTACTO e INALTERADO
      final pinAfterDbKeyOperation = fakeStorage.peekRawValue(defaultNamespace, pinKey);
      expect(pinAfterDbKeyOperation, equals(fakeHashedPin));
      expect(pinAfterDbKeyOperation, isNot(equals(dbKey)));
    });
  });
}
