import 'package:home_widget/home_widget.dart';

class HomeScreenWidgetService {
  HomeScreenWidgetService._();

  static const String _androidWidgetName = 'ParetoHomeWidgetProvider';
  static const String _iosWidgetName = 'ParetoLingoHomeWidget';
  static const String _appGroupId = 'group.com.example.pareto_lingo';

  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  static Future<void> sync({
    required int streak,
    required bool reminderEnabled,
    required int reminderHour,
    required int reminderMinute,
    required String languageCode,
    required String languageFlag,
  }) async {
    await HomeWidget.saveWidgetData<int>('pl_streak', streak);
    await HomeWidget.saveWidgetData<bool>(
      'pl_reminder_enabled',
      reminderEnabled,
    );
    await HomeWidget.saveWidgetData<int>('pl_reminder_hour', reminderHour);
    await HomeWidget.saveWidgetData<int>('pl_reminder_minute', reminderMinute);
    await HomeWidget.saveWidgetData<String>('pl_language_code', languageCode);
    await HomeWidget.saveWidgetData<String>('pl_language_flag', languageFlag);

    await HomeWidget.updateWidget(
      name: _androidWidgetName,
      iOSName: _iosWidgetName,
    );
  }
}
