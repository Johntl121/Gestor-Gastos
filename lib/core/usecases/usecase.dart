import 'package:dartz/dartz.dart';
import '../errors/failure.dart';

abstract class UseCase<Output, Params> {
  Future<Either<Failure, Output>> call(Params params);
}

class NoParams {}
