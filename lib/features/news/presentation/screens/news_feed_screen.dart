import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/news/presentation/providers/news_providers.dart';
import 'package:pareto_lingo/features/news/presentation/screens/news_detail_screen.dart';

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
      appBar: AppBar(
        title: Text('${language.flag} ${language.name} News'),
        centerTitle: false,
      ),
      body: newsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unable to load news right now.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed:
                          () =>
                              ref.invalidate(latestNewsProvider(language.code)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        data: (articles) {
          if (articles.isEmpty) {
            return const Center(child: Text('No news articles available.'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(latestNewsProvider(language.code));
              await ref.read(latestNewsProvider(language.code).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              itemCount: articles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final article = articles[index];
                final isSaved = ref.watch(
                  isNewsArticleSavedProvider(article.pageId),
                );
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => NewsDetailScreen(
                              languageCode: language.code,
                              article: article,
                            ),
                      ),
                    );
                  },
                  child: Ink(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 120,
                            height: 90,
                            child:
                                article.thumbnailUrl.isNotEmpty
                                    ? Image.network(
                                      article.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) =>
                                              const _NewsImagePlaceholder(),
                                    )
                                    : const _NewsImagePlaceholder(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                article.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  tooltip:
                                      isSaved
                                          ? 'Remove from saved'
                                          : 'Save article',
                                  onPressed: () async {
                                    await toggleSavedNewsArticle(ref, article);
                                  },
                                  icon: Icon(
                                    isSaved
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                article.description.isEmpty
                                    ? 'Tap to open full article.'
                                    : article.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NewsImagePlaceholder extends StatelessWidget {
  const _NewsImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.article_rounded),
    );
  }
}
