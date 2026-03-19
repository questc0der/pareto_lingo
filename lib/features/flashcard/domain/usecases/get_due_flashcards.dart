import 'package:pareto_lingo/features/flashcard/domain/entities/flashcard_item.dart';
import 'package:pareto_lingo/features/flashcard/domain/repositories/flashcard_repository.dart';

class GetDueFlashcards {
  final FlashcardRepository _repository;

  const GetDueFlashcards(this._repository);

  Future<List<FlashcardItem>> call({required int limit}) {
    return _repository.getDueCards(limit: limit);
  }
}
