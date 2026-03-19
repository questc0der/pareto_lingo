import 'package:pareto_lingo/features/flashcard/domain/entities/flashcard_item.dart';
import 'package:pareto_lingo/features/flashcard/domain/services/srs_scheduler.dart';

abstract class FlashcardRepository {
  Future<List<FlashcardItem>> getDueCards({required int limit, DateTime? asOf});

  Future<void> applyReview({
    required String cardId,
    required SrsSchedule schedule,
  });
}
