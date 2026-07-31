import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class GetTransactionsUseCase
    implements UseCase<List<TransactionEntity>, GetTransactionsParams> {
  final TransactionRepository repository;

  GetTransactionsUseCase(this.repository);

  @override
  Future<Either<Failure, List<TransactionEntity>>> call(
      GetTransactionsParams params) async {
    return await repository.getTransactions(
      limit: params.limit,
      offset: params.offset,
    );
  }
}

class GetTransactionsParams extends Equatable {
  final int limit;
  final int offset;

  const GetTransactionsParams({this.limit = 50, this.offset = 0});

  @override
  List<Object?> get props => [limit, offset];
}
