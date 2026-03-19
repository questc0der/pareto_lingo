import 'package:pareto_lingo/features/podcast/domain/entities/podcast_episode.dart';
import 'package:pareto_lingo/features/podcast/domain/repositories/podcast_repository.dart';

class GetPodcastEpisodes {
  final PodcastRepository _repository;

  const GetPodcastEpisodes(this._repository);

  Future<List<PodcastEpisode>> call(String feedUrl) {
    return _repository.getEpisodes(feedUrl);
  }
}
