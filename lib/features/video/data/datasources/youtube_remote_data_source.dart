import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/video/domain/entities/learning_video.dart';

class YoutubeRemoteDataSource {
  final http.Client _client;
  final String _apiKey;

  const YoutubeRemoteDataSource(this._client, this._apiKey);

  Future<List<LearningVideo>> fetchLearningVideos({
    required String languageCode,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'Missing YOUTUBE_API_KEY. Provide it with --dart-define.',
      );
    }

    final selectedLanguage = languageOptionByCode(languageCode);
    final encodedQuery = Uri.encodeQueryComponent(selectedLanguage.videoQuery);

    final url = Uri.parse(
      'https://www.googleapis.com/youtube/v3/search?'
      'part=snippet&type=video&videoDuration=short&'
      'relevanceLanguage=${selectedLanguage.code}&q=$encodedQuery&'
      'maxResults=100&key=$_apiKey',
    );

    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw Exception('Unable to fetch videos.');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? []);

    return items
        .map((item) => item as Map<String, dynamic>)
        .map((item) {
          final id =
              (item['id'] as Map<String, dynamic>? ?? {})['videoId']
                  ?.toString() ??
              '';
          final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
          final title = snippet['title']?.toString() ?? '';
          final thumbnails =
              snippet['thumbnails'] as Map<String, dynamic>? ?? {};
          final thumbnailUrl =
              (thumbnails['high'] as Map<String, dynamic>? ?? {})['url']
                  ?.toString() ??
              '';

          return LearningVideo(
            id: id,
            title: title,
            thumbnailUrl: thumbnailUrl,
          );
        })
        .where((video) => video.id.isNotEmpty)
        .toList(growable: false);
  }
}
