import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:dartz/dartz.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/backup_v1_limits.dart';
import '../../core/errors/backup_exceptions.dart';
import '../../core/errors/failure.dart';
import '../../core/services/app_info_provider.dart';
import '../../core/services/attachment_storage_service.dart';
import '../../core/services/backup_crypto_service.dart';
import '../../core/services/backup_preferences_service.dart';
import '../../core/services/restore_service.dart';
import '../../domain/entities/backup_restore_result.dart';
import '../../domain/services/backup_restore_service.dart';

class BackupRestoreServiceImpl implements BackupRestoreService {
  final RestoreService _restoreService;
  final BackupPreferencesService _preferencesService;
  final AttachmentStorageService _attachmentService;
  final BackupCryptoService _cryptoService;
  // ignore: unused_field
  final AppInfoProvider _appInfoProvider;
  final Future<Directory> Function() _getDocsDirProvider;

  BackupRestoreServiceImpl({
    required RestoreService restoreService,
    required BackupPreferencesService preferencesService,
    required AttachmentStorageService attachmentService,
    required BackupCryptoService cryptoService,
    required AppInfoProvider appInfoProvider,
    Future<Directory> Function()? getDocsDirProvider,
  })  : _restoreService = restoreService,
        _preferencesService = preferencesService,
        _attachmentService = attachmentService,
        _cryptoService = cryptoService,
        _appInfoProvider = appInfoProvider,
        _getDocsDirProvider =
            getDocsDirProvider ?? getApplicationDocumentsDirectory;

  @override
  Future<Either<Failure, BackupRestoreResult>> restorePortableBackup(
    String backupPath,
    String password,
  ) async {
    final docsDir = await _getDocsDirProvider();
    final stagingId = const Uuid().v4();
    final stagingDir =
        Directory(p.join(docsDir.path, 'backup_staging_$stagingId'));
    final zipPlaintextPath =
        p.join(docsDir.path, 'backup_staging_$stagingId.zip');

    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw BackupException('El archivo de respaldo no existe.');
      }
      final backupLength = await backupFile.length();
      if (backupLength > BackupV1Limits.maxEncryptedContainerBytes) {
        throw BackupTooLargeException(
            'El archivo cifrado excede el tamaño máximo permitido.');
      }

      final encryptedBytes = await backupFile.readAsBytes();
      final plaintextBytes =
          await _cryptoService.decrypt(encryptedBytes, password);

      final zipPlaintext = File(zipPlaintextPath);
      await zipPlaintext.writeAsBytes(plaintextBytes, flush: true);

      await stagingDir.create(recursive: true);

      final inputStream = InputFileStream(zipPlaintextPath);
      final archive = ZipDecoder().decodeStream(inputStream);

      int uncompressedBytes = 0;
      int entriesCount = 0;

      for (final file in archive.files) {
        if (!file.isFile) {
          if (!file.name.endsWith('/')) {
            throw ZipSecurityException(
                'Entrada especial no permitida: ${file.name}');
          }
          continue;
        }

        if (file.name.contains('..') ||
            file.name.startsWith('/') ||
            file.name.startsWith('\\')) {
          throw ZipSecurityException(
              'Intento de path traversal detectado: ${file.name}');
        }

        // Whitelist validation
        final isManifest = file.name == 'manifest.json';
        final isDb = file.name == 'gestor_gastos.db';
        final isPrefs = file.name == 'preferences.json';
        final isAttachment =
            file.name.startsWith('attachments/transactions/') &&
                !file.name
                    .substring('attachments/transactions/'.length)
                    .contains('/');

        if (!isManifest && !isDb && !isPrefs && !isAttachment) {
          throw BackupFormatException(
              'El respaldo contiene archivos no permitidos: ${file.name}');
        }

        final fileSize = file.size.toInt();
        uncompressedBytes += fileSize;
        entriesCount++;

        if (fileSize > BackupV1Limits.maxSingleFileBytes) {
          throw BackupTooLargeException(
              'Un archivo dentro del respaldo excede el límite permitido: ${file.name}');
        }
        if (uncompressedBytes > BackupV1Limits.maxUncompressedPayloadBytes) {
          throw BackupTooLargeException(
              'El contenido descomprimido excede el límite permitido.');
        }
        if (entriesCount > BackupV1Limits.maxEntries) {
          throw BackupTooLargeException(
              'El número de archivos excede el límite permitido.');
        }

        final outputPath = p.join(stagingDir.path, file.name);
        final outputFile = File(outputPath);
        await outputFile.parent.create(recursive: true);

        final outStream = OutputFileStream(outputPath);
        file.writeContent(outStream);
        outStream.close();
      }
      inputStream.close();

      final manifestFile = File(p.join(stagingDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw BackupFormatException('Falta el manifest.json en el respaldo.');
      }
      final manifestJson = jsonDecode(await manifestFile.readAsString());
      if (manifestJson['payloadVersion'] != 1) {
        throw BackupVersionException(
            'Versión de payload no soportada: ${manifestJson['payloadVersion']}');
      }

      final manifestSchemaVersion =
          manifestJson['databaseSchemaVersion'] as int;
      final manifestAttachmentsIncluded =
          manifestJson['transactionAttachmentsIncluded'] as int;

      final dbFile = File(p.join(stagingDir.path, 'gestor_gastos.db'));
      if (!await dbFile.exists()) {
        throw BackupFormatException('Falta la base de datos en el respaldo.');
      }

      final prefsFile = File(p.join(stagingDir.path, 'preferences.json'));
      if (await prefsFile.exists()) {
        final content = await prefsFile.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is! Map<String, dynamic>) {
          throw BackupFormatException(
              'El archivo preferences.json no es un objeto válido.');
        }
      }

      Database? stagingDb;
      int attachmentsMissing = 0;

      try {
        stagingDb = await openDatabase(dbFile.path, singleInstance: false);

        final versionResult = await stagingDb.rawQuery('PRAGMA user_version;');
        final dbSchemaVersion = versionResult.isNotEmpty
            ? (versionResult.first.values.first as int? ?? 1)
            : 1;

        if (dbSchemaVersion != manifestSchemaVersion) {
          throw BackupFormatException(
              'Inconsistencia: PRAGMA user_version no coincide con el manifest.');
        }

        final rows = await stagingDb.query(
          'transactions',
          columns: ['id', 'imagePath'],
          where: 'imagePath IS NOT NULL',
        );

        if (rows.length != manifestAttachmentsIncluded) {
          throw BackupFormatException(
              'Inconsistencia: El número de attachments referenciados no coincide con el manifest.');
        }

        for (final row in rows) {
          final storedPath = row['imagePath'] as String;

          final stagingAttachmentPath = p.join(stagingDir.path, storedPath);
          if (!await File(stagingAttachmentPath).exists()) {
            throw BackupFormatException(
                'Inconsistencia fatal: El archivo referenciado $storedPath no existe en el contenedor.');
          }
        }
      } finally {
        await stagingDb?.close();
      }

      int attachmentsRestored = 0;
      int attachmentsConflicted = 0; // Se sobrescriben pero los contamos
      final List<String> warnings = [];

      await _attachmentService.executeMaintenance(() async {
        await _restoreService.restoreDatabase(dbFile.path);

        final stagingAttachmentsDir =
            Directory(p.join(stagingDir.path, 'attachments', 'transactions'));
        if (await stagingAttachmentsDir.exists()) {
          final db = await openDatabase(
              p.join(docsDir.path, 'gestor_gastos.db'),
              singleInstance: false);
          try {
            final attachments = await stagingAttachmentsDir.list().toList();
            for (final entity in attachments) {
              if (entity is File) {
                final fileName = p.basename(entity.path);
                final relativePath = 'attachments/transactions/$fileName';
                final destFinalPath = p.join(docsDir.path, relativePath);
                final destTmpPath = p.join(
                    docsDir.path, 'attachments/transactions/$fileName.tmp');

                final destFinalFile = File(destFinalPath);
                if (await destFinalFile.exists()) {
                  attachmentsConflicted++;
                }

                final destTmpFile = File(destTmpPath);
                try {
                  await destTmpFile.parent.create(recursive: true);
                  await entity.copy(destTmpPath);

                  if (await destFinalFile.exists()) {
                    // Platform independent best-effort replace
                    final backupOldPath = p.join(
                        docsDir.path, 'attachments/transactions/$fileName.old');
                    final backupOldFile = File(backupOldPath);
                    try {
                      await destFinalFile.rename(backupOldPath);
                      await destTmpFile.rename(destFinalPath);
                      if (await backupOldFile.exists()) {
                        await backupOldFile.delete();
                      }
                    } catch (e) {
                      if (await backupOldFile.exists()) {
                        await backupOldFile
                            .rename(destFinalPath); // Recover old
                      }
                      rethrow;
                    }
                  } else {
                    await destTmpFile.rename(destFinalPath);
                  }

                  attachmentsRestored++;
                } catch (e) {
                  if (await destTmpFile.exists()) {
                    await destTmpFile.delete();
                  }
                  await db.update(
                    'transactions',
                    {'imagePath': null},
                    where: 'imagePath = ?',
                    whereArgs: [relativePath],
                  );
                  attachmentsMissing++;
                  warnings.add(
                      'No se pudo instalar el adjunto $fileName. Se removió la referencia. Error: $e');
                }
              }
            }
          } finally {
            await db.close();
          }
        }
      });

      bool preferencesRestored = false;
      if (await prefsFile.exists()) {
        try {
          final content = await prefsFile.readAsString();
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          await _preferencesService.restorePreferences(decoded);
          preferencesRestored = true;
        } catch (e) {
          warnings.add('No se pudieron restaurar las preferencias: $e');
        }
      }

      return Right(BackupRestoreResult(
        attachmentsRestored: attachmentsRestored,
        attachmentsMissing: attachmentsMissing,
        attachmentsConflicted: attachmentsConflicted,
        preferencesRestored: preferencesRestored,
        warnings: warnings,
      ));
    } catch (e) {
      if (e is BackupException) {
        return Left(CacheFailure(e.toString()));
      }
      return Left(CacheFailure('Fallo al restaurar el backup: $e'));
    } finally {
      try {
        final zipPlaintext = File(zipPlaintextPath);
        if (await zipPlaintext.exists()) await zipPlaintext.delete();
      } catch (_) {}
      try {
        if (await stagingDir.exists()) await stagingDir.delete(recursive: true);
      } catch (_) {}
    }
  }
}
