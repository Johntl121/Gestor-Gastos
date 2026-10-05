import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../services/backup_creation_service.dart';

class CreateBackupParams {
  final String password;
  CreateBackupParams({required this.password});
}

class CreateBackupUseCase implements UseCase<BackupCreationResult, CreateBackupParams> {
  final BackupCreationService service;

  CreateBackupUseCase(this.service);

  @override
  Future<Either<Failure, BackupCreationResult>> call(CreateBackupParams params) async {
    return await service.generatePortableBackup(params.password);
  }
}
