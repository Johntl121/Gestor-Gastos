import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../entities/transaction_entity.dart';
import '../repositories/goal_operations_repository.dart';
import '../../data/datasources/goal_local_data_source.dart';
import '../repositories/account_repository.dart';
import '../../data/datasources/preferences_local_data_source.dart';
import '../../core/services/currency_converter.dart';
import '../../core/constants/app_constants.dart';

class DepositToGoalUseCase implements UseCase<void, DepositToGoalParams> {
  final GoalOperationsRepository repository;
  final GoalLocalDataSource goalLocalDataSource;
  final AccountRepository accountRepository;
  final PreferencesLocalDataSource preferencesLocalDataSource;

  DepositToGoalUseCase({
    required this.repository,
    required this.goalLocalDataSource,
    required this.accountRepository,
    required this.preferencesLocalDataSource,
  });

  @override
  Future<Either<Failure, void>> call(DepositToGoalParams params) async {
    final goals = await goalLocalDataSource.getGoals();
    final index = goals.indexWhere((g) => g.id == params.goalId);
    if (index == -1) return const Left(CacheFailure('Meta no encontrada'));
    final goal = goals[index];

    if (goal.accountId == null) {
      return const Left(ValidationFailure('No se puede depositar: La meta no tiene una cuenta configurada.'));
    }

    final accountsResult = await accountRepository.getAccounts();
    return await accountsResult.fold(
      (failure) async => Left(failure),
      (accounts) async {
        try {
          final sourceAccount = accounts.firstWhere((a) => a.id == params.sourceAccountId);
          final goalAccount = accounts.firstWhere((a) => a.id == goal.accountId);

          double? receivedAmount;
          if (sourceAccount.currencySymbol != goalAccount.currencySymbol) {
            final rates = preferencesLocalDataSource.getExchangeRates();
            final converter = CurrencyConverter(rates: rates);
            receivedAmount = converter.convert(
                params.amount, sourceAccount.currencySymbol, goalAccount.currencySymbol);
          }

          final transaction = TransactionEntity(
            accountId: params.sourceAccountId,
            categoryId: AppConstants.transferCategoryId,
            amount: params.amount,
            date: DateTime.now(),
            description: "Transferencia Meta: ${goal.name}",
            note: "Ahorro depositado a meta",
            type: TransactionType.transfer,
            destinationAccountId: goal.accountId,
            receivedAmount: receivedAmount,
          );

          return await repository.depositToGoalAtomic(params.goalId, transaction);
        } catch (e) {
          return Left(ValidationFailure('Cuenta no encontrada: $e'));
        }
      },
    );
  }
}

class DepositToGoalParams {
  final String goalId;
  final double amount;
  final int sourceAccountId;

  DepositToGoalParams({
    required this.goalId,
    required this.amount,
    required this.sourceAccountId,
  });
}

class PurchaseGoalUseCase implements UseCase<void, PurchaseGoalParams> {
  final GoalOperationsRepository repository;
  final GoalLocalDataSource goalLocalDataSource;

  PurchaseGoalUseCase({
    required this.repository,
    required this.goalLocalDataSource,
  });

  @override
  Future<Either<Failure, void>> call(PurchaseGoalParams params) async {
    final goals = await goalLocalDataSource.getGoals();
    final index = goals.indexWhere((g) => g.id == params.goalId);
    if (index == -1) return const Left(CacheFailure('Meta no encontrada'));
    final goal = goals[index];

    if (goal.accountId == null) {
      return const Left(ValidationFailure('No se puede comprar la meta: No tiene una cuenta configurada.'));
    }

    final purchaseAccountId = goal.accountId!;
    final finalCategoryId = params.categoryId ?? goal.categoryId ?? AppConstants.shoppingCategoryId;

    final transaction = TransactionEntity(
      accountId: purchaseAccountId,
      categoryId: finalCategoryId,
      amount: -goal.currentAmount.abs(),
      date: DateTime.now(),
      description: "Meta Cumplida: ${goal.name}",
      note: "Compra realizada con éxito 🏆",
      type: TransactionType.expense,
    );

    return await repository.purchaseGoalAtomic(params.goalId, transaction);
  }
}

class PurchaseGoalParams {
  final String goalId;
  final int? categoryId;

  PurchaseGoalParams({required this.goalId, this.categoryId});
}

class DeleteGoalAtomicUseCase implements UseCase<void, DeleteGoalAtomicParams> {
  final GoalOperationsRepository repository;
  final GoalLocalDataSource goalLocalDataSource;
  final AccountRepository accountRepository;
  final PreferencesLocalDataSource preferencesLocalDataSource;

  DeleteGoalAtomicUseCase({
    required this.repository,
    required this.goalLocalDataSource,
    required this.accountRepository,
    required this.preferencesLocalDataSource,
  });

  @override
  Future<Either<Failure, void>> call(DeleteGoalAtomicParams params) async {
    final goals = await goalLocalDataSource.getGoals();
    final index = goals.indexWhere((g) => g.id == params.goalId);
    if (index == -1) return const Left(CacheFailure('Meta no encontrada'));
    final goal = goals[index];

    TransactionEntity? refundTx;

    if (params.refund && params.refundAccountId != null && goal.currentAmount > 0) {
      if (goal.accountId == null) {
        return const Left(ValidationFailure('No se puede reembolsar: La meta no tiene una cuenta asociada.'));
      }

      final accountsResult = await accountRepository.getAccounts();
      final Either<Failure, void> accountsEither = await accountsResult.fold(
        (failure) async => Left(failure),
        (accounts) async {
          try {
            final refundAccount = accounts.firstWhere((a) => a.id == params.refundAccountId);
            final goalAccount = accounts.firstWhere((a) => a.id == goal.accountId);

            double? receivedAmount;
            if (goalAccount.currencySymbol != refundAccount.currencySymbol) {
              final rates = preferencesLocalDataSource.getExchangeRates();
              final converter = CurrencyConverter(rates: rates);
              receivedAmount = converter.convert(
                  goal.currentAmount, goalAccount.currencySymbol, refundAccount.currencySymbol);
            }

            refundTx = TransactionEntity(
              accountId: goal.accountId!,
              categoryId: AppConstants.transferCategoryId,
              amount: goal.currentAmount,
              date: DateTime.now(),
              description: "Reembolso Meta: ${goal.name}",
              note: "Dinero devuelto al eliminar meta",
              type: TransactionType.transfer,
              destinationAccountId: params.refundAccountId,
              receivedAmount: receivedAmount,
            );
            return const Right(null);
          } catch (e) {
            return Left(ValidationFailure('Cuenta no encontrada: $e'));
          }
        },
      );

      return accountsEither.fold(
        (failure) async => Left(failure),
        (_) async => await repository.deleteGoalAtomic(params.goalId, refundTransaction: refundTx),
      );
    }

    return await repository.deleteGoalAtomic(params.goalId, refundTransaction: refundTx);
  }
}

class DeleteGoalAtomicParams {
  final String goalId;
  final bool refund;
  final int? refundAccountId;

  DeleteGoalAtomicParams({
    required this.goalId,
    this.refund = false,
    this.refundAccountId,
  });
}
