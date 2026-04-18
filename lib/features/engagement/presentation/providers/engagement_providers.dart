import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/core/notifications/reminder_notification_service.dart';
import 'package:pareto_lingo/core/widgets/home_screen_widget_service.dart';

const _streakKey = 'current_streak';
const _lastActiveDateKey = 'last_active_date';
const _reminderEnabledKey = 'daily_reminder_enabled';
const _reminderHourKey = 'daily_reminder_hour';
const _reminderMinuteKey = 'daily_reminder_minute';

class ReminderSettings {
  final bool enabled;
  final TimeOfDay time;

  const ReminderSettings({required this.enabled, required this.time});
}

final engagementSettingsBoxProvider = Provider<Box<String>>((ref) {
  return Hive.box<String>('app_settings');
});

final streakCounterProvider = StreamProvider<int>((ref) async* {
  final box = ref.read(engagementSettingsBoxProvider);

  int parseStreak() => int.tryParse(box.get(_streakKey) ?? '0') ?? 0;

  yield parseStreak();

  await for (final _ in box.watch(key: _streakKey)) {
    yield parseStreak();
  }
});

final reminderSettingsProvider = StreamProvider<ReminderSettings>((ref) async* {
  final box = ref.read(engagementSettingsBoxProvider);

  ReminderSettings parse() {
    final enabled = (box.get(_reminderEnabledKey) ?? 'false') == 'true';
    final hour = int.tryParse(box.get(_reminderHourKey) ?? '20') ?? 20;
    final minute = int.tryParse(box.get(_reminderMinuteKey) ?? '0') ?? 0;
    return ReminderSettings(
      enabled: enabled,
      time: TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59)),
    );
  }

  yield parse();

  await for (final _ in box.watch()) {
    yield parse();
  }
});

Future<void> markDailyEngagement(WidgetRef ref) async {
  final box = ref.read(engagementSettingsBoxProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final lastRaw = box.get(_lastActiveDateKey);
  final streak = int.tryParse(box.get(_streakKey) ?? '0') ?? 0;

  DateTime? last;
  if (lastRaw != null && lastRaw.trim().isNotEmpty) {
    last = DateTime.tryParse(lastRaw);
    if (last != null) {
      last = DateTime(last.year, last.month, last.day);
    }
  }

  if (last != null && _isSameDay(last, today)) {
    return;
  }

  final yesterday = today.subtract(const Duration(days: 1));
  final nextStreak =
      (last != null && _isSameDay(last, yesterday)) ? (streak + 1) : 1;

  await box.put(_streakKey, nextStreak.toString());
  await box.put(_lastActiveDateKey, today.toIso8601String());
  await _syncWidget(box);
}

Future<void> setReminderEnabled(WidgetRef ref, bool enabled) async {
  final box = ref.read(engagementSettingsBoxProvider);
  await box.put(_reminderEnabledKey, enabled.toString());

  if (enabled) {
    final granted = await ReminderNotificationService.requestPermissions();
    if (!granted) {
      await box.put(_reminderEnabledKey, 'false');
      await ReminderNotificationService.cancelDailyReminder();
      await _syncWidget(box);
      return;
    }
  }

  await ReminderNotificationService.syncFromSettings(box);
  await _syncWidget(box);
}

Future<void> setReminderTime(WidgetRef ref, TimeOfDay time) async {
  final box = ref.read(engagementSettingsBoxProvider);
  await box.put(_reminderHourKey, time.hour.toString());
  await box.put(_reminderMinuteKey, time.minute.toString());
  await ReminderNotificationService.syncFromSettings(box);
  await _syncWidget(box);
}

Future<void> syncHomeWidgetFromSettings(WidgetRef ref) async {
  final box = ref.read(engagementSettingsBoxProvider);
  await _syncWidget(box);
}

Future<void> _syncWidget(Box<String> box) async {
  final streak = int.tryParse(box.get(_streakKey) ?? '0') ?? 0;
  final enabled = (box.get(_reminderEnabledKey) ?? 'false') == 'true';
  final hour = int.tryParse(box.get(_reminderHourKey) ?? '20') ?? 20;
  final minute = int.tryParse(box.get(_reminderMinuteKey) ?? '0') ?? 0;
  final languageCode = languageOptionByCode(box.get('selected_learning_language')).code;
  final languageFlag = languageOptionByCode(languageCode).flag;

  await HomeScreenWidgetService.sync(
    streak: streak,
    reminderEnabled: enabled,
    reminderHour: hour,
    reminderMinute: minute,
    languageCode: languageCode,
    languageFlag: languageFlag,
  );
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
