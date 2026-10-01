import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';

import 'package:gestor_gastos/domain/entities/transaction_entity.dart';
import 'package:gestor_gastos/data/models/subscription.dart';
import 'package:gestor_gastos/domain/repositories/subscription_repository.dart';
import 'package:gestor_gastos/domain/repositories/transaction_repository.dart';
import 'package:gestor_gastos/domain/usecases/subscriptions/refresh_subscription_cycles_usecase.dart';
import 'package:gestor_gastos/core/errors/failure.dart';

class FakeSubscriptionRepository implements SubscriptionRepository {
  List<Subscription> subsToReturn = [];
  bool saveCalled = false;

  @override
  Future<Either<Failure, List<Subscription>>> getSubscriptions() async {
    return Right(subsToReturn);
  }

  @override
  Future<Either<Failure, void>> saveSubscription(Subscription subscription) async {
    saveCalled = true;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteSubscription(String id) async => const Right(null);
}

class FakeTransactionRepository implements TransactionRepository {
  List<TransactionEntity> txsToReturn = [];

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    return Right(txsToReturn);
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactions({int limit = 50, int offset = 0}) async => const Right([]);
  @override
  Future<Either<Failure, void>> addTransaction(TransactionEntity tx, {bool updateBalance = true}) async => const Right(null);
  @override
  Future<Either<Failure, void>> updateTransaction(TransactionEntity tx) async => const Right(null);
  @override
  Future<Either<Failure, void>> deleteTransaction(int id) async => const Right(null);
  @override
  Future<Either<Failure, double>> getCurrentMonthExpenses() async => const Right(0.0);
}

void main() {
  late FakeSubscriptionRepository mockSubscriptionRepo;
  late FakeTransactionRepository mockTransactionRepo;
  late RefreshSubscriptionCyclesUseCase usecase;

  setUp(() {
    mockSubscriptionRepo = FakeSubscriptionRepository();
    mockTransactionRepo = FakeTransactionRepository();
    usecase = RefreshSubscriptionCyclesUseCase(
      subscriptionRepository: mockSubscriptionRepo,
      transactionRepository: mockTransactionRepo,
    );
  });

  final now = DateTime(2026, 10, 15);
  final sub1 = Subscription(
    id: 'sub_1',
    name: 'Netflix',
    amount: 15.0,
    paymentDate: DateTime(2026, 1, 15),
    frequency: ExpenseFrequency.monthly,
    isPaid: false,
    categoryId: 1,
  );

  group('FASE 11: Relación explícita Subscription ↔ Transaction', () {
    test('transacción vinculada sí marca la suscripción como pagada', () async {
      mockTransactionRepo.txsToReturn = [
        TransactionEntity(
          id: 1,
          accountId: 1,
          categoryId: 1,
          amount: -15.0,
          date: now,
          description: 'Netflix',
          subscriptionId: 'sub_1', // Explicit link
          type: TransactionType.expense,
        )
      ];
      mockSubscriptionRepo.subsToReturn = [sub1];

      final result = await usecase(RefreshSubscriptionCyclesParams(now: now));

      expect(result.isRight(), true);
      final subs = result.getOrElse(() => []);
      expect(subs.first.isPaid, true);
      expect(mockSubscriptionRepo.saveCalled, true);
    });

    test('transacción manual con description == subscription.name NO marca la suscripción como pagada', () async {
      mockTransactionRepo.txsToReturn = [
        TransactionEntity(
          id: 1,
          accountId: 1,
          categoryId: 1,
          amount: -15.0,
          date: now,
          description: 'Netflix',
          subscriptionId: null, // No explicit link!
          type: TransactionType.expense,
        )
      ];
      mockSubscriptionRepo.subsToReturn = [sub1];

      final result = await usecase(RefreshSubscriptionCyclesParams(now: now));

      expect(result.isRight(), true);
      final subs = result.getOrElse(() => []);
      expect(subs.first.isPaid, false);
      expect(mockSubscriptionRepo.saveCalled, false);
    });

    test('renombrar subscription no rompe detección', () async {
      final renamedSub = sub1.copyWith(name: 'Netflix Premium (Renamed)');

      mockTransactionRepo.txsToReturn = [
        TransactionEntity(
          id: 1,
          accountId: 1,
          categoryId: 1,
          amount: -15.0,
          date: now,
          description: 'Netflix', // Old description in transaction
          subscriptionId: 'sub_1', // But linked explicitly by ID
          type: TransactionType.expense,
        )
      ];
      mockSubscriptionRepo.subsToReturn = [renamedSub];

      final result = await usecase(RefreshSubscriptionCyclesParams(now: now));

      expect(result.isRight(), true);
      final subs = result.getOrElse(() => []);
      expect(subs.first.isPaid, true);
      expect(mockSubscriptionRepo.saveCalled, true);
    });

    test('transacciones antiguas con subscriptionId null siguen funcionando', () async {
      final oldPaidSub = sub1.copyWith(isPaid: true);

      mockTransactionRepo.txsToReturn = [
        TransactionEntity(
          id: 1,
          accountId: 1,
          categoryId: 1,
          amount: -15.0,
          date: now,
          description: 'Netflix',
          subscriptionId: null,
          type: TransactionType.expense,
        )
      ];
      mockSubscriptionRepo.subsToReturn = [oldPaidSub];

      final result = await usecase(RefreshSubscriptionCyclesParams(now: now));

      expect(result.isRight(), true);
      final subs = result.getOrElse(() => []);
      expect(subs.first.isPaid, false); 
      expect(mockSubscriptionRepo.saveCalled, true); // It saves to update isPaid from true to false
    });
  });
}
