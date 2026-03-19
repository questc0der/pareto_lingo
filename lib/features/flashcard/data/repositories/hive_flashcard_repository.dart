import 'package:hive/hive.dart';
import 'package:pareto_lingo/features/flashcard/domain/entities/flashcard_item.dart';
import 'package:pareto_lingo/features/flashcard/domain/repositories/flashcard_repository.dart';
import 'package:pareto_lingo/features/flashcard/domain/services/srs_scheduler.dart';
import 'package:pareto_lingo/models/flashcard_model.dart';

class HiveFlashcardRepository implements FlashcardRepository {
  final Box<Flashcard> _box;

  const HiveFlashcardRepository(this._box);

  @override
  Future<List<FlashcardItem>> getDueCards({
    required int limit,
    DateTime? asOf,
  }) async {
    final now = asOf ?? DateTime.now();
    final dueCards = <FlashcardItem>[];

    for (var index = 0; index < _box.length; index++) {
      final key = _box.keyAt(index);
      final card = _box.get(key);

      if (card == null) continue;
      if (card.dueDate.isAfter(now)) continue;

      dueCards.add(
        FlashcardItem(
          id: key.toString(),
          word: card.word,
          meaning: card.meaning,
          interval: card.interval,
          repetitions: card.repetitions,
          easeFactorPermille: card.easeFactor,
          dueDate: card.dueDate,
        ),
      );

      if (dueCards.length >= limit) break;
    }

    return dueCards;
  }

  @override
  Future<void> applyReview({
    required String cardId,
    required SrsSchedule schedule,
  }) async {
    final card = _box.get(_resolveKey(cardId));
    if (card == null) return;

    card.interval = schedule.interval;
    card.repetitions = schedule.repetitions;
    card.easeFactor = schedule.easeFactorPermille;
    card.dueDate = schedule.dueDate;

    await card.save();
  }

  dynamic _resolveKey(String id) {
    return int.tryParse(id) ?? id;
  }
}
