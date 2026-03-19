import 'package:pareto_lingo/features/auth/domain/repositories/auth_repository.dart';

class LoginUser {
  final AuthRepository _repository;

  const LoginUser(this._repository);

  Future<void> call({required String email, required String password}) {
    return _repository.login(email: email, password: password);
  }
}
