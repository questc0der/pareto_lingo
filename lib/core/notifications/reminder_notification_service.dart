import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderNotificationService {
  ReminderNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _dailyReminderId = 1207;
  static const String _channelId = 'daily_learning_reminder';
  static const String _channelName = 'Daily Learning Reminders';
  static const String _channelDescription =
      'Reminders to practice language learning daily';

  static bool _initialized = false;

  static Future<void> initialize({required Box<String> appSettings}) async {
    if (_initialized) {
      await syncFromSettings(appSettings);
      return;
    }

    tz.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // Keep tz.local default if timezone lookup fails.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    _initialized = true;
    await syncFromSettings(appSettings);
  }

  static Future<bool> requestPermissions() async {
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    final ios =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    final macos =
        _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();

    final androidGranted = await android?.requestNotificationsPermission();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    final macosGranted = await macos?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return (androidGranted ?? true) &&
        (iosGranted ?? true) &&
        (macosGranted ?? true);
  }

  static Future<void> syncFromSettings(Box<String> appSettings) async {
    final enabled =
        (appSettings.get('daily_reminder_enabled') ?? 'false') == 'true';
    if (!enabled) {
      await cancelDailyReminder();
      return;
    }

    final hour =
        int.tryParse(appSettings.get('daily_reminder_hour') ?? '20') ?? 20;
    final minute =
        int.tryParse(appSettings.get('daily_reminder_minute') ?? '0') ?? 0;

    await scheduleDailyReminder(hour: hour, minute: minute);
  }

  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    final safeHour = hour.clamp(0, 23);
    final safeMinute = minute.clamp(0, 59);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      safeHour,
      safeMinute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Time to practice',
      'Review your flashcards and keep your streak alive.',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_dailyReminderId);
  }
}
