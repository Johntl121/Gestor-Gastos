import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:gestor_gastos/core/errors/failure.dart';
import 'package:gestor_gastos/domain/entities/transaction_entity.dart';
import 'package:gestor_gastos/domain/repositories/transaction_repository.dart';
import 'package:gestor_gastos/core/services/attachment_storage_service.dart';
import 'package:gestor_gastos/domain/usecases/add_transaction_usecase.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockAttachmentStorageService extends Mock implements AttachmentStorageService {}
class FakeTransactionEntity extends Fake implements TransactionEntity {}

void main() {
  late AddTransactionUseCase usecase;
  late MockTransactionRepository mockRepository;
  late MockAttachmentStorageService mockAttachmentService;

  setUpAll(() {
    final now = DateTime.now();
    registerFallbackValue(TransactionEntity(
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
    usecase = AddTransactionUseCase(mockRepository, mockAttachmentService);
  });

  final tTransactionWithoutImage = TransactionEntity(
    accountId: 1,
    categoryId: 1,
    amount: 100,
    date: DateTime(2023),
    description: 'test no image',
    type: TransactionType.expense,
  );

  final tTransactionWithImage = TransactionEntity(
    accountId: 1,
    categoryId: 1,
    amount: 100,
    date: DateTime(2023),
    description: 'test with image',
    type: TransactionType.expense,
    imagePath: '/absolute/path/to/picked_image.jpg',
  );

  group('AddTransactionUseCase', () {
    test('nueva transacción sin imagen -> imagePath null / comportamiento actual', () async {
      when(() => mockRepository.addTransaction(any(), updateBalance: any(named: 'updateBalance')))
          .thenAnswer((_) async => const Right(null));

      final result = await usecase(AddTransactionParams(transaction: tTransactionWithoutImage));

      expect(result, const Right(null));
      verify(() => mockRepository.addTransaction(tTransactionWithoutImage, updateBalance: true)).called(1);
      verifyZeroInteractions(mockAttachmentService);
    });

    test('nueva transacción con imagen -> DB recibe relativePath', () async {
      const relativePath = 'attachments/transactions/1234.jpg';
      when(() => mockAttachmentService.saveTransactionAttachment(any()))
          .thenAnswer((_) async => relativePath);
      
      when(() => mockRepository.addTransaction(any(), updateBalance: any(named: 'updateBalance')))
          .thenAnswer((_) async => const Right(null));

      final result = await usecase(AddTransactionParams(transaction: tTransactionWithImage));

      expect(result, const Right(null));
      
      verify(() => mockAttachmentService.saveTransactionAttachment('/absolute/path/to/picked_image.jpg')).called(1);
      
      final captured = verify(() => mockRepository.addTransaction(captureAny(), updateBalance: true)).captured;
      final insertedTx = captured.first as TransactionEntity;
      expect(insertedTx.imagePath, relativePath);
    });

    test('fallo de insert después de guardar archivo -> cleanup best-effort del nuevo attachment', () async {
      const relativePath = 'attachments/transactions/1234.jpg';
      when(() => mockAttachmentService.saveTransactionAttachment(any()))
          .thenAnswer((_) async => relativePath);
      
      when(() => mockRepository.addTransaction(any(), updateBalance: any(named: 'updateBalance')))
          .thenAnswer((_) async => const Left(CacheFailure("DB Insert Error")));
      
      when(() => mockAttachmentService.deleteAttachment(any())).thenAnswer((_) async {});

      final result = await usecase(AddTransactionParams(transaction: tTransactionWithImage));

      expect(result, const Left(CacheFailure("DB Insert Error")));
      
      verify(() => mockAttachmentService.saveTransactionAttachment('/absolute/path/to/picked_image.jpg')).called(1);
      verify(() => mockAttachmentService.deleteAttachment(relativePath)).called(1);
    });
  });
}
