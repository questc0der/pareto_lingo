import 'package:podcast_search/podcast_search.dart';

class PodcastRemoteDataSource {
  final Search _search;

  const PodcastRemoteDataSource(this._search);

  Future<SearchResult> searchPodcasts({
    required String query,
    required int limit,
    required String languageCode,
  }) {
    final country = switch (languageCode.toLowerCase()) {
      'zh' => Country.china,
      'en' => Country.unitedStates,
      _ => Country.france,
    };

    return _search.search(query, country: country, limit: limit);
  }

  Future<Podcast> loadFeed({required String url}) {
    return Feed.loadFeed(url: url);
  }
}
