import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/errors/failure.dart';
import '../../core/services/database_helper.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/subscription_operations_repository.dart';
import '../helpers/account_transaction_helper.dart';
import '../models/subscription.dart';
import '../models/transaction_model.dart';

class SubscriptionOperationsRepositoryImpl
    implements SubscriptionOperationsRepository {
  final LocalDatabase localDatabase;

  SubscriptionOperationsRepositoryImpl({required this.localDatabase});

  @override
  Future<Either<Failure, void>> paySubscriptionAtomic({
    required Subscription subscription,
    required TransactionEntity transaction,
  }) async {
    try {
      final db = await localDatabase.database;

      await db.transaction((txn) async {
        // 1. Guardar la transacción en SQLite
        final transactionModel = TransactionModel.fromEntity(transaction);
        await txn.insert('transactions', transactionModel.toJson());

        // 2. Actualizar Saldo de Cuenta en SQL
        await AccountTransactionHelper.applyTransaction(txn, transaction);

        // 3. Actualizar la suscripción a estado pagado
        final updatedSub = subscription.copyWith(isPaid: true);
        await txn.insert('fixed_expenses', updatedSub.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      });

      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure(e.toString()));
    }
  }
}
