import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:gestor_gastos/core/errors/failure.dart';
import 'package:gestor_gastos/domain/repositories/account_repository.dart';
import 'package:gestor_gastos/core/services/attachment_storage_service.dart';
import 'package:gestor_gastos/domain/usecases/delete_account_usecase.dart';

class MockAccountRepository extends Mock implements AccountRepository {}
class MockAttachmentStorageService extends Mock implements AttachmentStorageService {}

void main() {
  late DeleteAccountUseCase usecase;
  late MockAccountRepository mockRepository;
  late MockAttachmentStorageService mockAttachmentService;

  setUp(() {
    mockRepository = MockAccountRepository();
    mockAttachmentService = MockAttachmentStorageService();
    usecase = DeleteAccountUseCase(mockRepository, mockAttachmentService);
  });

  group('DeleteAccountUseCase', () {
    test('cuenta con transacciones con adjuntos -> delete DB primero -> luego deleteAttachment', () async {
      final imagePaths = ['attachments/transactions/1.jpg', 'attachments/transactions/2.png'];
      
      when(() => mockRepository.deleteAccount(1))
          .thenAnswer((_) async => Right(imagePaths));
      when(() => mockAttachmentService.deleteAttachment(any()))
          .thenAnswer((_) async {});

      final result = await usecase(DeleteAccountParams(id: 1));

      expect(result, const Right(null));
      verify(() => mockRepository.deleteAccount(1)).called(1);
      verify(() => mockAttachmentService.deleteAttachment('attachments/transactions/1.jpg')).called(1);
      verify(() => mockAttachmentService.deleteAttachment('attachments/transactions/2.png')).called(1);
    });

    test('deleteAccount falla -> ningún attachment se elimina', () async {
      when(() => mockRepository.deleteAccount(1))
          .thenAnswer((_) async => const Left(CacheFailure('DB error')));

      final result = await usecase(DeleteAccountParams(id: 1));

      expect(result, const Left(CacheFailure('DB error')));
      verify(() => mockRepository.deleteAccount(1)).called(1);
      verifyZeroInteractions(mockAttachmentService);
    });

    test('cuenta sin attachments -> delete normal -> storage no se invoca', () async {
      when(() => mockRepository.deleteAccount(1))
          .thenAnswer((_) async => const Right(<String>[]));

      final result = await usecase(DeleteAccountParams(id: 1));

      expect(result, const Right(null));
      verify(() => mockRepository.deleteAccount(1)).called(1);
      verifyZeroInteractions(mockAttachmentService);
    });

    test('paths duplicados -> solo retorna y borra lo que recibe (repository se encarga del distinct)', () async {
      when(() => mockRepository.deleteAccount(1))
          .thenAnswer((_) async => const Right(['attachments/transactions/1.jpg']));
      when(() => mockAttachmentService.deleteAttachment(any()))
          .thenAnswer((_) async {});

      final result = await usecase(DeleteAccountParams(id: 1));

      expect(result, const Right(null));
      verify(() => mockAttachmentService.deleteAttachment('attachments/transactions/1.jpg')).called(1);
    });

    test('attachment inexistente o deleteAttachment falla -> eliminación de cuenta sigue siendo éxito', () async {
      when(() => mockRepository.deleteAccount(1))
          .thenAnswer((_) async => const Right(['attachments/transactions/1.jpg']));
      
      when(() => mockAttachmentService.deleteAttachment('attachments/transactions/1.jpg'))
          .thenAnswer((_) async => throw Exception('I/O error'));

      try {
        final result = await usecase(DeleteAccountParams(id: 1));
        expect(result, const Right(null)); // Sigue siendo success si el usecase no re-lanza
      } catch (e) {
        fail('Exception was not caught: $e');
      }
    });

    test('DeleteAccountUseCase no completa hasta que deleteAttachment haya finalizado', () async {
      final imagePaths = ['attachments/transactions/wait.jpg'];
      bool isFinished = false;

      when(() => mockRepository.deleteAccount(1))
          .thenAnswer((_) async => Right(imagePaths));

      when(() => mockAttachmentService.deleteAttachment(any()))
          .thenAnswer((_) async {
            await Future.delayed(const Duration(milliseconds: 100));
            isFinished = true;
          });

      final usecaseFuture = usecase(DeleteAccountParams(id: 1));
      expect(isFinished, isFalse);

      await usecaseFuture;
      expect(isFinished, isTrue);
    });
  });
}
