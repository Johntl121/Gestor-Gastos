import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:archive/archive_io.dart';

import '../../core/errors/backup_exceptions.dart';
import '../../core/errors/failure.dart';
import '../../core/services/app_info_provider.dart';
import '../../core/services/attachment_storage_service.dart';
import '../../core/services/backup_crypto_service.dart';
import '../../core/services/backup_preferences_service.dart';
import '../../core/services/snapshot_service.dart';
import '../../domain/services/backup_creation_service.dart';

class BackupCreationServiceImpl implements BackupCreationService {
  final SnapshotService _snapshotService;
  final BackupPreferencesService _preferencesService;
  final AttachmentStorageService _attachmentService;
  final BackupCryptoService _cryptoService;
  final AppInfoProvider _appInfoProvider;
  final Future<Directory> Function() _getDocsDirProvider;
  final int _maxPlaintextZipBytes;

  BackupCreationServiceImpl({
    required SnapshotService snapshotService,
    required BackupPreferencesService preferencesService,
    required AttachmentStorageService attachmentService,
    required BackupCryptoService cryptoService,
    required AppInfoProvider appInfoProvider,
    Future<Directory> Function()? getDocsDirProvider,
    int maxPlaintextZipBytes = 50 * 1024 * 1024,
  })  : _snapshotService = snapshotService,
        _preferencesService = preferencesService,
        _attachmentService = attachmentService,
        _cryptoService = cryptoService,
        _appInfoProvider = appInfoProvider,
        _getDocsDirProvider = getDocsDirProvider ?? getApplicationDocumentsDirectory,
        _maxPlaintextZipBytes = maxPlaintextZipBytes;

  @override
  Future<Either<Failure, BackupCreationResult>> generatePortableBackup(String password) async {
    final docsDir = await _getDocsDirProvider();
    final stagingDirName = 'backup_staging_${const Uuid().v4()}';
    final stagingDir = Directory(p.join(docsDir.path, stagingDirName));
    
    final dbSnapshotPath = p.join(stagingDir.path, 'gestor_gastos.db');
    final zipPlaintextPath = p.join(docsDir.path, '$stagingDirName.zip');
    final tempOutputPath = p.join(docsDir.path, '$stagingDirName.gestorbackup.tmp');
    final finalOutputPath = p.join(docsDir.path, 'backup_${DateTime.now().millisecondsSinceEpoch}.gestorbackup');

    int attachmentsIncluded = 0;
    int attachmentsMissing = 0;
    int dbSchemaVersion = 1;

    try {
      await stagingDir.create(recursive: true);

      // 1. Critical window: DB Snapshot + Attachments with Mutex
      await _attachmentService.executeMaintenance(() async {
        // Create DB snapshot
        await _snapshotService.createDatabaseSnapshot(dbSnapshotPath);

        // Open snapshot and normalize paths / copy attachments
        Database? snapshotDb;
        try {
          snapshotDb = await openDatabase(dbSnapshotPath, singleInstance: false);

          final versionResult = await snapshotDb.rawQuery('PRAGMA user_version;');
          if (versionResult.isNotEmpty) {
            dbSchemaVersion = versionResult.first.values.first as int? ?? 1;
          }

          final attachmentsDir = Directory(p.join(stagingDir.path, 'attachments', 'transactions'));
          await attachmentsDir.create(recursive: true);

          final rows = await snapshotDb.query(
            'transactions',
            columns: ['id', 'imagePath'],
            where: 'imagePath IS NOT NULL',
          );

          final Map<String, String> physicalSourceToRelativePath = {};

          for (final row in rows) {
            final id = row['id'] as int;
            final storedPath = row['imagePath'] as String;

            final physicalPath = await _attachmentService.resolveAbsolutePath(storedPath);

            if (physicalPath == null || !(await File(physicalPath).exists())) {
              // Missing attachment
              attachmentsMissing++;
              await snapshotDb.update(
                'transactions',
                {'imagePath': null},
                where: 'id = ?',
                whereArgs: [id],
              );
            } else {
              // Attachment exists, deduplicate
              String newRelativePath;
              if (physicalSourceToRelativePath.containsKey(physicalPath)) {
                newRelativePath = physicalSourceToRelativePath[physicalPath]!;
              } else {
                final ext = p.extension(physicalPath);
                newRelativePath = 'attachments/transactions/${const Uuid().v4()}$ext';
                final stagingDestPath = p.join(stagingDir.path, newRelativePath);
                
                await File(physicalPath).copy(stagingDestPath);
                physicalSourceToRelativePath[physicalPath] = newRelativePath;
              }

              attachmentsIncluded++;
              await snapshotDb.update(
                'transactions',
                {'imagePath': newRelativePath},
                where: 'id = ?',
                whereArgs: [id],
              );
            }
          }
        } finally {
          await snapshotDb?.close();
        }
      });
      // Lock released!

      // 2. Preferences
      final prefsData = await _preferencesService.exportPreferences();
      final prefsFile = File(p.join(stagingDir.path, 'preferences.json'));
      await prefsFile.writeAsString(jsonEncode(prefsData));

      // 3. Manifest
      final appVersion = await _appInfoProvider.getAppVersion();
      final manifestMap = {
        'payloadVersion': 1,
        'appVersion': appVersion,
        'databaseSchemaVersion': dbSchemaVersion,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'components': ['database', 'preferences', 'transactionAttachments'],
        'transactionAttachmentsIncluded': attachmentsIncluded,
        'transactionAttachmentsMissing': attachmentsMissing,
      };
      final manifestFile = File(p.join(stagingDir.path, 'manifest.json'));
      await manifestFile.writeAsString(jsonEncode(manifestMap));

      // 4. ZIP Encoding (Directly to disk)
      final encoder = ZipFileEncoder();
      encoder.create(zipPlaintextPath);
      encoder.addDirectory(stagingDir, includeDirName: false);
      encoder.close();

      // 5. Size check
      final zipFile = File(zipPlaintextPath);
      if (!await zipFile.exists()) {
        throw BackupException('No se pudo generar el archivo ZIP temporal.');
      }
      final zipLength = await zipFile.length();
      if (zipLength > _maxPlaintextZipBytes) {
        throw BackupTooLargeException(
          'El archivo de copia (${(zipLength / 1024 / 1024).toStringAsFixed(1)} MB) '
          'supera el límite técnico temporal de Backup V1 (${_maxPlaintextZipBytes ~/ (1024 * 1024)} MB).',
        );
      }

      // 6. Crypto V1
      final payloadBytes = await zipFile.readAsBytes();
      final encryptedBytes = await _cryptoService.encrypt(payloadBytes, password);

      // 7. Output and rename
      final tempOutputFile = File(tempOutputPath);
      await tempOutputFile.writeAsBytes(encryptedBytes, flush: true);
      final finalFile = await tempOutputFile.rename(finalOutputPath);
      
      final finalLength = await finalFile.length();

      return Right(BackupCreationResult(
        finalFile.path,
        attachmentsIncluded,
        attachmentsMissing,
        finalLength,
      ));

    } catch (e) {
      if (e is BackupException) {
        return Left(CacheFailure(e.toString()));
      }
      return Left(CacheFailure('Fallo al generar el backup: $e'));
    } finally {
      // 8. Cleanup
      try {
        if (await stagingDir.exists()) await stagingDir.delete(recursive: true);
      } catch (_) {}
      try {
        final zipPlaintext = File(zipPlaintextPath);
        if (await zipPlaintext.exists()) await zipPlaintext.delete();
      } catch (_) {}
      try {
        final tempOutputFile = File(tempOutputPath);
        if (await tempOutputFile.exists()) await tempOutputFile.delete();
      } catch (_) {}
    }
  }
}
