class NewsArticle {
  final int pageId;
  final String languageCode;
  final String title;
  final String description;
  final String content;
  final String thumbnailUrl;
  final String articleUrl;

  const NewsArticle({
    required this.pageId,
    required this.languageCode,
    required this.title,
    required this.description,
    required this.content,
    required this.thumbnailUrl,
    required this.articleUrl,
  });

  NewsArticle copyWith({
    String? description,
    String? content,
    String? thumbnailUrl,
    String? articleUrl,
  }) {
    return NewsArticle(
      pageId: pageId,
      languageCode: languageCode,
      title: title,
      description: description ?? this.description,
      content: content ?? this.content,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      articleUrl: articleUrl ?? this.articleUrl,
    );
  }
}
