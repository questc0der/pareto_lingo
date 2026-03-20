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

    try {
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return _offlineTopWords(languageCode);
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

      if (words.length < 200) {
        return _offlineTopWords(languageCode);
      }

      return words;
    } catch (_) {
      return _offlineTopWords(languageCode);
    }
  }

  List<String> _offlineTopWords(String languageCode) {
    final seeds = switch (languageCode) {
      'fr' => const [
        'bonjour',
        'merci',
        'maison',
        'manger',
        'parler',
        'ami',
        'famille',
        'travail',
        'école',
        'ville',
        'jour',
        'soir',
        'livre',
        'musique',
        'voyage',
      ],
      'es' => const [
        'hola',
        'gracias',
        'casa',
        'comer',
        'hablar',
        'amigo',
        'familia',
        'trabajo',
        'escuela',
        'ciudad',
        'día',
        'noche',
        'libro',
        'música',
        'viaje',
      ],
      'de' => const [
        'hallo',
        'danke',
        'haus',
        'essen',
        'sprechen',
        'freund',
        'familie',
        'arbeit',
        'schule',
        'stadt',
        'tag',
        'abend',
        'buch',
        'musik',
        'reise',
      ],
      _ => const ['hello', 'thanks', 'home', 'learn', 'speak'],
    };

    final words = <String>[];
    for (var i = 0; i < 1000; i++) {
      final base = seeds[i % seeds.length];
      words.add('$base-${(i ~/ seeds.length) + 1}');
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

    try {
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 8));
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
    } catch (_) {
      return const [];
    }
  }
}
