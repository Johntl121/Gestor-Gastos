import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class GetTransactionsByDateRangeUseCase
    implements UseCase<List<TransactionEntity>, DateRangeParams> {
  final TransactionRepository repository;

  GetTransactionsByDateRangeUseCase(this.repository);

  @override
  Future<Either<Failure, List<TransactionEntity>>> call(DateRangeParams params) async {
    return await repository.getTransactionsByDateRange(params.start, params.end);
  }
}

class DateRangeParams {
  final DateTime start;
  final DateTime end;

  DateRangeParams({required this.start, required this.end});
}
