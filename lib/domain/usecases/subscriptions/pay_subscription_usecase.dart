import 'package:dartz/dartz.dart';
import '../../../core/errors/failure.dart';
import '../../../data/models/subscription.dart';
import '../../entities/transaction_entity.dart';
import '../../repositories/subscription_operations_repository.dart';

import '../../../core/constants/app_categories.dart';
import '../../../core/constants/icon_mapper.dart';

class PaySubscriptionParams {
  final Subscription subscription;

  const PaySubscriptionParams({
    required this.subscription,
  });
}

class PaySubscriptionUseCase {
  final SubscriptionOperationsRepository repository;

  PaySubscriptionUseCase(this.repository);

  Future<Either<Failure, void>> call(PaySubscriptionParams params) async {
    final subscription = params.subscription;
    
    final transaction = TransactionEntity(
      accountId: subscription.accountToCharge,
      categoryId: subscription.categoryId,
      amount: -subscription.amount,
      date: DateTime.now(),
      description: subscription.name,
      note: subscription.frequency == ExpenseFrequency.monthly
          ? "Pago mensual"
          : "Pago anual",
      type: TransactionType.expense,
      iconCode: subscription.customIcon != null
          ? IconMapper.getIcon(subscription.customIcon).codePoint
          : AppCategories.getIcon(subscription.categoryId).codePoint,
      colorValue: subscription.customColor ??
          AppCategories.getColor(subscription.categoryId).toARGB32(),
      subscriptionId: subscription.id,
    );

    return await repository.paySubscriptionAtomic(
      subscription: subscription,
      transaction: transaction,
    );
  }
}
