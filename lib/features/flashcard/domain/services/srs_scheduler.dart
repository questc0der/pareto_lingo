import 'package:pareto_lingo/features/flashcard/domain/entities/flashcard_item.dart';

class SrsSchedule {
  final int interval;
  final int repetitions;
  final int easeFactorPermille;
  final DateTime dueDate;

  const SrsSchedule({
    required this.interval,
    required this.repetitions,
    required this.easeFactorPermille,
    required this.dueDate,
  });
}

abstract class SrsScheduler {
  SrsSchedule schedule({
    required FlashcardItem card,
    required int quality,
    required DateTime reviewedAt,
  });
}
