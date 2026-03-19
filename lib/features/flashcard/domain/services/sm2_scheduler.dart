import 'dart:math';

import 'package:pareto_lingo/features/flashcard/domain/entities/flashcard_item.dart';
import 'package:pareto_lingo/features/flashcard/domain/services/srs_scheduler.dart';

class Sm2Scheduler implements SrsScheduler {
  const Sm2Scheduler();

  @override
  SrsSchedule schedule({
    required FlashcardItem card,
    required int quality,
    required DateTime reviewedAt,
  }) {
    final boundedQuality = quality.clamp(0, 5);
    final oldEase = card.easeFactorPermille / 1000;

    if (boundedQuality < 3) {
      return SrsSchedule(
        interval: 0,
        repetitions: 0,
        easeFactorPermille: card.easeFactorPermille,
        dueDate: reviewedAt.add(const Duration(minutes: 1)),
      );
    }

    final updatedEase = max(
      1.3,
      oldEase +
          (0.1 - (5 - boundedQuality) * (0.08 + (5 - boundedQuality) * 0.02)),
    );

    final updatedRepetitions = card.repetitions + 1;
    final updatedInterval = switch (updatedRepetitions) {
      1 => 1,
      2 => 6,
      _ => max(1, (card.interval * updatedEase).round()),
    };

    return SrsSchedule(
      interval: updatedInterval,
      repetitions: updatedRepetitions,
      easeFactorPermille: (updatedEase * 1000).round(),
      dueDate: reviewedAt.add(Duration(days: updatedInterval)),
    );
  }
}
