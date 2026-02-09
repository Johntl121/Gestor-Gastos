import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/transaction_repository.dart';

class DeleteAccountParams {
  final int id;
  DeleteAccountParams({required this.id});
}

class DeleteAccountUseCase implements UseCase<void, DeleteAccountParams> {
  final TransactionRepository repository;

  DeleteAccountUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteAccountParams params) async {
    return await repository.deleteAccount(params.id);
  }
}
