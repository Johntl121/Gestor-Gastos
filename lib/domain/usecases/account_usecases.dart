import 'package:dartz/dartz.dart';
import '../../core/errors/failure.dart';
import '../../core/usecases/usecase.dart';
import '../entities/account_entity.dart';
import '../repositories/transaction_repository.dart';

class GetAccountsUseCase implements UseCase<List<AccountEntity>, NoParams> {
  final TransactionRepository repository;

  GetAccountsUseCase(this.repository);

  @override
  Future<Either<Failure, List<AccountEntity>>> call(NoParams params) async {
    return await repository.getAccounts();
  }
}

class CreateAccountParams {
  final AccountEntity account;
  CreateAccountParams({required this.account});
}

class CreateAccountUseCase implements UseCase<void, CreateAccountParams> {
  final TransactionRepository repository;

  CreateAccountUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(CreateAccountParams params) async {
    return await repository.createAccount(params.account);
  }
}
