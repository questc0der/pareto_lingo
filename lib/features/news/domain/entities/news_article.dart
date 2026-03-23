class NewsArticle {
  final int pageId;
  final String languageCode;
  final String title;
  final String description;
  final String content;
  final String thumbnailUrl;
  final String articleUrl;
  final DateTime? publishedAt;
  final String source;

  const NewsArticle({
    required this.pageId,
    required this.languageCode,
    required this.title,
    required this.description,
    required this.content,
    required this.thumbnailUrl,
    required this.articleUrl,
    this.publishedAt,
    this.source = 'News',
  });

  NewsArticle copyWith({
    String? description,
    String? content,
    String? thumbnailUrl,
    String? articleUrl,
    DateTime? publishedAt,
    String? source,
  }) {
    return NewsArticle(
      pageId: pageId,
      languageCode: languageCode,
      title: title,
      description: description ?? this.description,
      content: content ?? this.content,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      articleUrl: articleUrl ?? this.articleUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      source: source ?? this.source,
    );
  }
}
