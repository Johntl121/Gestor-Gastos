import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:archive/archive_io.dart';
import 'package:gestor_gastos/core/services/app_info_provider.dart';
import 'package:gestor_gastos/core/services/attachment_storage_service.dart';
import 'package:gestor_gastos/core/services/backup_crypto_service.dart';
import 'package:gestor_gastos/core/services/backup_preferences_service.dart';
import 'package:gestor_gastos/core/services/snapshot_service.dart';
import 'package:gestor_gastos/data/services/backup_creation_service_impl.dart';

class MockSnapshotService extends Mock implements SnapshotService {}

class MockPreferencesService extends Mock implements BackupPreferencesService {}

class MockCryptoService extends Mock implements BackupCryptoService {}

class MockAppInfoProvider extends Mock implements AppInfoProvider {}

class FakeAttachmentService extends Fake implements AttachmentStorageService {
  final Map<String, String> mockResolvedPaths = {};

  @override
  Future<T> executeMaintenance<T>(Future<T> Function() action) {
    return action();
  }

  @override
  Future<String?> resolveAbsolutePath(String storedPath) async {
    return mockResolvedPaths[storedPath];
  }
}

void main() {
  late BackupCreationServiceImpl service;
  late MockSnapshotService mockSnapshotService;
  late MockPreferencesService mockPreferencesService;
  late FakeAttachmentService fakeAttachmentService;
  late MockCryptoService mockCryptoService;
  late MockAppInfoProvider mockAppInfoProvider;

  late Directory tempDocsDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(Uint8List(0));
  });

  setUp(() async {
    tempDocsDir = await Directory.systemTemp.createTemp('backup_creation_test');

    mockSnapshotService = MockSnapshotService();
    mockPreferencesService = MockPreferencesService();
    fakeAttachmentService = FakeAttachmentService();
    mockCryptoService = MockCryptoService();
    mockAppInfoProvider = MockAppInfoProvider();

    service = BackupCreationServiceImpl(
      snapshotService: mockSnapshotService,
      preferencesService: mockPreferencesService,
      attachmentService: fakeAttachmentService,
      cryptoService: mockCryptoService,
      appInfoProvider: mockAppInfoProvider,
      getDocsDirProvider: () async => tempDocsDir,
    );

    when(() => mockAppInfoProvider.getAppVersion())
        .thenAnswer((_) async => '1.0.0');
    when(() => mockPreferencesService.exportPreferences())
        .thenAnswer((_) async => {'USER_NAME': 'Test User'});
    when(() => mockCryptoService.encrypt(any(), any())).thenAnswer((i) async {
      final bytes = i.positionalArguments[0] as Uint8List;
      return Uint8List.fromList([...bytes, 0, 1, 2]); // dummy encrypt
    });
  });

  tearDown(() async {
    if (await tempDocsDir.exists()) {
      await tempDocsDir.delete(recursive: true);
    }
  });

  Future<Database> createMockSnapshot(String path) async {
    final db =
        await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY,
          imagePath TEXT
        )
      ''');
    });
    return db;
  }

  test('backup válido sin attachments', () async {
    when(() => mockSnapshotService.createDatabaseSnapshot(any()))
        .thenAnswer((i) async {
      final db = await createMockSnapshot(i.positionalArguments[0] as String);
      await db.close();
      return File(i.positionalArguments[0] as String);
    });

    final result = await service.generatePortableBackup('password123');

    expect(result.isRight(), isTrue);
    result.fold(
      (l) => fail('Should be Right'),
      (r) {
        expect(r.transactionAttachmentsIncluded, 0);
        expect(r.transactionAttachmentsMissing, 0);
        expect(r.backupFilePath, endsWith('.gestorbackup'));
        expect(File(r.backupFilePath).existsSync(), isTrue);
      },
    );

    // Verify temp files are cleaned up
    final entries = tempDocsDir.listSync();
    expect(entries.length, 1); // Only the generated .gestorbackup file
  });

  test(
      'backup válido con attachment relative, missing attachment y legacy absolute (deduplicado)',
      () async {
    final realRelativeFile = File(
        p.join(tempDocsDir.path, 'attachments', 'transactions', 'real.jpg'));
    await realRelativeFile.parent.create(recursive: true);
    await realRelativeFile.writeAsString('relative content');

    final realLegacyFile = File(p.join(tempDocsDir.path, 'legacy', 'old.jpg'));
    await realLegacyFile.parent.create(recursive: true);
    await realLegacyFile.writeAsString('legacy content');

    when(() => mockSnapshotService.createDatabaseSnapshot(any()))
        .thenAnswer((i) async {
      final db = await createMockSnapshot(i.positionalArguments[0] as String);
      // Insert 1 relative, 1 missing, 2 sharing same legacy absolute
      await db.insert('transactions',
          {'id': 1, 'imagePath': 'attachments/transactions/real.jpg'});
      await db.insert('transactions',
          {'id': 2, 'imagePath': 'attachments/transactions/missing.jpg'});
      await db
          .insert('transactions', {'id': 3, 'imagePath': realLegacyFile.path});
      await db
          .insert('transactions', {'id': 4, 'imagePath': realLegacyFile.path});
      await db.close();
      return File(i.positionalArguments[0] as String);
    });

    fakeAttachmentService
            .mockResolvedPaths['attachments/transactions/real.jpg'] =
        realRelativeFile.path;
    // Missing attachment -> null (already default in map since it's not set)
    fakeAttachmentService.mockResolvedPaths[realLegacyFile.path] =
        realLegacyFile.path;

    final result = await service.generatePortableBackup('password123');

    expect(result.isRight(), isTrue);
    result.fold(
      (l) => fail('Should be Right'),
      (r) {
        // Included = 1 relative + 2 legacy references (even though physical file deduplicated) = 3
        expect(r.transactionAttachmentsIncluded, 3);
        expect(r.transactionAttachmentsMissing, 1);
      },
    );
  });

  test('ZIP > max size lanza BackupTooLarge y limpia staging', () async {
    final smallSizeService = BackupCreationServiceImpl(
      snapshotService: mockSnapshotService,
      preferencesService: mockPreferencesService,
      attachmentService: fakeAttachmentService,
      cryptoService: mockCryptoService,
      appInfoProvider: mockAppInfoProvider,
      getDocsDirProvider: () async => tempDocsDir,
      maxPlaintextZipBytesOverride: 10, // 10 bytes limit
    );

    when(() => mockSnapshotService.createDatabaseSnapshot(any()))
        .thenAnswer((i) async {
      final db = await createMockSnapshot(i.positionalArguments[0] as String);
      await db.close();
      return File(i.positionalArguments[0] as String);
    });

    when(() => mockPreferencesService.exportPreferences())
        .thenAnswer((_) async => {'a': 'b'});

    final result = await smallSizeService.generatePortableBackup('password123');

    expect(result.isLeft(), isTrue);
    result.fold(
      (l) {
        expect(l.message, contains('supera el límite técnico temporal'));
      },
      (r) => fail('Should fail'),
    );

    // Crypto should not be called
    verifyNever(() => mockCryptoService.encrypt(any(), any()));

    // Verify temp files are cleaned up
    final entries = tempDocsDir
        .listSync()
        .where((e) => !e.path.contains('backup_staging_'))
        .toList();
    expect(entries.isEmpty, isTrue);
  });

  test('pre-zip supera max uncompressed lanza BackupTooLarge', () async {
    final smallSizeService = BackupCreationServiceImpl(
      snapshotService: mockSnapshotService,
      preferencesService: mockPreferencesService,
      attachmentService: fakeAttachmentService,
      cryptoService: mockCryptoService,
      appInfoProvider: mockAppInfoProvider,
      getDocsDirProvider: () async => tempDocsDir,
      maxUncompressedPayloadBytesOverride: 1, // 1 byte limit
    );

    when(() => mockSnapshotService.createDatabaseSnapshot(any()))
        .thenAnswer((i) async {
      final db = await createMockSnapshot(i.positionalArguments[0] as String);
      await db.close();
      return File(i.positionalArguments[0] as String);
    });
    when(() => mockPreferencesService.exportPreferences())
        .thenAnswer((_) async => {'a': 'b'});

    final result = await smallSizeService.generatePortableBackup('password123');

    expect(result.isLeft(), isTrue);
    result.fold(
      (l) => expect(l.message, contains('supera los límites permitidos')),
      (r) => fail('Should fail'),
    );
  });

  test('pre-zip supera max entries lanza BackupTooLarge', () async {
    final smallSizeService = BackupCreationServiceImpl(
      snapshotService: mockSnapshotService,
      preferencesService: mockPreferencesService,
      attachmentService: fakeAttachmentService,
      cryptoService: mockCryptoService,
      appInfoProvider: mockAppInfoProvider,
      getDocsDirProvider: () async => tempDocsDir,
      maxEntriesOverride: 1, // 1 file max limit
    );

    when(() => mockSnapshotService.createDatabaseSnapshot(any()))
        .thenAnswer((i) async {
      final db = await createMockSnapshot(i.positionalArguments[0] as String);
      await db.close();
      return File(i.positionalArguments[0] as String);
    });
    when(() => mockPreferencesService.exportPreferences())
        .thenAnswer((_) async => {'a': 'b'});

    final result = await smallSizeService.generatePortableBackup('password123');

    expect(result.isLeft(), isTrue);
    result.fold(
      (l) => expect(l.message, contains('supera los límites permitidos')),
      (r) => fail('Should fail'),
    );
  });

  test('crypto falla -> limpia temporales', () async {
    when(() => mockSnapshotService.createDatabaseSnapshot(any()))
        .thenAnswer((i) async {
      final db = await createMockSnapshot(i.positionalArguments[0] as String);
      await db.close();
      return File(i.positionalArguments[0] as String);
    });

    when(() => mockCryptoService.encrypt(any(), any()))
        .thenThrow(Exception('Crypto error'));

    final result = await service.generatePortableBackup('password123');

    expect(result.isLeft(), isTrue);
    result.fold(
      (l) {
        expect(l.message, contains('Crypto error'));
      },
      (r) => fail('Should fail'),
    );

    final entries = tempDocsDir
        .listSync()
        .where((e) => !e.path.contains('backup_staging_'))
        .toList();
    expect(entries.isEmpty, isTrue);
  });

  test(
      'REGRESIÓN: ZIP generado contiene archivos reales (manifest, DB, prefs, attachment) con rutas normalizadas POSIX y await real',
      () async {
    final realCrypto = BackupCryptoService();
    final realCreationService = BackupCreationServiceImpl(
      snapshotService: mockSnapshotService,
      preferencesService: mockPreferencesService,
      attachmentService: fakeAttachmentService,
      cryptoService: realCrypto,
      appInfoProvider: mockAppInfoProvider,
      getDocsDirProvider: () async => tempDocsDir,
    );

    // Adjunto real
    final attachmentFile = File(p.join(
        tempDocsDir.path, 'attachments', 'transactions', 'receipt_01.jpg'));
    await attachmentFile.parent.create(recursive: true);
    await attachmentFile.writeAsString('bytes de imagen');
    fakeAttachmentService.mockResolvedPaths[
            'attachments/transactions/receipt_01.jpg'] =
        attachmentFile.path;

    when(() => mockSnapshotService.createDatabaseSnapshot(any()))
        .thenAnswer((i) async {
      final db = await openDatabase(i.positionalArguments[0] as String,
          version: 1, onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY,
            imagePath TEXT
          )
        ''');
        await db.insert('transactions', {
          'id': 1,
          'imagePath': 'attachments/transactions/receipt_01.jpg',
        });
      });
      await db.close();
      return File(i.positionalArguments[0] as String);
    });

    when(() => mockPreferencesService.exportPreferences())
        .thenAnswer((_) async => {'USER_NAME': 'Juan Perez'});

    const password = 'StrongPassword!123';
    final result = await realCreationService.generatePortableBackup(password);

    expect(result.isRight(), isTrue);
    final backupPath =
        result.getOrElse(() => throw Exception('')).backupFilePath;
    expect(File(backupPath).existsSync(), isTrue);

    // 1. Descifrado real con BackupCryptoService
    final encryptedBytes = await File(backupPath).readAsBytes();
    final decryptedBytes = await realCrypto.decrypt(encryptedBytes, password);

    // 2. Abrir y decodificar ZIP real
    final archive = ZipDecoder().decodeBytes(decryptedBytes);

    // 3. Inspeccionar las entradas del ZIP
    final entryNames = archive.files.map((f) => f.name).toList();
    expect(entryNames, contains('manifest.json'));
    expect(entryNames, contains('gestor_gastos.db'));
    expect(entryNames, contains('preferences.json'));

    // Debe contener el attachment con prefijo POSIX
    final attachmentEntries = entryNames
        .where((n) => n.startsWith('attachments/transactions/'))
        .toList();
    expect(attachmentEntries.length, 1);
    expect(attachmentEntries.first, endsWith('.jpg'));

    // Invariante multiplataforma: NINGUNA entrada debe contener separadores backslash '\'
    for (final name in entryNames) {
      expect(name.contains('\\'), isFalse,
          reason: 'La entrada ZIP $name no debe contener backslashes');
      expect(name.startsWith('/'), isFalse);
    }

    // Verificar que los archivos dentro del ZIP sean regulares y no estén vacíos
    final manifestEntry =
        archive.files.firstWhere((f) => f.name == 'manifest.json');
    expect(manifestEntry.isFile, isTrue);
    expect(manifestEntry.size, greaterThan(0));

    final dbEntry =
        archive.files.firstWhere((f) => f.name == 'gestor_gastos.db');
    expect(dbEntry.isFile, isTrue);
    expect(dbEntry.size, greaterThan(0));

    final prefsEntry =
        archive.files.firstWhere((f) => f.name == 'preferences.json');
    expect(prefsEntry.isFile, isTrue);
    expect(prefsEntry.size, greaterThan(0));

    final photoEntry = archive.files.firstWhere(
        (f) => f.name.startsWith('attachments/transactions/'));
    expect(photoEntry.isFile, isTrue);
    expect(photoEntry.size, greaterThan(0));
  });

  test('REGRESIÓN: canonical relative existente conserva exactamente el mismo imagePath', () async {
    final realCrypto = BackupCryptoService();
    final realCreationService = BackupCreationServiceImpl(
      snapshotService: mockSnapshotService,
      preferencesService: mockPreferencesService,
      attachmentService: fakeAttachmentService,
      cryptoService: realCrypto,
      appInfoProvider: mockAppInfoProvider,
      getDocsDirProvider: () async => tempDocsDir,
    );

    const canonicalPath = 'attachments/transactions/ed1b09cc-9d6e-4d16-9911-46d9f8c59353.jpg';
    final physicalFile = File(p.join(tempDocsDir.path, 'attachments', 'transactions', 'ed1b09cc-9d6e-4d16-9911-46d9f8c59353.jpg'));
    await physicalFile.parent.create(recursive: true);
    await physicalFile.writeAsString('bytes deterministas');
    fakeAttachmentService.mockResolvedPaths[canonicalPath] = physicalFile.path;

    when(() => mockSnapshotService.createDatabaseSnapshot(any()))
        .thenAnswer((i) async {
      final db = await openDatabase(i.positionalArguments[0] as String,
          version: 1, onCreate: (db, version) async {
        await db.execute('CREATE TABLE transactions (id INTEGER PRIMARY KEY, imagePath TEXT)');
        await db.insert('transactions', {'id': 1, 'imagePath': canonicalPath});
      });
      await db.close();
      return File(i.positionalArguments[0] as String);
    });
    when(() => mockPreferencesService.exportPreferences()).thenAnswer((_) async => {});

    const password = 'TestPassword123!';
    final result = await realCreationService.generatePortableBackup(password);
    expect(result.isRight(), isTrue);

    final backupPath = result.getOrElse(() => throw Exception('')).backupFilePath;
    final encBytes = await File(backupPath).readAsBytes();
    final decBytes = await realCrypto.decrypt(encBytes, password);
    final archive = ZipDecoder().decodeBytes(decBytes);

    // ZIP debe contener exactamente el mismo canonical relative path
    expect(archive.files.map((f) => f.name), contains(canonicalPath));

    // Base de datos en snapshot debe conservar exactamente el mismo imagePath
    final dbEntry = archive.files.firstWhere((f) => f.name == 'gestor_gastos.db');
    final inspectDbFile = File(p.join(tempDocsDir.path, 'inspect_canonical.db'));
    await inspectDbFile.writeAsBytes(dbEntry.content as List<int>);
    final inspectDb = await openDatabase(inspectDbFile.path);
    final rows = await inspectDb.query('transactions');
    await inspectDb.close();
    await inspectDbFile.delete();

    expect(rows.first['imagePath'], canonicalPath);
  });

  test('REGRESIÓN: legacy absolute se normaliza a nuevo canonical relative', () async {
    final realCrypto = BackupCryptoService();
    final realCreationService = BackupCreationServiceImpl(
      snapshotService: mockSnapshotService,
      preferencesService: mockPreferencesService,
      attachmentService: fakeAttachmentService,
      cryptoService: realCrypto,
      appInfoProvider: mockAppInfoProvider,
      getDocsDirProvider: () async => tempDocsDir,
    );

    final legacyFile = File(p.join(tempDocsDir.path, 'legacy_dir', 'receipt_legacy.png'));
    await legacyFile.parent.create(recursive: true);
    await legacyFile.writeAsString('bytes legacy');
    fakeAttachmentService.mockResolvedPaths[legacyFile.path] = legacyFile.path;

    when(() => mockSnapshotService.createDatabaseSnapshot(any()))
        .thenAnswer((i) async {
      final db = await openDatabase(i.positionalArguments[0] as String,
          version: 1, onCreate: (db, version) async {
        await db.execute('CREATE TABLE transactions (id INTEGER PRIMARY KEY, imagePath TEXT)');
        await db.insert('transactions', {'id': 1, 'imagePath': legacyFile.path});
      });
      await db.close();
      return File(i.positionalArguments[0] as String);
    });
    when(() => mockPreferencesService.exportPreferences()).thenAnswer((_) async => {});

    const password = 'TestPassword123!';
    final result = await realCreationService.generatePortableBackup(password);
    expect(result.isRight(), isTrue);

    final backupPath = result.getOrElse(() => throw Exception('')).backupFilePath;
    final encBytes = await File(backupPath).readAsBytes();
    final decBytes = await realCrypto.decrypt(encBytes, password);
    final archive = ZipDecoder().decodeBytes(decBytes);

    final dbEntry = archive.files.firstWhere((f) => f.name == 'gestor_gastos.db');
    final inspectDbFile = File(p.join(tempDocsDir.path, 'inspect_legacy.db'));
    await inspectDbFile.writeAsBytes(dbEntry.content as List<int>);
    final inspectDb = await openDatabase(inspectDbFile.path);
    final rows = await inspectDb.query('transactions');
    await inspectDb.close();
    await inspectDbFile.delete();

    final normalizedPath = rows.first['imagePath'] as String;
    expect(normalizedPath != legacyFile.path, isTrue);
    expect(normalizedPath.startsWith('attachments/transactions/'), isTrue);
    expect(normalizedPath.endsWith('.png'), isTrue);
    expect(archive.files.map((f) => f.name), contains(normalizedPath));
  });

  test('REGRESIÓN: dos referencias idénticas al mismo canonical path -> una copia física y conservan mismo path', () async {
    final realCrypto = BackupCryptoService();
    final realCreationService = BackupCreationServiceImpl(
      snapshotService: mockSnapshotService,
      preferencesService: mockPreferencesService,
      attachmentService: fakeAttachmentService,
      cryptoService: realCrypto,
      appInfoProvider: mockAppInfoProvider,
      getDocsDirProvider: () async => tempDocsDir,
    );

    const canonicalPath = 'attachments/transactions/common_receipt.webp';
    final physicalFile = File(p.join(tempDocsDir.path, 'attachments', 'transactions', 'common_receipt.webp'));
    await physicalFile.parent.create(recursive: true);
    await physicalFile.writeAsString('bytes comunes');
    fakeAttachmentService.mockResolvedPaths[canonicalPath] = physicalFile.path;

    when(() => mockSnapshotService.createDatabaseSnapshot(any()))
        .thenAnswer((i) async {
      final db = await openDatabase(i.positionalArguments[0] as String,
          version: 1, onCreate: (db, version) async {
        await db.execute('CREATE TABLE transactions (id INTEGER PRIMARY KEY, imagePath TEXT)');
        await db.insert('transactions', {'id': 1, 'imagePath': canonicalPath});
        await db.insert('transactions', {'id': 2, 'imagePath': canonicalPath});
      });
      await db.close();
      return File(i.positionalArguments[0] as String);
    });
    when(() => mockPreferencesService.exportPreferences()).thenAnswer((_) async => {});

    const password = 'TestPassword123!';
    final result = await realCreationService.generatePortableBackup(password);
    expect(result.isRight(), isTrue);

    final backupPath = result.getOrElse(() => throw Exception('')).backupFilePath;
    final encBytes = await File(backupPath).readAsBytes();
    final decBytes = await realCrypto.decrypt(encBytes, password);
    final archive = ZipDecoder().decodeBytes(decBytes);

    final attachmentEntries = archive.files
        .where((f) => f.name.startsWith('attachments/transactions/'))
        .toList();
    expect(attachmentEntries.length, 1);
    expect(attachmentEntries.first.name, canonicalPath);

    final dbEntry = archive.files.firstWhere((f) => f.name == 'gestor_gastos.db');
    final inspectDbFile = File(p.join(tempDocsDir.path, 'inspect_dedup.db'));
    await inspectDbFile.writeAsBytes(dbEntry.content as List<int>);
    final inspectDb = await openDatabase(inspectDbFile.path);
    final rows = await inspectDb.query('transactions');
    await inspectDb.close();
    await inspectDbFile.delete();

    expect(rows.length, 2);
    expect(rows[0]['imagePath'], canonicalPath);
    expect(rows[1]['imagePath'], canonicalPath);
  });

  test('REGRESIÓN: mismo physical file con una referencia legacy y una canonical -> canonical gana independientemente del orden', () async {
    final realCrypto = BackupCryptoService();
    final realCreationService = BackupCreationServiceImpl(
      snapshotService: mockSnapshotService,
      preferencesService: mockPreferencesService,
      attachmentService: fakeAttachmentService,
      cryptoService: realCrypto,
      appInfoProvider: mockAppInfoProvider,
      getDocsDirProvider: () async => tempDocsDir,
    );

    const canonicalPath = 'attachments/transactions/winner_receipt.jpg';
    final physicalFile = File(p.join(tempDocsDir.path, 'attachments', 'transactions', 'winner_receipt.jpg'));
    await physicalFile.parent.create(recursive: true);
    await physicalFile.writeAsString('bytes compartidos');

    const legacyPath = 'C:\\old_photos\\receipt_old.jpg';
    fakeAttachmentService.mockResolvedPaths[canonicalPath] = physicalFile.path;
    fakeAttachmentService.mockResolvedPaths[legacyPath] = physicalFile.path;

    when(() => mockPreferencesService.exportPreferences()).thenAnswer((_) async => {});
    const password = 'TestPassword123!';

    // Subcaso A: canonical primero (id: 1), legacy después (id: 2)
    when(() => mockSnapshotService.createDatabaseSnapshot(any()))
        .thenAnswer((i) async {
      final db = await openDatabase(i.positionalArguments[0] as String,
          version: 1, onCreate: (db, version) async {
        await db.execute('CREATE TABLE transactions (id INTEGER PRIMARY KEY, imagePath TEXT)');
        await db.insert('transactions', {'id': 1, 'imagePath': canonicalPath});
        await db.insert('transactions', {'id': 2, 'imagePath': legacyPath});
      });
      await db.close();
      return File(i.positionalArguments[0] as String);
    });

    final resultA = await realCreationService.generatePortableBackup(password);
    expect(resultA.isRight(), isTrue);
    final backupPathA = resultA.getOrElse(() => throw Exception('')).backupFilePath;
    final encBytesA = await File(backupPathA).readAsBytes();
    final decBytesA = await realCrypto.decrypt(encBytesA, password);
    final archiveA = ZipDecoder().decodeBytes(decBytesA);

    final dbEntryA = archiveA.files.firstWhere((f) => f.name == 'gestor_gastos.db');
    final inspectDbFileA = File(p.join(tempDocsDir.path, 'inspect_order_a.db'));
    await inspectDbFileA.writeAsBytes(dbEntryA.content as List<int>);
    final inspectDbA = await openDatabase(inspectDbFileA.path);
    final rowsA = await inspectDbA.query('transactions', orderBy: 'id ASC');
    await inspectDbA.close();
    await inspectDbFileA.delete();

    expect(rowsA[0]['imagePath'], canonicalPath);
    expect(rowsA[1]['imagePath'], canonicalPath);

    // Subcaso B: legacy primero (id: 1), canonical después (id: 2)
    when(() => mockSnapshotService.createDatabaseSnapshot(any()))
        .thenAnswer((i) async {
      final db = await openDatabase(i.positionalArguments[0] as String,
          version: 1, onCreate: (db, version) async {
        await db.execute('CREATE TABLE transactions (id INTEGER PRIMARY KEY, imagePath TEXT)');
        await db.insert('transactions', {'id': 1, 'imagePath': legacyPath});
        await db.insert('transactions', {'id': 2, 'imagePath': canonicalPath});
      });
      await db.close();
      return File(i.positionalArguments[0] as String);
    });

    final resultB = await realCreationService.generatePortableBackup(password);
    expect(resultB.isRight(), isTrue);
    final backupPathB = resultB.getOrElse(() => throw Exception('')).backupFilePath;
    final encBytesB = await File(backupPathB).readAsBytes();
    final decBytesB = await realCrypto.decrypt(encBytesB, password);
    final archiveB = ZipDecoder().decodeBytes(decBytesB);

    final dbEntryB = archiveB.files.firstWhere((f) => f.name == 'gestor_gastos.db');
    final inspectDbFileB = File(p.join(tempDocsDir.path, 'inspect_order_b.db'));
    await inspectDbFileB.writeAsBytes(dbEntryB.content as List<int>);
    final inspectDbB = await openDatabase(inspectDbFileB.path);
    final rowsB = await inspectDbB.query('transactions', orderBy: 'id ASC');
    await inspectDbB.close();
    await inspectDbFileB.delete();

    // En ambos subcasos, independientemente del orden, gana el path canónico
    expect(rowsB[0]['imagePath'], canonicalPath);
    expect(rowsB[1]['imagePath'], canonicalPath);
  });
}
