import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/transaction_repository.dart';
import '../../core/services/attachment_storage_service.dart';

class DeleteTransactionUseCase
    implements UseCase<void, DeleteTransactionParams> {
  final TransactionRepository repository;
  final AttachmentStorageService attachmentService;

  DeleteTransactionUseCase(this.repository, this.attachmentService);

  @override
  Future<Either<Failure, void>> call(DeleteTransactionParams params) async {
    final result = await repository.deleteTransaction(params.id);

    return result.fold(
      (failure) => Left(failure),
      (_) {
        if (params.imagePath != null) {
          attachmentService.deleteAttachment(params.imagePath!);
        }
        return const Right(null);
      },
    );
  }
}

class DeleteTransactionParams extends Equatable {
  final int id;
  final String? imagePath;

  const DeleteTransactionParams({required this.id, this.imagePath});

  @override
  List<Object?> get props => [id, imagePath];
}
