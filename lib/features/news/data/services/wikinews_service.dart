import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pareto_lingo/features/news/domain/entities/news_article.dart';
import 'package:xml/xml.dart';

class WikinewsService {
  final http.Client _client;

  WikinewsService(this._client);

  static const _supportedCodes = {'fr', 'es', 'de', 'en'};
  static const _newsLocaleByLanguage = {
    'fr': ('FR', 'fr'),
    'es': ('ES', 'es'),
    'de': ('DE', 'de'),
    'en': ('US', 'en'),
  };

  Future<List<NewsArticle>> fetchLatestNews({
    required String languageCode,
    int limit = 25,
  }) async {
    final safeCode = _safeLanguageCode(languageCode);
    final locale = _newsLocaleByLanguage[safeCode] ?? ('US', 'en');
    final ceid = '${locale.$1}:${locale.$2}';

    final uri = Uri.https('news.google.com', '/rss', {
      'hl': '${locale.$2}-${locale.$1}',
      'gl': locale.$1,
      'ceid': ceid,
    });

    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent': 'pareto-lingo-news/1.0',
        'Accept': 'application/rss+xml, application/xml;q=0.9, */*;q=0.8',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load news.');
    }

    final xml = XmlDocument.parse(response.body);
    final items = xml.findAllElements('item');

    final articles = <NewsArticle>[];
    for (final item in items) {
      final title = _childText(item, 'title');
      final link = _childText(item, 'link');
      final pubDateRaw = _childText(item, 'pubDate');
      final source = _childText(item, 'source');
      final rawDescription = _childText(item, 'description');
      final description = _cleanDescription(rawDescription);
      final image = _extractImageUrl(item, rawDescription);

      if (title.isEmpty || link.isEmpty) continue;

      final publishedAt = _parsePublishedAt(pubDateRaw);
      final article = NewsArticle(
        pageId: _stableId(link),
        languageCode: safeCode,
        title: title,
        description: description,
        content: description,
        thumbnailUrl: image,
        articleUrl: link,
        publishedAt: publishedAt,
        source: source.isEmpty ? 'Google News' : source,
      );

      articles.add(article);
      if (articles.length >= limit) break;
    }

    articles.sort((a, b) {
      final ad = a.publishedAt;
      final bd = b.publishedAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    return articles;
  }

  Future<NewsArticle> fetchArticleDetail({
    required String languageCode,
    required int pageId,
    required NewsArticle fallback,
  }) async {
    final url = fallback.articleUrl.trim();
    if (url.isEmpty) return fallback;

    try {
      final uri = Uri.parse(url);
      final response = await _client
          .get(
            uri,
            headers: const {
              'User-Agent': 'pareto-lingo-news/1.0',
              'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallback;
      }

      final extracted = _extractReadableTextFromHtml(response.body);
      if (extracted.length < 180) {
        return fallback;
      }

      return fallback.copyWith(content: extracted);
    } catch (_) {
      return fallback;
    }
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

  String _childText(XmlElement parent, String name) {
    final element = parent.getElement(name);
    return (element?.innerText ?? '').trim();
  }

  String _cleanDescription(String raw) {
    if (raw.trim().isEmpty) return '';

    var text =
        raw
            .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'")
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    if (text.startsWith('- ')) {
      text = text.substring(2).trim();
    }

    return text;
  }

  String _extractReadableTextFromHtml(String html) {
    var sanitized = html
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false),
          ' ',
        );

    final paragraphMatches = RegExp(
      r'<p[^>]*>([\s\S]*?)<\/p>',
      caseSensitive: false,
    ).allMatches(sanitized);

    final chunks = <String>[];
    for (final match in paragraphMatches) {
      final rawParagraph = (match.group(1) ?? '').trim();
      if (rawParagraph.isEmpty) continue;

      final paragraph = _cleanDescription(rawParagraph);
      if (paragraph.length < 45) continue;
      chunks.add(paragraph);
      if (chunks.length >= 10) break;
    }

    if (chunks.isNotEmpty) {
      return chunks.join('\n\n');
    }

    final metaDescMatch = RegExp(
      r'<meta[^>]+(?:name|property)="(?:description|og:description)"[^>]+content="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(sanitized);

    if (metaDescMatch != null) {
      return _cleanDescription(metaDescMatch.group(1) ?? '');
    }

    return '';
  }

  String _extractImageUrl(XmlElement item, String rawDescription) {
    final mediaElements = item.findAllElements('media:content');
    final media = mediaElements.isEmpty ? null : mediaElements.first;
    final mediaUrl = (media?.getAttribute('url') ?? '').trim();
    if (mediaUrl.isNotEmpty) return mediaUrl;

    final enclosure = item.getElement('enclosure');
    final enclosureUrl = (enclosure?.getAttribute('url') ?? '').trim();
    if (enclosureUrl.isNotEmpty) return enclosureUrl;

    final doubleQuoteMatch = RegExp(
      r'<img[^>]+src="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(rawDescription);
    if (doubleQuoteMatch != null) {
      return (doubleQuoteMatch.group(1) ?? '').trim();
    }

    final singleQuoteMatch = RegExp(
      r"<img[^>]+src='([^']+)'",
      caseSensitive: false,
    ).firstMatch(rawDescription);
    if (singleQuoteMatch != null) {
      return (singleQuoteMatch.group(1) ?? '').trim();
    }

    return '';
  }

  int _stableId(String input) {
    var hash = 2166136261;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash *= 16777619;
    }
    return hash & 0x7fffffff;
  }

  DateTime? _parsePublishedAt(String value) {
    final input = value.trim();
    if (input.isEmpty) return null;

    try {
      return HttpDate.parse(input).toLocal();
    } catch (_) {
      return DateTime.tryParse(input)?.toLocal();
    }
  }

  String _safeLanguageCode(String input) {
    final code = input.toLowerCase().trim();
    if (_supportedCodes.contains(code)) return code;
    return 'en';
  }
}
