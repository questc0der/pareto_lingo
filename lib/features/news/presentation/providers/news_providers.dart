import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:pareto_lingo/features/news/data/services/wikinews_service.dart';
import 'package:pareto_lingo/features/news/domain/entities/news_article.dart';

final newsHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final wikinewsServiceProvider = Provider<WikinewsService>((ref) {
  return WikinewsService(ref.watch(newsHttpClientProvider));
});

final latestNewsProvider = FutureProvider.family<List<NewsArticle>, String>((
  ref,
  languageCode,
) async {
  return ref
      .watch(wikinewsServiceProvider)
      .fetchLatestNews(languageCode: languageCode);
});

final newsDetailProvider = FutureProvider.family<
  NewsArticle,
  ({String languageCode, NewsArticle article})
>((ref, args) async {
  return ref
      .watch(wikinewsServiceProvider)
      .fetchArticleDetail(
        languageCode: args.languageCode,
        pageId: args.article.pageId,
        fallback: args.article,
      );
});

const _savedNewsKey = 'saved_news_articles';

final savedNewsProvider = StreamProvider<List<NewsArticle>>((ref) async* {
  final box = Hive.box<String>('app_settings');

  List<NewsArticle> parseSaved() {
    final raw = box.get(_savedNewsKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_articleFromMap)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  yield parseSaved();

  await for (final _ in box.watch(key: _savedNewsKey)) {
    yield parseSaved();
  }
});

final isNewsArticleSavedProvider = Provider.family<bool, int>((ref, pageId) {
  final saved = ref
      .watch(savedNewsProvider)
      .maybeWhen(data: (items) => items, orElse: () => const <NewsArticle>[]);
  return saved.any((item) => item.pageId == pageId);
});

Future<void> toggleSavedNewsArticle(WidgetRef ref, NewsArticle article) async {
  final box = Hive.box<String>('app_settings');
  final saved = ref
      .read(savedNewsProvider)
      .maybeWhen(
        data: (items) => List<NewsArticle>.from(items),
        orElse: () => <NewsArticle>[],
      );

  final existingIndex = saved.indexWhere(
    (item) => item.pageId == article.pageId,
  );
  if (existingIndex >= 0) {
    saved.removeAt(existingIndex);
  } else {
    saved.insert(0, article);
  }

  final encoded = json.encode(saved.map(_articleToMap).toList(growable: false));
  await box.put(_savedNewsKey, encoded);
}

Map<String, dynamic> _articleToMap(NewsArticle article) {
  return {
    'pageId': article.pageId,
    'languageCode': article.languageCode,
    'title': article.title,
    'description': article.description,
    'content': article.content,
    'thumbnailUrl': article.thumbnailUrl,
    'articleUrl': article.articleUrl,
  };
}

NewsArticle _articleFromMap(Map<String, dynamic> map) {
  return NewsArticle(
    pageId: (map['pageId'] as num?)?.toInt() ?? 0,
    languageCode: map['languageCode']?.toString() ?? 'en',
    title: map['title']?.toString() ?? '',
    description: map['description']?.toString() ?? '',
    content: map['content']?.toString() ?? '',
    thumbnailUrl: map['thumbnailUrl']?.toString() ?? '',
    articleUrl: map['articleUrl']?.toString() ?? '',
  );
}
