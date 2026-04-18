import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:pareto_lingo/core/widgets/home_screen_widget_service.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/domain/entities/app_user.dart';
import 'package:pareto_lingo/features/auth/domain/entities/user_profile.dart';

const _learningLanguageKey = 'selected_learning_language';
const _displayNameKey = 'local_display_name';
const _nativeLanguageKey = 'native_language_code';

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
  final box = ref.read(localAppSettingsBoxProvider);
  await box.put(_learningLanguageKey, resolved);
  ref.read(selectedLearningLanguageProvider.notifier).state = resolved;

  final streak = int.tryParse(box.get('current_streak') ?? '0') ?? 0;
  final reminderEnabled = (box.get('daily_reminder_enabled') ?? 'false') == 'true';
  final hour = int.tryParse(box.get('daily_reminder_hour') ?? '20') ?? 20;
  final minute = int.tryParse(box.get('daily_reminder_minute') ?? '0') ?? 0;

  await HomeScreenWidgetService.sync(
    streak: streak,
    reminderEnabled: reminderEnabled,
    reminderHour: hour,
    reminderMinute: minute,
    languageCode: resolved,
    languageFlag: languageOptionByCode(resolved).flag,
  );
}

final selectedNativeLanguageProvider = StateProvider<String>((ref) {
  final stored = ref.read(localAppSettingsBoxProvider).get(_nativeLanguageKey);
  final resolved = languageOptionByCode(stored).code;
  return resolved;
});

final userNativeLanguageProvider = FutureProvider<String>((ref) async {
  final stored = ref.read(localAppSettingsBoxProvider).get(_nativeLanguageKey);
  final resolved = languageOptionByCode(stored).code;
  ref.read(selectedNativeLanguageProvider.notifier).state = resolved;
  return resolved;
});

Future<void> setNativeLanguage(WidgetRef ref, String code) async {
  final resolved = languageOptionByCode(code).code;
  await ref.read(localAppSettingsBoxProvider).put(_nativeLanguageKey, resolved);
  ref.read(selectedNativeLanguageProvider.notifier).state = resolved;
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
