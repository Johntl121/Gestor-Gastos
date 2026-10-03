import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/account_repository.dart';
import '../../core/services/attachment_storage_service.dart';

class DeleteAccountParams {
  final int id;
  DeleteAccountParams({required this.id});
}

class DeleteAccountUseCase implements UseCase<void, DeleteAccountParams> {
  final AccountRepository repository;
  final AttachmentStorageService attachmentService;

  DeleteAccountUseCase(this.repository, this.attachmentService);

  @override
  Future<Either<Failure, void>> call(DeleteAccountParams params) async {
    final result = await repository.deleteAccount(params.id);
    return await result.fold(
      (failure) async => Left(failure),
      (imagePaths) async {
        // Borrar best-effort si la DB tuvo éxito de forma secuencial y bloqueante
        for (final path in imagePaths) {
          try {
            await attachmentService.deleteAttachment(path);
          } catch (_) {
            // Ignorar fallos de filesystem.
            // La operación financiera ya fue exitosa.
          }
        }
        return const Right(null);
      },
    );
  }
}
