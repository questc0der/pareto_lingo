import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pareto_lingo/features/news/domain/entities/news_article.dart';

class WikinewsService {
  final http.Client _client;

  WikinewsService(this._client);

  static const _supportedCodes = {'fr', 'es', 'de', 'en'};

  Future<List<NewsArticle>> fetchLatestNews({
    required String languageCode,
    int limit = 25,
  }) async {
    final safeCode = _safeLanguageCode(languageCode);
    final uri = Uri.https('$safeCode.wikinews.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'generator': 'recentchanges',
      'grcnamespace': '0',
      'grclimit': '$limit',
      'prop': 'extracts|pageimages|info',
      'inprop': 'url',
      'exintro': '1',
      'explaintext': '1',
      'pithumbsize': '700',
      'origin': '*',
    });

    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load news.');
    }

    final root = json.decode(response.body) as Map<String, dynamic>;
    final pages =
        (root['query'] as Map<String, dynamic>? ?? const {})['pages']
            as Map<String, dynamic>? ??
        const {};

    final articles =
        pages.values
            .whereType<Map<String, dynamic>>()
            .map((page) => _fromPageMap(page, safeCode))
            .where((item) => item.title.isNotEmpty)
            .toList()
          ..sort((a, b) => b.pageId.compareTo(a.pageId));

    return articles;
  }

  Future<NewsArticle> fetchArticleDetail({
    required String languageCode,
    required int pageId,
    required NewsArticle fallback,
  }) async {
    final safeCode = _safeLanguageCode(languageCode);
    final uri = Uri.https('$safeCode.wikinews.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'prop': 'extracts|pageimages|info',
      'inprop': 'url',
      'explaintext': '1',
      'pageids': '$pageId',
      'pithumbsize': '900',
      'origin': '*',
    });

    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return fallback;
    }

    final root = json.decode(response.body) as Map<String, dynamic>;
    final pages =
        (root['query'] as Map<String, dynamic>? ?? const {})['pages']
            as Map<String, dynamic>? ??
        const {};

    final page = pages['$pageId'] as Map<String, dynamic>?;
    if (page == null) return fallback;

    final detail = _fromPageMap(page, safeCode);

    return fallback.copyWith(
      description: detail.description,
      content: detail.content,
      thumbnailUrl: detail.thumbnailUrl,
      articleUrl: detail.articleUrl,
    );
  }

  Future<String> translateText({
    required String text,
    required String sourceLanguage,
    String targetLanguage = 'en',
  }) async {
    final input = text.trim();
    if (input.isEmpty) return '';

    final safeSource = _safeLanguageCode(sourceLanguage);
    final safeTarget = targetLanguage.trim().isEmpty ? 'en' : targetLanguage;

    final uri = Uri.https('api.mymemory.translated.net', '/get', {
      'q': input,
      'langpair': '$safeSource|$safeTarget',
    });

    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to translate selected text.');
    }

    final root = json.decode(response.body) as Map<String, dynamic>;
    final translated =
        (root['responseData'] as Map<String, dynamic>? ??
                const {})['translatedText']
            ?.toString()
            .trim() ??
        '';

    if (translated.isEmpty) {
      throw Exception('Translation unavailable for this selection.');
    }

    return translated;
  }

  NewsArticle _fromPageMap(Map<String, dynamic> page, String languageCode) {
    final extract = (page['extract']?.toString() ?? '').trim();
    final title = (page['title']?.toString() ?? '').trim();
    final fullUrl = (page['fullurl']?.toString() ?? '').trim();
    final thumbnail =
        ((page['thumbnail'] as Map<String, dynamic>?)?['source']?.toString() ??
                '')
            .trim();

    final pageId = (page['pageid'] as num?)?.toInt() ?? 0;

    return NewsArticle(
      pageId: pageId,
      languageCode: languageCode,
      title: title,
      description: extract,
      content: extract,
      thumbnailUrl: thumbnail,
      articleUrl: fullUrl,
    );
  }

  String _safeLanguageCode(String input) {
    final code = input.toLowerCase().trim();
    if (_supportedCodes.contains(code)) return code;
    return 'en';
  }
}
