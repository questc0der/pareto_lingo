import 'dart:convert';

import 'package:flutter/services.dart';
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
  final bool _useRemoteSources;

  const LanguageBootstrapRemoteDataSource(
    this._client,
    this._backendBaseUrl, {
    required bool useRemoteSources,
  }) : _useRemoteSources = useRemoteSources;

  Future<LearningBootstrapContent> fetchContent(String languageCode) async {
    final option = languageOptionByCode(languageCode);
    final words = await _fetchTopWordsResolved(option.code);

    return LearningBootstrapContent(
      languageCode: option.code,
      topWords: words,
      lectureTopics: option.lectureTopics,
      readingText: option.readingText,
    );
  }

  Future<List<String>> _fetchTopWords(String languageCode) async {
    if (!_useRemoteSources) {
      return _offlineTopWords(languageCode);
    }

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
    if (languageCode == 'fr') {
      // Uses the shipped local asset to keep the app fully offline-capable.
      return const [];
    }

    final seeds = switch (languageCode) {
      'zh' => const [
        '你好',
        '谢谢',
        '家',
        '吃',
        '说',
        '朋友',
        '工作',
        '学校',
        '城市',
        '今天',
        '明天',
        '音乐',
        '学习',
        '阅读',
        '旅行',
      ],
      'en' => const [
        'hello',
        'thank',
        'house',
        'eat',
        'speak',
        'friend',
        'family',
        'work',
        'school',
        'city',
        'today',
        'tomorrow',
        'book',
        'music',
        'travel',
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

  Future<List<String>> _loadFrenchWordsFromAsset() async {
    try {
      final raw = await rootBundle.loadString('assets/french_words.json');
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => item as Map<String, dynamic>)
          .map((item) => (item['word'] ?? '').toString().trim())
          .where((word) => word.isNotEmpty)
          .take(1000)
          .toList(growable: false);
    } catch (_) {
      return const [
        'bonjour',
        'merci',
        'maison',
        'manger',
        'parler',
        'ami',
        'famille',
      ];
    }
  }

  Future<List<FlashcardWordMeaning>> fetchFlashcardDeck({
    required String languageCode,
    int limit = 1000,
    String? targetLanguage,
  }) async {
    if (!_useRemoteSources || _backendBaseUrl.trim().isEmpty) {
      if (languageCode == 'fr') {
        final pairs = await _loadFrenchDeckFromAsset();
        return pairs.take(limit).toList(growable: false);
      }
      return _buildFallbackDeck(
        languageCode: languageCode,
        targetLanguage: targetLanguage,
        limit: limit,
      );
    }

    final query = <String, String>{'language': languageCode, 'limit': '$limit'};
    if (targetLanguage != null && targetLanguage.trim().isNotEmpty) {
      query['targetLanguage'] = targetLanguage.trim();
    }

    final url = Uri.parse(
      '$_backendBaseUrl/api/v1/content/flashcards',
    ).replace(queryParameters: query);

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
      return _buildFallbackDeck(
        languageCode: languageCode,
        targetLanguage: targetLanguage,
        limit: limit,
      );
    }
  }

  Future<List<String>> _offlineTopWordsWithFrenchAsset(
    String languageCode,
  ) async {
    if (languageCode == 'fr') {
      final words = await _loadFrenchWordsFromAsset();
      if (words.isNotEmpty) {
        return words;
      }
    }
    return _offlineTopWords(languageCode);
  }

  Future<List<FlashcardWordMeaning>> _loadFrenchDeckFromAsset() async {
    try {
      final raw = await rootBundle.loadString('assets/french_words.json');
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => item as Map<String, dynamic>)
          .map(
            (item) => FlashcardWordMeaning(
              word: (item['word'] ?? '').toString().trim(),
              meaning: (item['meaning'] ?? '').toString().trim(),
            ),
          )
          .where((entry) => entry.word.isNotEmpty && entry.meaning.isNotEmpty)
          .take(1000)
          .toList(growable: false);
    } catch (_) {
      return const [
        FlashcardWordMeaning(word: 'bonjour', meaning: 'hello'),
        FlashcardWordMeaning(word: 'merci', meaning: 'thank you'),
        FlashcardWordMeaning(word: 'maison', meaning: 'house'),
      ];
    }
  }

  Future<List<String>> _fetchTopWordsResolved(String languageCode) async {
    if (!_useRemoteSources) {
      return _offlineTopWordsWithFrenchAsset(languageCode);
    }

    final remoteWords = await _fetchTopWords(languageCode);
    if (remoteWords.isNotEmpty) {
      return remoteWords;
    }

    return _offlineTopWordsWithFrenchAsset(languageCode);
  }

  List<FlashcardWordMeaning> _buildFallbackDeck({
    required String languageCode,
    required int limit,
    String? targetLanguage,
  }) {
    final words = _offlineTopWords(languageCode).take(limit);

    return words
        .map(
          (word) => FlashcardWordMeaning(
            word: word,
            meaning: _fallbackMeaningForWord(
              languageCode: languageCode,
              word: word,
              targetLanguage: targetLanguage,
            ),
          ),
        )
        .toList(growable: false);
  }

  String _fallbackMeaningForWord({
    required String languageCode,
    required String word,
    String? targetLanguage,
  }) {
    final target = (targetLanguage ?? 'en').trim().toLowerCase();

    if (languageCode == 'en') {
      return _localizedEnglishMeaning(word, target);
    }

    if (languageCode == 'zh') {
      return _localizedMandarinMeaning(word, target);
    }

    return 'meaning: $word';
  }

  String _localizedEnglishMeaning(String word, String targetLanguage) {
    final normalizedWord = word.trim().toLowerCase();
    final target = targetLanguage.trim().toLowerCase();

    const fr = {
      'hello': 'bonjour',
      'thank': 'merci',
      'house': 'maison',
      'eat': 'manger',
      'speak': 'parler',
      'friend': 'ami',
      'family': 'famille',
      'work': 'travail',
      'school': 'ecole',
      'city': 'ville',
      'today': 'aujourd\'hui',
      'tomorrow': 'demain',
      'book': 'livre',
      'music': 'musique',
      'travel': 'voyage',
    };

    const zh = {
      'hello': '你好',
      'thank': '谢谢',
      'house': '房子',
      'eat': '吃',
      'speak': '说',
      'friend': '朋友',
      'family': '家人',
      'work': '工作',
      'school': '学校',
      'city': '城市',
      'today': '今天',
      'tomorrow': '明天',
      'book': '书',
      'music': '音乐',
      'travel': '旅行',
    };

    if (target == 'fr') {
      return fr[normalizedWord] ?? normalizedWord;
    }

    if (target == 'zh') {
      return zh[normalizedWord] ?? normalizedWord;
    }

    return normalizedWord;
  }

  String _localizedMandarinMeaning(String word, String targetLanguage) {
    final normalizedWord = word.trim();
    final target = targetLanguage.trim().toLowerCase();

    const fr = {
      '你好': 'bonjour',
      '谢谢': 'merci',
      '家': 'maison',
      '吃': 'manger',
      '说': 'parler',
      '朋友': 'ami',
      '工作': 'travail',
      '学校': 'école',
      '城市': 'ville',
      '今天': 'aujourd\'hui',
      '明天': 'demain',
      '音乐': 'musique',
      '学习': 'apprendre',
      '阅读': 'lire',
      '旅行': 'voyage',
    };

    const en = {
      '你好': 'hello',
      '谢谢': 'thank you',
      '家': 'home',
      '吃': 'eat',
      '说': 'speak',
      '朋友': 'friend',
      '工作': 'work',
      '学校': 'school',
      '城市': 'city',
      '今天': 'today',
      '明天': 'tomorrow',
      '音乐': 'music',
      '学习': 'learn',
      '阅读': 'read',
      '旅行': 'travel',
    };

    if (target == 'fr') {
      return fr[normalizedWord] ?? normalizedWord;
    }

    if (target == 'en') {
      return en[normalizedWord] ?? normalizedWord;
    }

    return normalizedWord;
  }
}
