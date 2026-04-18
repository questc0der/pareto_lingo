import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pareto_lingo/core/notifications/reminder_notification_service.dart';
import 'package:pareto_lingo/core/widgets/home_screen_widget_service.dart';
import 'package:pareto_lingo/firebase_options.dart';
import 'package:pareto_lingo/models/flashcard_model.dart';
import 'package:pareto_lingo/models/seed_flashcard.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> initialize() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FlashcardAdapter());
    }

    if (Hive.isBoxOpen('flashcards')) {
      await Hive.box('flashcards').close();
    }

    await Hive.openBox<Flashcard>('flashcards');
    await Hive.openBox<double>('video_progress');
    await Hive.openBox<String>('learning_bootstrap_cache');
    final appSettingsBox = await Hive.openBox<String>('app_settings');
    await seedFlashcards();

    await ReminderNotificationService.initialize(appSettings: appSettingsBox);
    await HomeScreenWidgetService.initialize();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
