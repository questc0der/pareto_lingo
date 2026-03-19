import 'package:pareto_lingo/features/podcast/domain/entities/podcast_category.dart';
import 'package:pareto_lingo/features/podcast/domain/entities/podcast_item.dart';
import 'package:pareto_lingo/features/podcast/domain/repositories/podcast_repository.dart';

class GetPodcastsByCategory {
  final PodcastRepository _repository;

  const GetPodcastsByCategory(this._repository);

  Future<List<PodcastItem>> call(
    PodcastCategory category, {
    required String languageCode,
  }) {
    return _repository.getPodcasts(category, languageCode: languageCode);
  }
}
