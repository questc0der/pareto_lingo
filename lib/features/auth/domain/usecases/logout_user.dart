import 'package:pareto_lingo/features/auth/domain/repositories/auth_repository.dart';

class LogoutUser {
  final AuthRepository _repository;

  const LogoutUser(this._repository);

  Future<void> call() {
    return _repository.logout();
  }
}
