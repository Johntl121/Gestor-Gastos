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
import '../../core/constants/backup_v1_limits.dart';
import '../../core/services/snapshot_service.dart';
import '../../domain/services/backup_creation_service.dart';

class BackupCreationServiceImpl implements BackupCreationService {
  final SnapshotService _snapshotService;
  final BackupPreferencesService _preferencesService;
  final AttachmentStorageService _attachmentService;
  final BackupCryptoService _cryptoService;
  final AppInfoProvider _appInfoProvider;
  final Future<Directory> Function() _getDocsDirProvider;
  final int? _maxPlaintextZipBytesOverride;
  final int? _maxUncompressedPayloadBytesOverride;
  final int? _maxEntriesOverride;

  BackupCreationServiceImpl({
    required SnapshotService snapshotService,
    required BackupPreferencesService preferencesService,
    required AttachmentStorageService attachmentService,
    required BackupCryptoService cryptoService,
    required AppInfoProvider appInfoProvider,
    Future<Directory> Function()? getDocsDirProvider,
    int? maxPlaintextZipBytesOverride,
    int? maxUncompressedPayloadBytesOverride,
    int? maxEntriesOverride,
  })  : _snapshotService = snapshotService,
        _preferencesService = preferencesService,
        _attachmentService = attachmentService,
        _cryptoService = cryptoService,
        _appInfoProvider = appInfoProvider,
        _getDocsDirProvider =
            getDocsDirProvider ?? getApplicationDocumentsDirectory,
        _maxPlaintextZipBytesOverride = maxPlaintextZipBytesOverride,
        _maxUncompressedPayloadBytesOverride =
            maxUncompressedPayloadBytesOverride,
        _maxEntriesOverride = maxEntriesOverride;

  int get _maxPlaintextZipBytes =>
      _maxPlaintextZipBytesOverride ?? BackupV1Limits.maxPlaintextZipBytes;
  int get _maxUncompressedPayloadBytes =>
      _maxUncompressedPayloadBytesOverride ??
      BackupV1Limits.maxUncompressedPayloadBytes;
  int get _maxEntries => _maxEntriesOverride ?? BackupV1Limits.maxEntries;

  @override
  Future<Either<Failure, BackupCreationResult>> generatePortableBackup(
      String password) async {
    final docsDir = await _getDocsDirProvider();
    final stagingDirName = 'backup_staging_${const Uuid().v4()}';
    final stagingDir = Directory(p.join(docsDir.path, stagingDirName));

    final dbSnapshotPath = p.join(stagingDir.path, 'gestor_gastos.db');
    final zipPlaintextPath = p.join(docsDir.path, '$stagingDirName.zip');
    final tempOutputPath =
        p.join(docsDir.path, '$stagingDirName.gestorbackup.tmp');
    final finalOutputPath = p.join(docsDir.path,
        'backup_${DateTime.now().millisecondsSinceEpoch}.gestorbackup');

    int attachmentsIncluded = 0;
    int attachmentsMissing = 0;
    int dbSchemaVersion = 1;
    final List<String> deduplicatedRelativePaths = [];

    try {
      // 0. Cleanup previous temp backups
      try {
        final dir = Directory(docsDir.path);
        if (await dir.exists()) {
          final entities = dir.listSync();
          for (var entity in entities) {
            if (entity is File && p.basename(entity.path).startsWith('backup_') && p.basename(entity.path).endsWith('.gestorbackup')) {
              await entity.delete();
            }
          }
        }
      } catch (_) {}

      await stagingDir.create(recursive: true);

      // 1. Critical window: DB Snapshot + Attachments with Mutex
      await _attachmentService.executeMaintenance(() async {
        // Create DB snapshot
        await _snapshotService.createDatabaseSnapshot(dbSnapshotPath);

        // Open snapshot and normalize paths / copy attachments
        Database? snapshotDb;
        try {
          snapshotDb =
              await openDatabase(dbSnapshotPath, singleInstance: false);

          final versionResult =
              await snapshotDb.rawQuery('PRAGMA user_version;');
          if (versionResult.isNotEmpty) {
            dbSchemaVersion = versionResult.first.values.first as int? ?? 1;
          }

          final attachmentsDir =
              Directory(p.join(stagingDir.path, 'attachments', 'transactions'));
          await attachmentsDir.create(recursive: true);

          final rows = await snapshotDb.query(
            'transactions',
            columns: ['id', 'imagePath'],
            where: 'imagePath IS NOT NULL',
          );

          final List<_AttachmentReference> validReferences = [];

          for (final row in rows) {
            final id = row['id'] as int;
            final storedPath = row['imagePath'] as String;

            final physicalPath =
                await _attachmentService.resolveAbsolutePath(storedPath);

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
              validReferences.add(_AttachmentReference(
                transactionId: id,
                storedPath: storedPath,
                physicalPath: physicalPath,
              ));
            }
          }

          // Agrupar referencias por archivo físico para deduplicación determinista
          final Map<String, List<_AttachmentReference>> physicalPathGroups = {};
          for (final ref in validReferences) {
            physicalPathGroups
                .putIfAbsent(ref.physicalPath, () => [])
                .add(ref);
          }

          for (final entry in physicalPathGroups.entries) {
            final physicalPath = entry.key;
            final refs = entry.value;

            // Determinar candidatos canónicos relativos válidos
            final canonicalCandidates = refs
                .map((r) => r.storedPath.replaceAll('\\', '/'))
                .where(isCanonicalRelativePath)
                .toSet()
                .toList()
              ..sort();

            final String chosenRelativePath;
            if (canonicalCandidates.isNotEmpty) {
              chosenRelativePath = canonicalCandidates.first;
            } else {
              final ext = p.extension(physicalPath);
              chosenRelativePath =
                  'attachments/transactions/${const Uuid().v4()}$ext';
            }

            final stagingDestPath = p.joinAll([
              stagingDir.path,
              ...p.posix.split(chosenRelativePath),
            ]);
            final stagingDestFile = File(stagingDestPath);
            await stagingDestFile.parent.create(recursive: true);
            await File(physicalPath).copy(stagingDestPath);

            deduplicatedRelativePaths.add(chosenRelativePath);

            for (final ref in refs) {
              attachmentsIncluded++;
              if (ref.storedPath != chosenRelativePath) {
                await snapshotDb.update(
                  'transactions',
                  {'imagePath': chosenRelativePath},
                  where: 'id = ?',
                  whereArgs: [ref.transactionId],
                );
              }
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

      // 4. Pre-zip structural validation
      int uncompressedBytes = 0;
      int entriesCount = 0;

      Future<void> addFileToCounts(File file) async {
        if (await file.exists()) {
          uncompressedBytes += await file.length();
          entriesCount++;
        }
      }

      await addFileToCounts(File(dbSnapshotPath));
      await addFileToCounts(prefsFile);
      await addFileToCounts(manifestFile);

      for (final relativePath in deduplicatedRelativePaths) {
        final archivePath = relativePath.replaceAll('\\', '/');
        final sourcePath = p.joinAll([
          stagingDir.path,
          ...p.posix.split(archivePath),
        ]);
        await addFileToCounts(File(sourcePath));
      }

      if (uncompressedBytes > _maxUncompressedPayloadBytes ||
          entriesCount > _maxEntries) {
        throw BackupTooLargeException(
          'El contenido a respaldar (descomprimido: ${(uncompressedBytes / 1024 / 1024).toStringAsFixed(1)} MB, '
          'archivos: $entriesCount) supera los límites permitidos de Backup V1.',
        );
      }

      // 5. ZIP Encoding (Directly to disk con rutas normalizadas POSIX)
      final encoder = ZipFileEncoder();
      encoder.create(zipPlaintextPath);

      try {
        await encoder.addFile(File(dbSnapshotPath), 'gestor_gastos.db');
        await encoder.addFile(prefsFile, 'preferences.json');
        await encoder.addFile(manifestFile, 'manifest.json');

        for (final relativePath in deduplicatedRelativePaths) {
          final archivePath = relativePath.replaceAll('\\', '/');
          final sourcePath = p.joinAll([
            stagingDir.path,
            ...p.posix.split(archivePath),
          ]);
          await encoder.addFile(File(sourcePath), archivePath);
        }
      } finally {
        await encoder.close();
      }

      // 6. Size check
      final zipFile = File(zipPlaintextPath);
      if (!await zipFile.exists()) {
        throw BackupException('No se pudo generar el archivo ZIP temporal.');
      }
      final zipLength = await zipFile.length();
      if (zipLength > _maxPlaintextZipBytes) {
        throw BackupTooLargeException(
          'El archivo de copia comprimido (${(zipLength / 1024 / 1024).toStringAsFixed(1)} MB) '
          'supera el límite técnico temporal de Backup V1 (${_maxPlaintextZipBytes ~/ (1024 * 1024)} MB).',
        );
      }

      // 7. Crypto V1
      final payloadBytes = await zipFile.readAsBytes();
      final encryptedBytes =
          await _cryptoService.encrypt(payloadBytes, password);

      // 8. Output and rename
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
      // 9. Cleanup
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

  static const String _transactionsNamespace = 'attachments/transactions';

  /// Valida si un path almacenado en DB es un path canónico relativo seguro
  /// conforme al namespace canónico de la aplicación.
  static bool isCanonicalRelativePath(String relativePath) {
    if (p.isAbsolute(relativePath)) return false;
    if (relativePath.contains('..')) return false;
    final normalized = p.normalize(relativePath).replaceAll('\\', '/');
    if (normalized.startsWith('..')) return false;
    if (!normalized.startsWith('$_transactionsNamespace/')) return false;
    final fileName = normalized.substring('$_transactionsNamespace/'.length);
    if (fileName.isEmpty || fileName.contains('/')) return false;
    return true;
  }
}

class _AttachmentReference {
  final int transactionId;
  final String storedPath;
  final String physicalPath;

  _AttachmentReference({
    required this.transactionId,
    required this.storedPath,
    required this.physicalPath,
  });
}
