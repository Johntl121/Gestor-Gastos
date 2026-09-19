import 'package:dartz/dartz.dart';
import '../../../core/errors/failure.dart';
import '../../../data/models/subscription.dart';
import '../../repositories/subscription_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../entities/transaction_entity.dart';

class RefreshSubscriptionCyclesParams {
  final DateTime now;
  RefreshSubscriptionCyclesParams({required this.now});
}

class RefreshSubscriptionCyclesUseCase {
  final SubscriptionRepository subscriptionRepository;
  final TransactionRepository transactionRepository;

  RefreshSubscriptionCyclesUseCase({
    required this.subscriptionRepository,
    required this.transactionRepository,
  });

  Future<Either<Failure, List<Subscription>>> call(RefreshSubscriptionCyclesParams params) async {
    try {
      final now = params.now;

      // 1. Obtener todas las transacciones del año en curso para evaluar pagos
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfYear = DateTime(now.year, 12, 31, 23, 59, 59);

      final txResult = await transactionRepository.getTransactionsByDateRange(startOfYear, endOfYear);
      
      return txResult.fold(
        (fail) => Left(fail),
        (transactions) async {
          // Set para suscripciones mensuales pagadas en el mes/año actual
          final Set<String> paidMonthlyNames = {};
          // Set para suscripciones anuales pagadas en el año actual
          final Set<String> paidYearlyNames = {};

          for (var tx in transactions) {
            if (tx.type == TransactionType.expense) {
              if (tx.date.year == now.year) {
                paidYearlyNames.add(tx.description);
                if (tx.date.month == now.month) {
                  paidMonthlyNames.add(tx.description);
                }
              }
            }
          }

          // 2. Obtener todas las suscripciones
          final subsResult = await subscriptionRepository.getSubscriptions();

          return subsResult.fold(
            (fail) => Left(fail),
            (subs) async {
              List<Subscription> finalSubs = [];
              
              for (int i = 0; i < subs.length; i++) {
                final sub = subs[i];
                final bool isPaid = sub.frequency == ExpenseFrequency.monthly
                    ? paidMonthlyNames.contains(sub.name)
                    : paidYearlyNames.contains(sub.name);

                if (sub.isPaid != isPaid) {
                  final updatedSub = sub.copyWith(isPaid: isPaid);
                  final updateResult = await subscriptionRepository.saveSubscription(updatedSub);
                  
                  bool success = updateResult.fold((l) => false, (r) => true);
                  if (success) {
                    finalSubs.add(updatedSub);
                  } else {
                    finalSubs.add(sub);
                  }
                } else {
                  finalSubs.add(sub);
                }
              }

              return Right(finalSubs);
            }
          );
        }
      );

    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
