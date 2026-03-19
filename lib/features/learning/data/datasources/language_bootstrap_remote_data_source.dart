import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/learning/domain/entities/learning_bootstrap_content.dart';

class FlashcardWordMeaning {
  final String word;
  final String meaning;

  const FlashcardWordMeaning({required this.word, required this.meaning});
}

class LanguageBootstrapRemoteDataSource {
  final http.Client _client;
  final String _backendBaseUrl;

  const LanguageBootstrapRemoteDataSource(this._client, this._backendBaseUrl);

  Future<LearningBootstrapContent> fetchContent(String languageCode) async {
    final option = languageOptionByCode(languageCode);
    final words = await _fetchTopWords(option.code);

    return LearningBootstrapContent(
      languageCode: option.code,
      topWords: words,
      lectureTopics: option.lectureTopics,
      readingText: option.readingText,
    );
  }

  Future<List<String>> _fetchTopWords(String languageCode) async {
    final url = Uri.parse(
      'https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/$languageCode/${languageCode}_50k.txt',
    );

    final response = await _client.get(url);
    if (response.statusCode != 200) {
      return const [];
    }

    final lines = const LineSplitter().convert(response.body);
    final words = <String>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final firstToken = line.split(' ').first.trim();
      if (firstToken.isEmpty) continue;
      words.add(firstToken);
      if (words.length >= 1000) break;
    }

    return words;
  }

  Future<List<FlashcardWordMeaning>> fetchFlashcardDeck({
    required String languageCode,
    int limit = 1000,
  }) async {
    if (_backendBaseUrl.trim().isEmpty) {
      return const [];
    }

    final url = Uri.parse(
      '$_backendBaseUrl/api/v1/content/flashcards?language=$languageCode&limit=$limit',
    );

    final response = await _client.get(url);
    if (response.statusCode != 200) {
      return const [];
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (decoded['items'] as List<dynamic>? ?? const []);

    return items
        .map((item) => item as Map<String, dynamic>)
        .map(
          (item) => FlashcardWordMeaning(
            word: (item['word'] ?? '').toString().trim(),
            meaning: (item['meaning'] ?? '').toString().trim(),
          ),
        )
        .where((entry) => entry.word.isNotEmpty && entry.meaning.isNotEmpty)
        .toList(growable: false);
  }
}
