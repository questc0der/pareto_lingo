import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pareto_lingo/features/flashcard/presentation/providers/flashcard_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyLimitAsync = ref.watch(dailyFlashcardLimitProvider);
    final dailyLimit = dailyLimitAsync.maybeWhen(
      data: (value) => value,
      orElse: () => 10,
    );

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Learning Settings',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Set how many flashcards you want to study per day.'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Flashcards',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  '$dailyLimit',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: dailyLimit.toDouble(),
              min: 5,
              max: 100,
              divisions: 19,
              label: '$dailyLimit',
              onChanged: (value) {
                setDailyFlashcardLimit(ref, value.round());
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Default daily target is 10 cards.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
