import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pareto_lingo/features/podcast/domain/entities/podcast_episode.dart';
import 'package:pareto_lingo/features/podcast/presentation/models/podcast_route_args.dart';
import 'package:pareto_lingo/features/podcast/presentation/providers/podcast_providers.dart';

class PodcastEpisodeListScreen extends ConsumerWidget {
  final PodcastListArgs args;

  const PodcastEpisodeListScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodesAsync = ref.watch(podcastEpisodesProvider(args.feedUrl));

    return Scaffold(
      appBar: AppBar(title: const Text('Podcast Episodes')),
      body: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(18),
            ),
            child: Image.network(
              args.imageUrl,
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.28,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return SizedBox(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.28,
                  child: const ColoredBox(
                    color: Colors.black12,
                    child: Center(child: Icon(Icons.image_not_supported)),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: episodesAsync.when(
              data: (episodes) {
                if (episodes.isEmpty) {
                  return const Center(child: Text('No episodes available.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: episodes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _EpisodeTile(episode: episodes[index], index: index);
                  },
                );
              },
              error: (_, __) {
                return const Center(
                  child: Text('Unable to load episodes. Please try again.'),
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

class _EpisodeTile extends ConsumerWidget {
  final PodcastEpisode episode;
  final int index;

  const _EpisodeTile({required this.episode, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(podcastAudioPlayerProvider);
    final playbackState = ref.watch(podcastPlaybackControllerProvider);
    final playbackController = ref.read(
      podcastPlaybackControllerProvider.notifier,
    );

    final isCurrent = playbackState.currentPlayingIndex == index;

    return Container(
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFE8F7FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? const Color(0xFF7DF9FF) : const Color(0xFFD9D9D9),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            if ((episode.imageUrl).isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  episode.imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => const SizedBox(
                        width: 56,
                        height: 56,
                        child: ColoredBox(color: Colors.black12),
                      ),
                ),
              )
            else
              const SizedBox(
                width: 56,
                height: 56,
                child: ColoredBox(color: Colors.black12),
              ),
            const SizedBox(width: 10),
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final isPlaying = playerState?.playing ?? false;
                final isCurrentLoading = isCurrent && playbackState.isLoading;

                if (isCurrentLoading) {
                  return Container(
                    margin: const EdgeInsets.all(8),
                    width: 36,
                    height: 36,
                    child: const CircularProgressIndicator(strokeWidth: 3),
                  );
                }

                if (isCurrent && isPlaying) {
                  return IconButton(
                    icon: const Icon(Icons.pause_circle_filled),
                    iconSize: 36,
                    onPressed: playbackController.pause,
                  );
                }

                return IconButton(
                  icon: const Icon(Icons.play_circle_fill),
                  iconSize: 36,
                  onPressed: () async {
                    final message = await playbackController.playEpisode(
                      audioUrl: episode.audioUrl,
                      index: index,
                    );

                    if (message != null && context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(message)));
                    }
                  },
                );
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    episode.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCurrent ? 'Now playing' : 'Tap to play',
                    style: TextStyle(
                      fontSize: 12,
                      color: isCurrent ? Colors.teal : Colors.black54,
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
}
