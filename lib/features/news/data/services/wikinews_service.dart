import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/news/domain/entities/news_article.dart';
import 'package:xml/xml.dart';

class WikinewsService {
  final http.Client _client;

  WikinewsService(this._client);

  static const _supportedCodes = {'fr', 'zh', 'en'};
  static const _newsLocaleByLanguage = {
    'fr': ('FR', 'fr'),
    'zh': ('CN', 'zh'),
    'en': ('US', 'en'),
  };

  Future<List<NewsArticle>> fetchLatestNews({
    required String languageCode,
    int limit = 25,
  }) async {
    final safeCode = _safeLanguageCode(languageCode);

    // For Mandarin use Wikinews zh RSS — Google News blocks zh CEID
    if (safeCode == 'zh') {
      final articles = await _fetchWikinewsZh(limit: limit);
      if (articles.isNotEmpty) return articles;
    }

    try {
      final google = await _fetchGoogleNews(safeCode: safeCode, limit: limit);
      if (google.isNotEmpty) return google;
    } catch (_) {
      // Keep UI usable on transient feed/network failures.
    }

    return const [];
  }

  Future<List<NewsArticle>> _fetchGoogleNews({
    required String safeCode,
    required int limit,
  }) async {
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
      return const [];
    }

    return _parseRssItems(
      response.body,
      safeCode: safeCode,
      defaultSource: 'Google News',
      limit: limit,
    );
  }

  Future<List<NewsArticle>> _fetchWikinewsZh({required int limit}) async {
    // zh.wikinews.org Atom feed
    final uri = Uri.parse(
      'https://zh.wikinews.org/w/index.php?title=Special:NewPages&feed=rss&namespace=0',
    );
    try {
      final response = await _client
          .get(
            uri,
            headers: const {
              'User-Agent': 'pareto-lingo-news/1.0',
              'Accept': 'application/rss+xml, application/xml;q=0.9, */*;q=0.8',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      return _parseRssItems(
        response.body,
        safeCode: 'zh',
        defaultSource: 'Wikinews 中文',
        limit: limit,
      );
    } catch (_) {
      return const [];
    }
  }

  List<NewsArticle> _parseRssItems(
    String body, {
    required String safeCode,
    required String defaultSource,
    required int limit,
  }) {
    final xml = XmlDocument.parse(body);
    final items = xml.findAllElements('item');

    final articles = <NewsArticle>[];
    for (final item in items) {
      final title = _cleanHeadline(_childText(item, 'title'));
      final link = _childText(item, 'link');
      final pubDateRaw = _childText(item, 'pubDate');
      final source = _childText(item, 'source');
      final rawDescription = _childText(item, 'description');
      final description = _cleanDescription(rawDescription);
      final image = _extractImageUrl(item, rawDescription);

      if (title.isEmpty || link.isEmpty) continue;

      articles.add(
        NewsArticle(
          pageId: _stableId(link),
          languageCode: safeCode,
          title: title,
          description: description,
          content: description,
          thumbnailUrl: image,
          articleUrl: link,
          publishedAt: _parsePublishedAt(pubDateRaw),
          source: source.isEmpty ? defaultSource : source,
        ),
      );
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

    // Drop MediaWiki template blocks like {{HI|...}} that can leak from bot pages.
    text = _stripWikiTemplates(text);

    if (text.startsWith('- ')) {
      text = text.substring(2).trim();
    }

    if (_looksLikeJsonPayload(text)) {
      final extracted = _extractTextFromJsonPayload(text);
      if (extracted.isNotEmpty) {
        text = extracted;
      }
    }

    if (_looksLikeTemplateNoise(text)) {
      return '';
    }

    return text;
  }

  String _cleanHeadline(String raw) {
    final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return '';
    if (_looksLikeTemplateNoise(text)) return '';

    final lower = text.toLowerCase();
    if (lower.contains('fetch error') || lower.contains('cewbot')) {
      return '';
    }

    return text;
  }

  String _stripWikiTemplates(String input) {
    var text = input;

    // Remove simple {{...}} blocks iteratively.
    for (var i = 0; i < 6; i++) {
      final next = text.replaceAll(RegExp(r'\{\{[^{}]*\}\}'), ' ');
      if (next == text) break;
      text = next;
    }

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _looksLikeTemplateNoise(String input) {
    final text = input.trim();
    if (text.isEmpty) return false;

    if (text.contains('{{') || text.contains('}}')) {
      return true;
    }

    final lower = text.toLowerCase();
    if (lower.contains('cewbot') ||
        lower.contains('{{headline') ||
        lower.contains('{{hi|') ||
        lower.contains('{{date|')) {
      return true;
    }

    final templateMarkers = RegExp(r'\{\{').allMatches(text).length;
    return templateMarkers >= 1;
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
      if (chunks.length >= 20) break;
    }

    if (chunks.isNotEmpty) {
      final paragraphText = chunks.join('\n\n');
      if (_looksLikeJsonPayload(paragraphText)) {
        final extracted = _extractTextFromJsonPayload(paragraphText);
        if (extracted.isNotEmpty) {
          return extracted;
        }
      }
      return paragraphText;
    }

    final metaDescMatch = RegExp(
      r'<meta[^>]+(?:name|property)="(?:description|og:description)"[^>]+content="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(sanitized);

    if (metaDescMatch != null) {
      return _cleanDescription(metaDescMatch.group(1) ?? '');
    }

    if (_looksLikeJsonPayload(sanitized)) {
      final extracted = _extractTextFromJsonPayload(sanitized);
      if (extracted.isNotEmpty) {
        return extracted;
      }
    }

    return '';
  }

  bool _looksLikeJsonPayload(String input) {
    final text = input.trimLeft();
    return text.startsWith('{') || text.startsWith('[');
  }

  String _extractTextFromJsonPayload(String raw) {
    try {
      final decoded = json.decode(raw);
      final candidates = <String>[];

      void collect(dynamic node) {
        if (node is Map<String, dynamic>) {
          const preferredKeys = [
            'title',
            'headline',
            'description',
            'summary',
            'content',
            'text',
            'snippet',
            'abstract',
          ];

          for (final key in preferredKeys) {
            final value = node[key];
            if (value is String && value.trim().isNotEmpty) {
              candidates.add(value.trim());
            }
          }

          for (final value in node.values) {
            if (candidates.length >= 8) break;
            collect(value);
          }
          return;
        }

        if (node is List) {
          for (final value in node) {
            if (candidates.length >= 8) break;
            collect(value);
          }
        }
      }

      collect(decoded);
      if (candidates.isEmpty) return '';

      return candidates.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (_) {
      return '';
    }
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
    final code = normalizeLearningLanguageCode(input);
    if (_supportedCodes.contains(code)) return code;
    return 'en';
  }
}
