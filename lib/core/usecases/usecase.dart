import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

/// Base class for all use cases
/// [Type] is the return type
/// [Params] is the parameter type
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Used when a use case doesn't need any parameters
class NoParams {
  const NoParams();
}
