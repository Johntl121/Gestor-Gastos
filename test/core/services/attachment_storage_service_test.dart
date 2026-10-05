import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:gestor_gastos/core/services/attachment_storage_service.dart';

void main() {
  late AttachmentStorageServiceImpl service;
  late Directory mockDocsDir;

  setUp(() async {
    // Create a temporary directory to act as getApplicationDocumentsDirectory
    mockDocsDir = await Directory.systemTemp.createTemp('mock_docs_dir');
    service = AttachmentStorageServiceImpl(
      getDocsDirProvider: () async => mockDocsDir,
    );
  });

  tearDown(() async {
    if (await mockDocsDir.exists()) {
      await mockDocsDir.delete(recursive: true);
    }
  });

  group('AttachmentStorageService - Save', () {
    test('saveTransactionAttachment crea archivo bajo attachments/transactions/ con relativa', () async {
      final sourceFile = File(p.join(mockDocsDir.path, 'source_test.jpg'));
      await sourceFile.writeAsString('dummy_content');

      final relativePath = await service.saveTransactionAttachment(sourceFile.path);

      expect(relativePath.startsWith('attachments/transactions/'), isTrue);
      expect(relativePath.endsWith('.jpg'), isTrue);

      final absDest = p.join(mockDocsDir.path, relativePath);
      expect(await File(absDest).exists(), isTrue);
      expect(await File(absDest).readAsString(), 'dummy_content');
    });

    test('dos saves generan nombres distintos', () async {
      final sourceFile = File(p.join(mockDocsDir.path, 'source.jpg'))..writeAsStringSync('a');
      final r1 = await service.saveTransactionAttachment(sourceFile.path);
      final r2 = await service.saveTransactionAttachment(sourceFile.path);

      expect(r1, isNot(equals(r2)));
    });

    test('extensión válida (.png) es conservada', () async {
      final sourceFile = File(p.join(mockDocsDir.path, 'source_test.png'))..writeAsStringSync('x');
      final relativePath = await service.saveTransactionAttachment(sourceFile.path);
      
      expect(relativePath.endsWith('.png'), isTrue);
    });

    test('extensión no admitida (.exe) o vacía usa fallback .jpg', () async {
      final sourceExe = File(p.join(mockDocsDir.path, 'virus.exe'))..writeAsStringSync('x');
      final sourceNone = File(p.join(mockDocsDir.path, 'file_no_ext'))..writeAsStringSync('x');
      
      final rExe = await service.saveTransactionAttachment(sourceExe.path);
      final rNone = await service.saveTransactionAttachment(sourceNone.path);
      
      expect(rExe.endsWith('.jpg'), isTrue);
      expect(rExe.endsWith('.exe'), isFalse);
      
      expect(rNone.endsWith('.jpg'), isTrue);
    });
  });

  group('AttachmentStorageService - Resolve & Protection', () {
    test('resolve relative válido', () async {
      const safePath = 'attachments/transactions/1234.jpg';
      final file = File(p.join(mockDocsDir.path, safePath));
      await file.parent.create(recursive: true);
      await file.writeAsString('test');

      final resolved = await service.resolveAbsolutePath(safePath);
      expect(resolved, file.path);
      expect(await service.exists(safePath), isTrue);
    });

    test('resolve legacy absolute existente', () async {
      final legacyFile = File(p.join(mockDocsDir.path, 'legacy_absolute.jpg'));
      await legacyFile.writeAsString('legacy');

      final resolved = await service.resolveAbsolutePath(legacyFile.path);
      expect(resolved, legacyFile.path);
    });

    test('legacy inexistente -> null', () async {
      final fakeLegacy = p.join(mockDocsDir.path, 'non_existent.jpg');
      final resolved = await service.resolveAbsolutePath(fakeLegacy);
      expect(resolved, isNull);
    });

    test('relative inexistente -> null', () async {
      const fakeRelative = 'attachments/transactions/ghost.jpg';
      final resolved = await service.resolveAbsolutePath(fakeRelative);
      expect(resolved, isNull);
    });

    test('../ path traversal rechazado (devuelve null)', () async {
      const maliciousPath = 'attachments/transactions/../../hacked.txt';
      final resolved = await service.resolveAbsolutePath(maliciousPath);
      expect(resolved, isNull);
    });

    test('absolute externo no se interpreta como relative y si no existe da null', () async {
      final extAbs = p.join(mockDocsDir.path, '..', 'external.jpg');
      final resolved = await service.resolveAbsolutePath(extAbs);
      expect(resolved, isNull);
    });
  });

  group('AttachmentStorageService - Delete', () {
    test('delete existente lo borra', () async {
      const safePath = 'attachments/transactions/todelete.jpg';
      final file = File(p.join(mockDocsDir.path, safePath));
      await file.parent.create(recursive: true);
      await file.writeAsString('test');

      await service.deleteAttachment(safePath);

      expect(await file.exists(), isFalse);
      expect(await service.exists(safePath), isFalse);
    });

    test('delete inexistente no falla (best-effort)', () async {
      const safePath = 'attachments/transactions/ghost.jpg';
      
      // Si falla, el test tirará excepción. Solo lo invocamos.
      await service.deleteAttachment(safePath);
      expect(true, isTrue); // Llego aquí sin crash
    });

    test('delete absolute legacy interno -> sí lo borra', () async {
      final legacyFile = File(p.join(mockDocsDir.path, 'legacy_absolute_delete.jpg'));
      await legacyFile.writeAsString('legacy');

      await service.deleteAttachment(legacyFile.path);

      expect(await legacyFile.exists(), isFalse);
    });

    test('delete absolute legacy externo -> NO lo borra', () async {
      final extDir = await Directory.systemTemp.createTemp('external_mock_dir');
      final externalFile = File(p.join(extDir.path, 'external_delete.jpg'));
      await externalFile.writeAsString('external');

      await service.deleteAttachment(externalFile.path);

      // Debería seguir existiendo porque no está en mockDocsDir
      expect(await externalFile.exists(), isTrue);

      await extDir.delete(recursive: true);
    });
  });

  group('AttachmentStorageService - Maintenance Lock', () {
    test('executeMaintenance locks mutations', () async {
      final sourceFile = File(p.join(mockDocsDir.path, 'source_test.jpg'))..writeAsStringSync('dummy_content');

      bool maintenanceFinished = false;
      bool saveFinished = false;

      // Start maintenance that takes some time
      final maintenanceFuture = service.executeMaintenance(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        maintenanceFinished = true;
      });

      // Attempt to save an attachment while maintenance is running
      final saveFuture = service.saveTransactionAttachment(sourceFile.path).then((_) {
        saveFinished = true;
      });

      // Verify that save is waiting for maintenance
      await Future.delayed(const Duration(milliseconds: 20));
      expect(maintenanceFinished, isFalse);
      expect(saveFinished, isFalse); // Save shouldn't finish while maintenance is running

      await maintenanceFuture;
      expect(maintenanceFinished, isTrue);

      await saveFuture;
      expect(saveFinished, isTrue); // Save finishes after maintenance
    });

    test('executeMaintenance releases lock on exception', () async {
      final sourceFile = File(p.join(mockDocsDir.path, 'source_test.jpg'))..writeAsStringSync('dummy_content');

      try {
        await service.executeMaintenance(() async {
          throw Exception('Maintenance Error');
        });
      } catch (e) {
        expect(e.toString(), contains('Maintenance Error'));
      }

      // Next save should run fine
      final path = await service.saveTransactionAttachment(sourceFile.path);
      expect(path, isNotEmpty);
    });
  });
}
