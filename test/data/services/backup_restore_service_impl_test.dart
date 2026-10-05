// ignore_for_file: unused_import, unused_element
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:gestor_gastos/core/constants/backup_v1_limits.dart';
import 'package:gestor_gastos/core/services/app_info_provider.dart';
import 'package:gestor_gastos/core/services/attachment_storage_service.dart';
import 'package:gestor_gastos/core/services/backup_crypto_service.dart';
import 'package:gestor_gastos/core/services/backup_preferences_service.dart';
import 'package:gestor_gastos/core/services/restore_service.dart';
import 'package:gestor_gastos/data/services/backup_restore_service_impl.dart';

class MockRestoreService extends Mock implements RestoreService {}

class MockPreferencesService extends Mock implements BackupPreferencesService {}

class MockCryptoService extends Mock implements BackupCryptoService {}

class MockAppInfoProvider extends Mock implements AppInfoProvider {}

class FakeAttachmentService extends Fake implements AttachmentStorageService {
  @override
  Future<T> executeMaintenance<T>(Future<T> Function() action) {
    return action();
  }
}

void main() {
  late BackupRestoreServiceImpl service;
  late MockRestoreService mockRestoreService;
  late MockPreferencesService mockPreferencesService;
  late FakeAttachmentService fakeAttachmentService;
  late MockCryptoService mockCryptoService;
  late MockAppInfoProvider mockAppInfoProvider;

  late Directory tempDocsDir;
  late String password;

  setUp(() async {
    tempDocsDir = await Directory.systemTemp.createTemp('backup_restore_test');

    mockRestoreService = MockRestoreService();
    mockPreferencesService = MockPreferencesService();
    fakeAttachmentService = FakeAttachmentService();
    mockCryptoService = MockCryptoService();
    mockAppInfoProvider = MockAppInfoProvider();

    password = 'password123';

    service = BackupRestoreServiceImpl(
      restoreService: mockRestoreService,
      preferencesService: mockPreferencesService,
      attachmentService: fakeAttachmentService,
      cryptoService: mockCryptoService,
      appInfoProvider: mockAppInfoProvider,
      getDocsDirProvider: () async => tempDocsDir,
    );
  });

  tearDown(() async {
    if (await tempDocsDir.exists()) {
      await tempDocsDir.delete(recursive: true);
    }
  });

  Future<String> createMockEncryptedBackup({
    bool includeAttachments = false,
    bool validManifest = true,
    int? sizeOverride,
  }) async {
    final stagingDir = Directory(
        p.join(tempDocsDir.path, 'create_staging_${const Uuid().v4()}'));
    await stagingDir.create();

    if (validManifest) {
      final manifestMap = {
        'payloadVersion': 1,
        'appVersion': '1.0.0',
        'databaseSchemaVersion': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'components': ['database', 'preferences', 'transactionAttachments'],
        'transactionAttachmentsIncluded': includeAttachments ? 1 : 0,
        'transactionAttachmentsMissing': 0,
      };
      await File(p.join(stagingDir.path, 'manifest.json'))
          .writeAsString(jsonEncode(manifestMap));
    }

    // Dummy DB
    await File(p.join(stagingDir.path, 'gestor_gastos.db'))
        .writeAsString('dummy db content');

    // Preferences
    await File(p.join(stagingDir.path, 'preferences.json'))
        .writeAsString(jsonEncode({'a': 'b'}));

    if (includeAttachments) {
      final attachmentsDir =
          Directory(p.join(stagingDir.path, 'attachments', 'transactions'));
      await attachmentsDir.create(recursive: true);
      await File(p.join(attachmentsDir.path, 'test.jpg'))
          .writeAsString('image data');
    }

    final zipPath = p.join(tempDocsDir.path, 'temp.zip');
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    encoder.addDirectory(stagingDir, includeDirName: false);
    encoder.close();

    final zipBytes = await File(zipPath).readAsBytes();

    when(() => mockCryptoService.decrypt(any(), password))
        .thenAnswer((_) async => zipBytes);

    final encryptedPath = p.join(tempDocsDir.path, 'backup.gestorbackup');
    final file = File(encryptedPath);
    await file.writeAsBytes(zipBytes);

    await stagingDir.delete(recursive: true);
    await File(zipPath).delete();

    return encryptedPath;
  }

  test('MAX encrypted input V1 pre-read: > 52MB falla sin procesar', () async {
    final file = File(p.join(tempDocsDir.path, 'large.gestorbackup'));
    final dummyBytes = List<int>.filled(53 * 1024 * 1024, 0); // 53 MiB
    await file.writeAsBytes(dummyBytes);

    final result = await service.restorePortableBackup(file.path, password);

    expect(result.isLeft(), isTrue);
    result.fold(
      (l) => expect(l.message, contains('excede el tamaño máximo permitido')),
      (r) => fail('Debería fallar'),
    );
  });
}
