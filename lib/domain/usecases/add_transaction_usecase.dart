import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';
import '../../core/services/attachment_storage_service.dart';
import 'package:path/path.dart' as p;

class AddTransactionUseCase implements UseCase<void, AddTransactionParams> {
  final TransactionRepository repository;
  final AttachmentStorageService attachmentService;

  AddTransactionUseCase(this.repository, this.attachmentService);

  @override
  Future<Either<Failure, void>> call(AddTransactionParams params) async {
    TransactionEntity finalTransaction = params.transaction;
    String? relativePath;

    // 1. Guardar attachment si viene del picker (absoluto y no es nuestro namespace)
    if (finalTransaction.imagePath != null &&
        p.isAbsolute(finalTransaction.imagePath!)) {
      try {
        relativePath = await attachmentService
            .saveTransactionAttachment(finalTransaction.imagePath!);
        finalTransaction = finalTransaction.copyWith(imagePath: relativePath);
      } catch (e) {
        return Left(CacheFailure("Error al guardar la imagen: $e"));
      }
    }

    // 2. Persistir en base de datos
    final result = await repository.addTransaction(finalTransaction,
        updateBalance: params.updateBalance);

    // 3. Fallo al insertar transacción -> cleanup best-effort de la imagen recién copiada
    return result.fold(
      (failure) {
        if (relativePath != null) {
          attachmentService.deleteAttachment(relativePath);
        }
        return Left(failure);
      },
      (success) => const Right(null),
    );
  }
}

class AddTransactionParams extends Equatable {
  final TransactionEntity transaction;
  final bool updateBalance;

  const AddTransactionParams(
      {required this.transaction, this.updateBalance = true});

  @override
  List<Object> get props => [transaction, updateBalance];
}
