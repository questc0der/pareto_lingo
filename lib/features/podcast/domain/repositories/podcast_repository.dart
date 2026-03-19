import 'package:pareto_lingo/features/podcast/domain/entities/podcast_category.dart';
import 'package:pareto_lingo/features/podcast/domain/entities/podcast_episode.dart';
import 'package:pareto_lingo/features/podcast/domain/entities/podcast_item.dart';

abstract class PodcastRepository {
  Future<List<PodcastItem>> getPodcasts(
    PodcastCategory category, {
    required String languageCode,
  });

  Future<List<PodcastEpisode>> getEpisodes(String feedUrl);
}
