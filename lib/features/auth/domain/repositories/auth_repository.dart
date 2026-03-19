import 'package:pareto_lingo/features/auth/domain/entities/app_user.dart';
import 'package:pareto_lingo/features/auth/domain/entities/user_profile.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();

  Future<void> login({required String email, required String password});

  Future<void> register({
    required String email,
    required String password,
    required String learningLanguage,
    required String displayName,
    String? profileImageUrl,
  });

  Future<UserProfile> getCurrentUserProfile();

  Future<String?> getLearningLanguage();

  Future<void> setLearningLanguage(String languageCode);

  Future<void> logout();
}
