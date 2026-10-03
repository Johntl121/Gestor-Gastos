import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:gestor_gastos/core/errors/failure.dart';
import 'package:gestor_gastos/domain/entities/transaction_entity.dart';
import 'package:gestor_gastos/domain/repositories/transaction_repository.dart';
import 'package:gestor_gastos/core/services/attachment_storage_service.dart';
import 'package:gestor_gastos/domain/usecases/update_transaction_usecase.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockAttachmentStorageService extends Mock implements AttachmentStorageService {}

void main() {
  late UpdateTransactionUseCase usecase;
  late MockTransactionRepository mockRepository;
  late MockAttachmentStorageService mockAttachmentService;

  setUpAll(() {
    final now = DateTime.now();
    registerFallbackValue(TransactionEntity(
      id: 1,
      accountId: 1,
      categoryId: 1,
      amount: 100,
      date: now,
      description: 'test',
    ));
  });

  setUp(() {
    mockRepository = MockTransactionRepository();
    mockAttachmentService = MockAttachmentStorageService();
    usecase = UpdateTransactionUseCase(mockRepository, mockAttachmentService);
  });

  final tDate = DateTime(2023);
  final tOldTx = TransactionEntity(
    id: 1,
    accountId: 1,
    categoryId: 1,
    amount: 100,
    date: tDate,
    description: 'test',
    imagePath: 'attachments/transactions/old.jpg',
  );

  group('UpdateTransactionUseCase', () {
    test('update sin cambiar imagen -> no save, no delete, oldImagePath preservado', () async {
      when(() => mockRepository.updateTransaction(any())).thenAnswer((_) async => const Right(null));

      final result = await usecase(UpdateTransactionParams(
        transaction: tOldTx,
        imageChanged: false,
        oldImagePath: 'attachments/transactions/old.jpg',
      ));

      expect(result, const Right(null));
      verify(() => mockRepository.updateTransaction(tOldTx)).called(1);
      verifyZeroInteractions(mockAttachmentService);
    });

    test('reemplazo exitoso -> nueva relativePath a repo, vieja se elimina después', () async {
      when(() => mockAttachmentService.saveTransactionAttachment('new_source.jpg'))
          .thenAnswer((_) async => 'attachments/transactions/new.jpg');
      when(() => mockRepository.updateTransaction(any())).thenAnswer((_) async => const Right(null));
      when(() => mockAttachmentService.deleteAttachment('attachments/transactions/old.jpg'))
          .thenAnswer((_) async {});

      final result = await usecase(UpdateTransactionParams(
        transaction: tOldTx,
        imageChanged: true,
        newImageSourcePath: 'new_source.jpg',
        oldImagePath: 'attachments/transactions/old.jpg',
      ));

      expect(result, const Right(null));
      final captured = verify(() => mockRepository.updateTransaction(captureAny())).captured;
      expect((captured.first as TransactionEntity).imagePath, 'attachments/transactions/new.jpg');
      verify(() => mockAttachmentService.deleteAttachment('attachments/transactions/old.jpg')).called(1);
    });

    test('reemplazo + update DB falla -> nueva imagen se limpia, vieja NO se elimina', () async {
      when(() => mockAttachmentService.saveTransactionAttachment('new_source.jpg'))
          .thenAnswer((_) async => 'attachments/transactions/new.jpg');
      when(() => mockRepository.updateTransaction(any())).thenAnswer((_) async => const Left(CacheFailure('DB error')));
      when(() => mockAttachmentService.deleteAttachment('attachments/transactions/new.jpg'))
          .thenAnswer((_) async {});

      final result = await usecase(UpdateTransactionParams(
        transaction: tOldTx,
        imageChanged: true,
        newImageSourcePath: 'new_source.jpg',
        oldImagePath: 'attachments/transactions/old.jpg',
      ));

      expect(result, const Left(CacheFailure('DB error')));
      verify(() => mockAttachmentService.deleteAttachment('attachments/transactions/new.jpg')).called(1);
      verifyNever(() => mockAttachmentService.deleteAttachment('attachments/transactions/old.jpg'));
    });

    test('eliminar imagen exitosamente -> DB recibe imagePath null, vieja se elimina', () async {
      when(() => mockRepository.updateTransaction(any())).thenAnswer((_) async => const Right(null));
      when(() => mockAttachmentService.deleteAttachment('attachments/transactions/old.jpg'))
          .thenAnswer((_) async {});

      final result = await usecase(UpdateTransactionParams(
        transaction: tOldTx,
        imageChanged: true,
        newImageSourcePath: null, // indica remoción
        oldImagePath: 'attachments/transactions/old.jpg',
      ));

      expect(result, const Right(null));
      final captured = verify(() => mockRepository.updateTransaction(captureAny())).captured;
      expect((captured.first as TransactionEntity).imagePath, isNull);
      verify(() => mockAttachmentService.deleteAttachment('attachments/transactions/old.jpg')).called(1);
    });

    test('eliminar imagen + update falla -> vieja NO se elimina', () async {
      when(() => mockRepository.updateTransaction(any())).thenAnswer((_) async => const Left(CacheFailure('DB error')));

      final result = await usecase(UpdateTransactionParams(
        transaction: tOldTx,
        imageChanged: true,
        newImageSourcePath: null,
        oldImagePath: 'attachments/transactions/old.jpg',
      ));

      expect(result, const Left(CacheFailure('DB error')));
      verifyNever(() => mockAttachmentService.deleteAttachment(any()));
    });
  });
}
