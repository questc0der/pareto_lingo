import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pareto_lingo/models/flashcard_model.dart';
import 'package:pareto_lingo/models/seed_flashcard.dart';
import 'firebase_options.dart';
import 'package:pareto_lingo/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(FlashcardAdapter());

  if (Hive.isBoxOpen('flashcards')) {
    await Hive.box('flashcards').close();
  }

  // Open the box with correct type
  await Hive.openBox<Flashcard>('flashcards');
  await seedFlashcards();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
