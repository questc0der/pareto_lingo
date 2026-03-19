import 'package:pareto_lingo/features/auth/domain/entities/app_user.dart';
import 'package:pareto_lingo/features/auth/domain/repositories/auth_repository.dart';

class WatchAuthState {
  final AuthRepository _repository;

  const WatchAuthState(this._repository);

  Stream<AppUser?> call() {
    return _repository.authStateChanges();
  }
}
