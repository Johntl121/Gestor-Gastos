import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:gestor_gastos/core/errors/failure.dart';
import 'package:gestor_gastos/domain/repositories/transaction_repository.dart';
import 'package:gestor_gastos/core/services/attachment_storage_service.dart';
import 'package:gestor_gastos/domain/usecases/delete_transaction_usecase.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockAttachmentStorageService extends Mock implements AttachmentStorageService {}

void main() {
  late DeleteTransactionUseCase usecase;
  late MockTransactionRepository mockRepository;
  late MockAttachmentStorageService mockAttachmentService;

  setUp(() {
    mockRepository = MockTransactionRepository();
    mockAttachmentService = MockAttachmentStorageService();
    usecase = DeleteTransactionUseCase(mockRepository, mockAttachmentService);
  });

  group('DeleteTransactionUseCase', () {
    test('delete transaction exitoso -> attachment se elimina después', () async {
      when(() => mockRepository.deleteTransaction(1)).thenAnswer((_) async => const Right(null));
      when(() => mockAttachmentService.deleteAttachment('old.jpg')).thenAnswer((_) async {});

      final result = await usecase(const DeleteTransactionParams(id: 1, imagePath: 'old.jpg'));

      expect(result, const Right(null));
      verify(() => mockRepository.deleteTransaction(1)).called(1);
      verify(() => mockAttachmentService.deleteAttachment('old.jpg')).called(1);
    });

    test('delete transaction falla -> attachment NO se elimina', () async {
      when(() => mockRepository.deleteTransaction(1)).thenAnswer((_) async => const Left(CacheFailure('DB error')));

      final result = await usecase(const DeleteTransactionParams(id: 1, imagePath: 'old.jpg'));

      expect(result, const Left(CacheFailure('DB error')));
      verify(() => mockRepository.deleteTransaction(1)).called(1);
      verifyZeroInteractions(mockAttachmentService);
    });

    test('attachment inexistente (null imagePath) -> delete financiero sigue siendo éxito', () async {
      when(() => mockRepository.deleteTransaction(1)).thenAnswer((_) async => const Right(null));

      final result = await usecase(const DeleteTransactionParams(id: 1, imagePath: null));

      expect(result, const Right(null));
      verify(() => mockRepository.deleteTransaction(1)).called(1);
      verifyZeroInteractions(mockAttachmentService);
    });
  });
}
