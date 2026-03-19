import 'package:pareto_lingo/features/auth/domain/repositories/auth_repository.dart';

class RegisterUser {
  final AuthRepository _repository;

  const RegisterUser(this._repository);

  Future<void> call({
    required String email,
    required String password,
    required String learningLanguage,
    required String displayName,
    String? profileImageUrl,
  }) {
    return _repository.register(
      email: email,
      password: password,
      learningLanguage: learningLanguage,
      displayName: displayName,
      profileImageUrl: profileImageUrl,
    );
  }
}
