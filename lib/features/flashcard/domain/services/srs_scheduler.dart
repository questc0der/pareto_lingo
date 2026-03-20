import 'package:pareto_lingo/features/flashcard/domain/entities/flashcard_item.dart';

class SrsSchedule {
  final int interval;
  final int repetitions;
  final int easeFactorPermille;
  final DateTime dueDate;
  // FSRS fields (unused by SM2, populated by FSRS)
  final double stability;
  final double difficulty;
  final int lapses;

  const SrsSchedule({
    required this.interval,
    required this.repetitions,
    required this.easeFactorPermille,
    required this.dueDate,
    this.stability = 0.0,
    this.difficulty = 5.0,
    this.lapses = 0,
  });
}

abstract class SrsScheduler {
  SrsSchedule schedule({
    required FlashcardItem card,
    required int quality,
    required DateTime reviewedAt,
  });
}
