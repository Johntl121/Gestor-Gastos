import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../entities/backup_restore_result.dart';
import '../services/backup_restore_service.dart';

class RestoreBackupUseCase {
  final BackupRestoreService service;

  RestoreBackupUseCase(this.service);

  Future<Either<Failure, BackupRestoreResult>> call(
      String backupPath, String password) {
    return service.restorePortableBackup(backupPath, password);
  }
}
