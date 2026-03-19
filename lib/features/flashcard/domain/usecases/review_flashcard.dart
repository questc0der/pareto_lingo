import 'package:pareto_lingo/features/flashcard/domain/entities/flashcard_item.dart';
import 'package:pareto_lingo/features/flashcard/domain/repositories/flashcard_repository.dart';
import 'package:pareto_lingo/features/flashcard/domain/services/srs_scheduler.dart';

class ReviewFlashcard {
  final FlashcardRepository _repository;
  final SrsScheduler _scheduler;

  const ReviewFlashcard(this._repository, this._scheduler);

  Future<void> call({
    required FlashcardItem card,
    required int quality,
    DateTime? reviewedAt,
  }) async {
    final schedule = _scheduler.schedule(
      card: card,
      quality: quality,
      reviewedAt: reviewedAt ?? DateTime.now(),
    );

    await _repository.applyReview(cardId: card.id, schedule: schedule);
  }
}
