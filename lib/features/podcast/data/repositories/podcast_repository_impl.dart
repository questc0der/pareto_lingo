import 'package:pareto_lingo/features/podcast/data/datasources/podcast_remote_data_source.dart';
import 'package:pareto_lingo/features/podcast/domain/entities/podcast_category.dart';
import 'package:pareto_lingo/features/podcast/domain/entities/podcast_episode.dart';
import 'package:pareto_lingo/features/podcast/domain/entities/podcast_item.dart';
import 'package:pareto_lingo/features/podcast/domain/repositories/podcast_repository.dart';

class PodcastRepositoryImpl implements PodcastRepository {
  final PodcastRemoteDataSource _remoteDataSource;

  const PodcastRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<PodcastItem>> getPodcasts(
    PodcastCategory category, {
    required String languageCode,
  }) async {
    final results = await _remoteDataSource.searchPodcasts(
      query: category.queryForLanguage(languageCode),
      limit: category.limit,
      languageCode: languageCode,
    );

    return results.items
        .where((item) => item.feedUrl != null)
        .map(
          (item) => PodcastItem(
            imageUrl: item.artworkUrl600 ?? '',
            feedUrl: item.feedUrl!,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<PodcastEpisode>> getEpisodes(String feedUrl) async {
    final feed = await _remoteDataSource.loadFeed(url: feedUrl);

    return feed.episodes
        .where((episode) => (episode.contentUrl ?? '').isNotEmpty)
        .map(
          (episode) => PodcastEpisode(
            title: episode.title,
            audioUrl: episode.contentUrl ?? '',
            imageUrl: episode.imageUrl ?? '',
          ),
        )
        .toList(growable: false);
  }
}
