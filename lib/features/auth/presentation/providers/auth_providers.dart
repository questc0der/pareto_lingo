import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/learning/presentation/providers/learning_bootstrap_providers.dart';
import 'package:pareto_lingo/features/learning/domain/usecases/get_learning_bootstrap_content.dart';
import 'package:pareto_lingo/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:pareto_lingo/features/auth/domain/entities/app_user.dart';
import 'package:pareto_lingo/features/auth/domain/entities/user_profile.dart';
import 'package:pareto_lingo/features/auth/domain/repositories/auth_repository.dart';
import 'package:pareto_lingo/features/auth/domain/usecases/login_user.dart';
import 'package:pareto_lingo/features/auth/domain/usecases/logout_user.dart';
import 'package:pareto_lingo/features/auth/domain/usecases/register_user.dart';
import 'package:pareto_lingo/features/auth/domain/usecases/watch_auth_state.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(
    ref.read(firebaseAuthProvider),
    ref.read(firebaseFirestoreProvider),
  );
});

final loginUserProvider = Provider<LoginUser>((ref) {
  return LoginUser(ref.read(authRepositoryProvider));
});

final registerUserProvider = Provider<RegisterUser>((ref) {
  return RegisterUser(ref.read(authRepositoryProvider));
});

final logoutUserProvider = Provider<LogoutUser>((ref) {
  return LogoutUser(ref.read(authRepositoryProvider));
});

final watchAuthStateProvider = Provider<WatchAuthState>((ref) {
  return WatchAuthState(ref.read(authRepositoryProvider));
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.read(watchAuthStateProvider)();
});

final selectedLearningLanguageProvider = StateProvider<String>((ref) {
  return supportedLearningLanguages.first.code;
});

final userLearningLanguageProvider = FutureProvider<String>((ref) async {
  final repository = ref.read(authRepositoryProvider);
  try {
    final persistedLanguage = await repository.getLearningLanguage();
    final resolved = languageOptionByCode(persistedLanguage).code;
    ref.read(selectedLearningLanguageProvider.notifier).state = resolved;
    return resolved;
  } catch (_) {
    return ref.read(selectedLearningLanguageProvider);
  }
});

final currentUserProfileProvider = FutureProvider<UserProfile>((ref) async {
  final repository = ref.read(authRepositoryProvider);
  return repository.getCurrentUserProfile();
});

class AuthActionController extends StateNotifier<AsyncValue<void>> {
  final LoginUser _loginUser;
  final RegisterUser _registerUser;
  final LogoutUser _logoutUser;
  final AuthRepository _authRepository;
  final GetLearningBootstrapContent _getLearningBootstrapContent;

  AuthActionController(
    this._loginUser,
    this._registerUser,
    this._logoutUser,
    this._authRepository,
    this._getLearningBootstrapContent,
  ) : super(const AsyncData(null));

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _loginUser(email: email, password: password),
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String learningLanguage,
    required String displayName,
    String? profileImageUrl,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _registerUser(
        email: email,
        password: password,
        learningLanguage: learningLanguage,
        displayName: displayName,
        profileImageUrl: profileImageUrl,
      );

      try {
        await _authRepository.setLearningLanguage(learningLanguage);
      } catch (_) {
        // Keep signup successful even if profile persistence is temporarily down.
      }

      try {
        await _getLearningBootstrapContent(learningLanguage);
      } catch (_) {
        // Content prefetch should not block signup success.
      }
    });
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _logoutUser());
  }
}

final authActionControllerProvider =
    StateNotifierProvider<AuthActionController, AsyncValue<void>>((ref) {
      return AuthActionController(
        ref.read(loginUserProvider),
        ref.read(registerUserProvider),
        ref.read(logoutUserProvider),
        ref.read(authRepositoryProvider),
        ref.read(getLearningBootstrapContentProvider),
      );
    });
