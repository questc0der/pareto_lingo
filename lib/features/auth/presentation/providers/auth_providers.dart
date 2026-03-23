import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/domain/entities/app_user.dart';
import 'package:pareto_lingo/features/auth/domain/entities/user_profile.dart';

const _learningLanguageKey = 'selected_learning_language';
const _displayNameKey = 'local_display_name';

final localAppSettingsBoxProvider = Provider<Box<String>>((ref) {
  return Hive.box<String>('app_settings');
});

final selectedLearningLanguageProvider = StateProvider<String>((ref) {
  final stored = ref
      .read(localAppSettingsBoxProvider)
      .get(_learningLanguageKey);
  return languageOptionByCode(stored).code;
});

final userLearningLanguageProvider = FutureProvider<String>((ref) async {
  final stored = ref
      .read(localAppSettingsBoxProvider)
      .get(_learningLanguageKey);
  final resolved = languageOptionByCode(stored).code;
  ref.read(selectedLearningLanguageProvider.notifier).state = resolved;
  return resolved;
});

Future<void> setLearningLanguage(WidgetRef ref, String code) async {
  final resolved = languageOptionByCode(code).code;
  await ref
      .read(localAppSettingsBoxProvider)
      .put(_learningLanguageKey, resolved);
  ref.read(selectedLearningLanguageProvider.notifier).state = resolved;
}

final authStateProvider = StreamProvider<AppUser?>((ref) async* {
  yield const AppUser(id: 'local-user', email: 'local@pareto.lingo');
});

final currentUserProfileProvider = FutureProvider<UserProfile>((ref) async {
  final languageCode = await ref.read(userLearningLanguageProvider.future);
  final name =
      ref.read(localAppSettingsBoxProvider).get(_displayNameKey) ?? 'Learner';
  return UserProfile(displayName: name, learningLanguage: languageCode);
});
