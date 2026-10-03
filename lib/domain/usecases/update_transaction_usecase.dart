import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';
import '../../core/services/attachment_storage_service.dart';

class UpdateTransactionUseCase
    implements UseCase<void, UpdateTransactionParams> {
  final TransactionRepository repository;
  final AttachmentStorageService attachmentService;

  UpdateTransactionUseCase(this.repository, this.attachmentService);

  @override
  Future<Either<Failure, void>> call(UpdateTransactionParams params) async {
    TransactionEntity finalTransaction = params.transaction;
    String? newRelativePath;

    // 1. Guardar nueva imagen si fue reemplazada
    if (params.imageChanged && params.newImageSourcePath != null) {
      try {
        newRelativePath = await attachmentService
            .saveTransactionAttachment(params.newImageSourcePath!);
        finalTransaction = TransactionEntity(
          id: finalTransaction.id, accountId: finalTransaction.accountId, categoryId: finalTransaction.categoryId,
          amount: finalTransaction.amount, date: finalTransaction.date, description: finalTransaction.description,
          categoryName: finalTransaction.categoryName, accountName: finalTransaction.accountName, note: finalTransaction.note,
          type: finalTransaction.type, destinationAccountId: finalTransaction.destinationAccountId, receivedAmount: finalTransaction.receivedAmount,
          imagePath: newRelativePath, iconCode: finalTransaction.iconCode, colorValue: finalTransaction.colorValue,
          categoryIcon: finalTransaction.categoryIcon, categoryColor: finalTransaction.categoryColor, subscriptionId: finalTransaction.subscriptionId,
        );
      } catch (e) {
        return Left(CacheFailure("Error al guardar la nueva imagen: $e"));
      }
    } else if (params.imageChanged && params.newImageSourcePath == null) {
      // Imagen fue eliminada explícitamente
      finalTransaction = TransactionEntity(
        id: finalTransaction.id, accountId: finalTransaction.accountId, categoryId: finalTransaction.categoryId,
        amount: finalTransaction.amount, date: finalTransaction.date, description: finalTransaction.description,
        categoryName: finalTransaction.categoryName, accountName: finalTransaction.accountName, note: finalTransaction.note,
        type: finalTransaction.type, destinationAccountId: finalTransaction.destinationAccountId, receivedAmount: finalTransaction.receivedAmount,
        imagePath: null, iconCode: finalTransaction.iconCode, colorValue: finalTransaction.colorValue,
        categoryIcon: finalTransaction.categoryIcon, categoryColor: finalTransaction.categoryColor, subscriptionId: finalTransaction.subscriptionId,
      );
    } else {
      // Imagen no cambió
      finalTransaction = TransactionEntity(
        id: finalTransaction.id, accountId: finalTransaction.accountId, categoryId: finalTransaction.categoryId,
        amount: finalTransaction.amount, date: finalTransaction.date, description: finalTransaction.description,
        categoryName: finalTransaction.categoryName, accountName: finalTransaction.accountName, note: finalTransaction.note,
        type: finalTransaction.type, destinationAccountId: finalTransaction.destinationAccountId, receivedAmount: finalTransaction.receivedAmount,
        imagePath: params.oldImagePath, iconCode: finalTransaction.iconCode, colorValue: finalTransaction.colorValue,
        categoryIcon: finalTransaction.categoryIcon, categoryColor: finalTransaction.categoryColor, subscriptionId: finalTransaction.subscriptionId,
      );
    }

    // 2. Persistir update en la base de datos
    final result = await repository.updateTransaction(finalTransaction);

    return result.fold(
      (failure) {
        // Falló el update contable -> borrar el nuevo archivo creado (si hubo), preservar el viejo
        if (newRelativePath != null) {
          attachmentService.deleteAttachment(newRelativePath);
        }
        return Left(failure);
      },
      (_) {
        // Éxito en update contable -> borrar el archivo viejo (si se cambió/eliminó y existía uno)
        if (params.imageChanged && params.oldImagePath != null) {
          attachmentService.deleteAttachment(params.oldImagePath!);
        }
        return const Right(null);
      },
    );
  }
}

class UpdateTransactionParams extends Equatable {
  final TransactionEntity transaction;
  final bool imageChanged;
  final String? newImageSourcePath;
  final String? oldImagePath;

  const UpdateTransactionParams({
    required this.transaction,
    this.imageChanged = false,
    this.newImageSourcePath,
    this.oldImagePath,
  });

  @override
  List<Object?> get props => [
        transaction,
        imageChanged,
        newImageSourcePath,
        oldImagePath,
      ];
}
