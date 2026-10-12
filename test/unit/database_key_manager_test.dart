import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_gastos/core/services/database_key_manager.dart';
import 'package:path/path.dart' as p;

/// Test double de [FlutterSecureStorage] que simula el almacenamiento en memoria
/// con soporte para namespaces (sharedPreferencesName) e inyección de fallos controlados.
class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, Map<String, String>> _storageNamespaces = {};

  int readCallCount = 0;
  int writeCallCount = 0;
  int deleteCallCount = 0;

  bool throwOnRead = false;
  int failReadNTimes = 0;
  int currentReadFailures = 0;
  Object? errorToThrow;

  String _getNamespace(AndroidOptions? aOptions) {
    return aOptions?.sharedPreferencesName ?? 'default_namespace';
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
      throw errorToThrow ?? PlatformException(code: 'STORAGE_UNAVAILABLE', message: 'Fake error');
    }
    if (currentReadFailures < failReadNTimes) {
      currentReadFailures++;
      throw errorToThrow ?? PlatformException(code: 'TRANSIENT_ERROR', message: 'Temporary glitch');
    }

    final ns = _getNamespace(aOptions);
    return _storageNamespaces[ns]?[key];
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
  late Directory tempDir;

  CleanInstallPhysicalProof getCleanProof() => CleanInstallPhysicalProof(
        dbPath: p.join(tempDir.path, 'non_existent_${DateTime.now().microsecondsSinceEpoch}.db'),
        checkTimestamp: DateTime.now(),
      );

  Future<MigrationPhysicalProof> getValidMigrationProof() async {
    final file = File(p.join(tempDir.path, 'source_valid.db'));
    if (!await file.exists()) {
      await file.writeAsBytes(List.filled(1024, 0xAA));
    }
    final bytes = await file.readAsBytes();
    final hash = await Sha256().hash(bytes);
    final sha256 = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return MigrationPhysicalProof(
      dbPath: file.path,
      fileSizeBytes: await file.length(),
      lastModified: await file.lastModified(),
      validationTimestamp: DateTime.now(),
      userVersion: 24,
      sha256Fingerprint: sha256,
    );
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('db_key_mgr_test_');
    fakeStorage = FakeFlutterSecureStorage();
    keyManager = DatabaseKeyManagerImpl(
      storage: fakeStorage,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('DatabaseKeyManager — Suite de Validación Aislada con Evidencia Física (13B-05)', () {
    // TEST 1: Formato y generación de 256 bits (64 caracteres hex)
    test('1. Formato y generación criptográfica de 256 bits (64 caracteres hex)', () async {
      final key = await keyManager.createKeyForCleanInstall(proof: getCleanProof());

      expect(key, isNotNull);
      expect(key.length, equals(64));
      final hexRegex = RegExp(r'^[0-9a-f]{64}$');
      expect(hexRegex.hasMatch(key), isTrue);
      expect(key, isNot(equals('0' * 64)));
    });

    // TEST 2: Persistencia y recuperación
    test('2. Persistencia y recuperación segura de clave existente', () async {
      const existingKey = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      fakeStorage.seedValue('gestor_gastos_sqlcipher_keys', 'sqlcipher_database_key_v1', existingKey);

      final hasKey = await keyManager.hasExistingKey();
      expect(hasKey, isTrue);

      final retrievedKey = await keyManager.getExistingKey();
      expect(retrievedKey, equals(existingKey));
    });

    // TEST 3: Idempotencia
    test('3. Idempotencia: múltiples consultas retornan la misma clave sin mutar storage', () async {
      final key1 = await keyManager.createKeyForCleanInstall(proof: getCleanProof());
      final writesAfterCreate = fakeStorage.writeCallCount;

      final key2 = await keyManager.getExistingKey();
      final key3 = await keyManager.getExistingKey();

      expect(key2, equals(key1));
      expect(key3, equals(key1));
      expect(fakeStorage.writeCallCount, equals(writesAfterCreate));
    });

    // TEST 4: Llamadas concurrentes
    test('4. Llamadas concurrentes resuelven coherentemente sin duplicación', () async {
      final futures = [
        keyManager.createKeyForCleanInstall(proof: getCleanProof()),
        keyManager.getExistingKey(),
        keyManager.hasExistingKey(),
      ];

      final results = await Future.wait(futures);
      final createdKey = results[0] as String;
      expect(createdKey.length, equals(64));
      expect(fakeStorage.writeCallCount, equals(1));
    });

    // TEST 5: Reintentos transitorios
    test('5. Reintentos ante fallos transitorios y excepción ante error persistente', () async {
      const validKey = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      fakeStorage.seedValue('gestor_gastos_sqlcipher_keys', 'sqlcipher_database_key_v1', validKey);

      fakeStorage.failReadNTimes = 2;
      fakeStorage.errorToThrow = PlatformException(
        code: 'KEYSTORE_BUSY',
        message: 'Keystore busy, retry later',
      );

      final key = await keyManager.getExistingKey();
      expect(key, equals(validKey));
      expect(fakeStorage.readCallCount, equals(3));

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

    // TEST 6: No eliminación ante fallos de lectura (resetOnError: false)
    test('6. No eliminación de datos en storage ante fallos de lectura (resetOnError: false)', () async {
      const validKey = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      fakeStorage.seedValue('gestor_gastos_sqlcipher_keys', 'sqlcipher_database_key_v1', validKey);

      fakeStorage.throwOnRead = true;
      fakeStorage.errorToThrow = PlatformException(code: 'CORRUPT_KEYSTORE');

      try {
        await keyManager.getExistingKey();
      } catch (_) {}

      expect(fakeStorage.deleteCallCount, equals(0));
      expect(
        fakeStorage.peekRawValue('gestor_gastos_sqlcipher_keys', 'sqlcipher_database_key_v1'),
        equals(validKey),
      );
    });

    // TEST 7: Validación de precondiciones y rechazo ante evidencias no coincidentes
    test('7. No regeneración accidental y rechazo ante alteraciones físicas del archivo', () async {
      // Caso A: CleanInstall falla si el archivo sí existe en disco
      final existingFile = File(p.join(tempDir.path, 'existing_db.db'));
      await existingFile.writeAsString('dummy');
      expect(
        () => keyManager.createKeyForCleanInstall(
          proof: CleanInstallPhysicalProof(dbPath: existingFile.path, checkTimestamp: DateTime.now()),
        ),
        throwsA(isA<DatabaseKeyCreationForbiddenException>()),
      );

      // Caso B: Migration falla si el archivo no existe
      expect(
        () => keyManager.createKeyForMigration(
          proof: MigrationPhysicalProof(
            dbPath: p.join(tempDir.path, 'missing.db'),
            fileSizeBytes: 100,
            lastModified: DateTime.now(),
            validationTimestamp: DateTime.now(),
            sha256Fingerprint: '00' * 32,
          ),
        ),
        throwsA(isA<DatabaseKeyCreationForbiddenException>()),
      );

      // Caso C: Migration falla si el tamaño físico del archivo difiere de la prueba
      final proof = await getValidMigrationProof();
      expect(
        () => keyManager.createKeyForMigration(
          proof: MigrationPhysicalProof(
            dbPath: proof.dbPath,
            fileSizeBytes: proof.fileSizeBytes + 999, // tamaño alterado
            lastModified: proof.lastModified,
            validationTimestamp: proof.validationTimestamp,
            sha256Fingerprint: proof.sha256Fingerprint,
          ),
        ),
        throwsA(isA<DatabaseKeyCreationForbiddenException>()),
      );

      // Caso E: Migration falla si el contenido del archivo ha sido alterado (hash SHA-256 no coincide)
      expect(
        () => keyManager.createKeyForMigration(
          proof: MigrationPhysicalProof(
            dbPath: proof.dbPath,
            fileSizeBytes: proof.fileSizeBytes,
            lastModified: proof.lastModified,
            validationTimestamp: proof.validationTimestamp,
            sha256Fingerprint: 'deadbeef' * 8, // hash alterado
          ),
        ),
        throwsA(isA<DatabaseKeyCreationForbiddenException>()),
      );

      // Caso D: Clave ya existente prohíbe reescritura
      await keyManager.createKeyForMigration(proof: proof);
      expect(
        () => keyManager.createKeyForMigration(proof: proof),
        throwsA(isA<DatabaseKeyAlreadyExistsException>()),
      );
    });

    // TEST 8: Ausencia de exposición en toString
    test('8. Ausencia absoluta de exposición de claves en logs y representaciones de depuración', () async {
      final key = await keyManager.createKeyForCleanInstall(proof: getCleanProof());
      final stringRep = keyManager.toString();

      expect(stringRep.contains(key), isFalse);
      expect(stringRep, contains('DatabaseKeyManagerImpl'));
      expect(stringRep, contains('cached: true'));
    });

    // TEST 9: clearMemoryCache
    test('9. clearMemoryCache() limpia la memoria volátil sin borrar storage', () async {
      final key = await keyManager.createKeyForCleanInstall(proof: getCleanProof());
      keyManager.clearMemoryCache();

      final readsBefore = fakeStorage.readCallCount;
      final retrievedKey = await keyManager.getExistingKey();

      expect(retrievedKey, equals(key));
      expect(fakeStorage.readCallCount, greaterThan(readsBefore));
      expect(fakeStorage.peekRawValue('gestor_gastos_sqlcipher_keys', 'sqlcipher_database_key_v1'), equals(key));
    });

    // TEST 10: Independencia total frente al PIN
    test('10. Independencia total frente al almacenamiento y credenciales del PIN', () async {
      const pinKeyName = 'v1_pin_credential_data';
      const pinValue = 'argon2id_hash_pin_personal_secret';
      fakeStorage.seedValue('default_namespace', pinKeyName, pinValue);

      final dbKey = await keyManager.createKeyForCleanInstall(proof: getCleanProof());

      expect(fakeStorage.peekRawValue('default_namespace', pinKeyName), equals(pinValue));
      expect(fakeStorage.peekRawValue('gestor_gastos_sqlcipher_keys', 'sqlcipher_database_key_v1'), equals(dbKey));
    });
  });
}
