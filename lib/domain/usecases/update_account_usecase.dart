import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/account_repository.dart';
import '../entities/account_entity.dart';

class UpdateAccountParams {
  final AccountEntity account;
  UpdateAccountParams({required this.account});
}

class UpdateAccountUseCase implements UseCase<void, UpdateAccountParams> {
  final AccountRepository repository;

  UpdateAccountUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateAccountParams params) async {
    return await repository.updateAccount(params.account);
  }
}
