import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pareto_lingo/features/podcast/domain/entities/podcast_category.dart';
import 'package:pareto_lingo/features/podcast/presentation/models/podcast_route_args.dart';
import 'package:pareto_lingo/features/podcast/presentation/providers/podcast_providers.dart';

class PodcastScreen extends ConsumerWidget {
  const PodcastScreen({super.key});

  static const _categories = [
    PodcastCategory.popular,
    PodcastCategory.beginner,
    PodcastCategory.intermediate,
    PodcastCategory.advanced,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      child: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _PodcastSection(category: category);
        },
      ),
    );
  }
}

class _PodcastSection extends ConsumerWidget {
  final PodcastCategory category;

  const _PodcastSection({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final podcastsAsync = ref.watch(podcastCatalogProvider(category));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.title,
            style: const TextStyle(
              fontFamily: 'Circular',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: MediaQuery.of(context).size.height / 3,
            child: podcastsAsync.when(
              data: (podcasts) {
                if (podcasts.isEmpty) {
                  return const Center(child: Text('No podcast found.'));
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: podcasts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = podcasts[index];
                    return SizedBox(
                      width: MediaQuery.of(context).size.width / 1.5,
                      child: GestureDetector(
                        onTap: () {
                          context.go(
                            '/podcast_list',
                            extra: PodcastListArgs(
                              feedUrl: item.feedUrl,
                              imageUrl: item.imageUrl,
                            ),
                          );
                        },
                        child: Image.network(
                          item.imageUrl,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return const ColoredBox(
                              color: Colors.black12,
                              child: Center(
                                child: Icon(Icons.image_not_supported),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
              error: (_, __) {
                return const Center(
                  child: Text(
                    'Unable to load podcasts. Pull to refresh later.',
                  ),
                );
              },
              loading: () {
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
        ],
      ),
    );
  }
}
