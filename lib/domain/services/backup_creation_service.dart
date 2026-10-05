import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';

class BackupCreationResult {
  final String backupFilePath;
  final int transactionAttachmentsIncluded;
  final int transactionAttachmentsMissing;
  final int bytesSize;

  BackupCreationResult(
    this.backupFilePath,
    this.transactionAttachmentsIncluded,
    this.transactionAttachmentsMissing,
    this.bytesSize,
  );
}

abstract class BackupCreationService {
  Future<Either<Failure, BackupCreationResult>> generatePortableBackup(String password);
}
