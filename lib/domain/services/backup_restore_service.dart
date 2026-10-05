import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../entities/backup_restore_result.dart';

abstract class BackupRestoreService {
  Future<Either<Failure, BackupRestoreResult>> restorePortableBackup(
    String backupPath,
    String password,
  );
}
