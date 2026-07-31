import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/account_repository.dart';

class DeleteAccountParams {
  final int id;
  DeleteAccountParams({required this.id});
}

class DeleteAccountUseCase implements UseCase<void, DeleteAccountParams> {
  final AccountRepository repository;

  DeleteAccountUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteAccountParams params) async {
    return await repository.deleteAccount(params.id);
  }
}
