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
    final query = category.queryForLanguage(languageCode);
    final results = await _remoteDataSource.searchPodcasts(
      query: query,
      limit: category.limit,
      languageCode: languageCode,
    );

    final candidates = results.items.where((item) => item.feedUrl != null);
    final languageFiltered = candidates.where(
      (item) => _matchesRequestedLanguage(item, languageCode),
    );
    final categoryFiltered = languageFiltered.where(
      (item) => _matchesCategory(item, category),
    );

    final selected =
        categoryFiltered.isNotEmpty
            ? categoryFiltered
            : (languageFiltered.isNotEmpty ? languageFiltered : candidates);

    final uniqueFeedUrls = <String>{};
    final podcasts = <PodcastItem>[];

    for (final item in selected) {
      final feedUrl = (item.feedUrl ?? '').trim();
      if (feedUrl.isEmpty) continue;
      if (!uniqueFeedUrls.add(feedUrl)) continue;

      podcasts.add(
        PodcastItem(imageUrl: item.artworkUrl600 ?? '', feedUrl: feedUrl),
      );
    }

    return podcasts;
  }

  bool _matchesRequestedLanguage(dynamic item, String languageCode) {
    final haystack =
        '${item.trackName ?? ''} ${item.collectionName ?? ''}'.toLowerCase();

    final include = switch (languageCode.toLowerCase()) {
      'fr' => ['french', 'français', 'francais'],
      'zh' => ['chinese', 'mandarin', '中文', '普通话', '汉语'],
      'en' => ['english'],
      _ => ['french'],
    };

    final exclude = switch (languageCode.toLowerCase()) {
      'fr' => ['chinese', 'mandarin', 'english'],
      'zh' => ['french', 'français', 'english'],
      'en' => ['french', 'français', 'chinese', 'mandarin', '中文'],
      _ => const <String>[],
    };

    final hasInclude = include.any(haystack.contains);
    final hasExclude = exclude.any(haystack.contains);

    return hasInclude && !hasExclude;
  }

  bool _matchesCategory(dynamic item, PodcastCategory category) {
    final haystack =
        '${item.trackName ?? ''} ${item.collectionName ?? ''}'.toLowerCase();

    final categoryTokens = switch (category) {
      PodcastCategory.beginner => ['beginner', 'easy', 'basic', 'starter'],
      PodcastCategory.intermediate => ['intermediate', 'mid', 'b1', 'b2'],
      PodcastCategory.advanced => ['advanced', 'c1', 'c2', 'fluent'],
      PodcastCategory.popular => const <String>[],
    };

    if (categoryTokens.isEmpty) {
      return true;
    }

    return categoryTokens.any(haystack.contains);
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
