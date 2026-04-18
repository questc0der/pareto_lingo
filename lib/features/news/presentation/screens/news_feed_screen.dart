import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/news/domain/entities/news_article.dart';
import 'package:pareto_lingo/features/news/presentation/providers/news_providers.dart';
import 'package:pareto_lingo/features/news/presentation/screens/news_detail_screen.dart';

// ─── Design tokens (match music_screen & flashcard neo-brut theme) ──────────
const _kBg = Color(0xFFF5F5F0);
const _kAccent = Color(0xFF7DF9FF);
const _kBorderSide = BorderSide(color: Colors.black, width: 2.5);

class NewsFeedScreen extends ConsumerWidget {
  const NewsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = ref
        .watch(userLearningLanguageProvider)
        .maybeWhen(
          data: (code) => code,
          orElse: () => ref.watch(selectedLearningLanguageProvider),
        );
    final language = languageOptionByCode(languageCode);
    final newsAsync = ref.watch(latestNewsProvider(language.code));

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Neo-brut header ─────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: _kAccent,
                border: Border(bottom: _kBorderSide),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.newspaper_rounded,
                        color: _kAccent, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${language.flag} ${language.name} News',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Text(
                        'Read · Translate · Save',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: newsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => _buildError(context, ref, language.code, error),
                data: (articles) {
                  if (articles.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No news articles available.',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: Colors.black,
                    onRefresh: () async {
                      ref.invalidate(latestNewsProvider(language.code));
                      await ref
                          .read(latestNewsProvider(language.code).future);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: articles.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final article = articles[index];
                        return _NewsCard(
                          article: article,
                          languageCode: language.code,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref,
      String languageCode, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 2.5),
                boxShadow: const [
                  BoxShadow(offset: Offset(4, 4), color: Colors.black)
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 40),
                  const SizedBox(height: 10),
                  const Text(
                    'Unable to load news.',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _NeuBrutButton(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    color: _kAccent,
                    onPressed: () =>
                        ref.invalidate(latestNewsProvider(languageCode)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _NewsCard ──────────────────────────────────────────────────────────────

class _NewsCard extends ConsumerWidget {
  final NewsArticle article;
  final String languageCode;

  const _NewsCard({required this.article, required this.languageCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaved = ref.watch(isNewsArticleSavedProvider(article.pageId));
    final snippet = _readableSnippet(article);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NewsDetailScreen(
            languageCode: languageCode,
            article: article,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black, width: 2.5),
          boxShadow: const [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image (full-width) ──────────────────────────────────────
            if (article.thumbnailUrl.isNotEmpty)
              Container(
                height: 170,
                width: double.infinity,
                decoration: const BoxDecoration(
                  border: Border(bottom: _kBorderSide),
                ),
                child: Image.network(
                  article.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _Placeholder(),
                ),
              )
            else
              Container(
                height: 90,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEEEE8),
                  border: Border(bottom: _kBorderSide),
                ),
                child: _Placeholder(),
              ),
            // ── Text content ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source + date pill
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _metaLabel(article),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Bookmark
                      GestureDetector(
                        onTap: () => toggleSavedNewsArticle(ref, article),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSaved ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.black, width: 2),
                          ),
                          child: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 16,
                            color: isSaved ? _kAccent : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Title
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  if (snippet.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      snippet,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black54, height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Read more chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kAccent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Text(
                      'Read full article →',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _metaLabel(NewsArticle article) {
    final source =
        article.source.trim().isEmpty ? 'News' : article.source;
    final date = article.publishedAt;
    if (date == null) return source;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$source · ${date.year}-$m-$d';
  }

  String _readableSnippet(NewsArticle article) {
    final content = article.content.trim();
    final description = article.description.trim();

    if (content.isNotEmpty && !_isUnreadableText(content)) {
      return content;
    }

    if (description.isNotEmpty && !_isUnreadableText(description)) {
      return description;
    }

    return '';
  }

  bool _isUnreadableText(String value) {
    final text = value.trimLeft();
    if (text.startsWith('{') || text.startsWith('[')) return true;

    final lower = text.toLowerCase();
    if (text.contains('{{') ||
        text.contains('}}') ||
        lower.contains('cewbot') ||
        lower.contains('headline item/header') ||
        lower.contains('fetch error')) {
      return true;
    }

    return false;
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEEEEE8),
      alignment: Alignment.center,
      child: const Icon(Icons.article_rounded, size: 40, color: Colors.black26),
    );
  }
}

// ─── _NeuBrutButton ─────────────────────────────────────────────────────────

class _NeuBrutButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _NeuBrutButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black, width: 2.5),
          boxShadow: const [BoxShadow(offset: Offset(3, 3), color: Colors.black)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 7),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
