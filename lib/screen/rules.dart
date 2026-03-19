import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neubrutalism_ui/neubrutalism_ui.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/video/presentation/providers/video_providers.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class GrammarRules extends ConsumerWidget {
  const GrammarRules({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grammarVideosAsync = ref.watch(grammarVideosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Grammar Rules')),
      body: grammarVideosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (_, __) => const Center(
              child: Text('Unable to load grammar videos right now.'),
            ),
        data: (videos) {
          if (videos.isEmpty) {
            return const Center(child: Text('No grammar videos found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => GrammarVideoPlayerPage(
                            initialIndex: index,
                            allVideos: videos,
                          ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: NeuCard(
                    cardColor: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 200,
                          child:
                              video.thumbnailUrl.isNotEmpty
                                  ? Image.network(
                                    video.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder:
                                        (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image),
                                        ),
                                  )
                                  : const Center(
                                    child: Icon(Icons.broken_image),
                                  ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Circular',
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class GrammarVideoItem {
  final String videoId;
  final String title;
  final String thumbnailUrl;

  const GrammarVideoItem({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
  });
}

final grammarVideosProvider = FutureProvider<List<GrammarVideoItem>>((
  ref,
) async {
  final apiKey = ref.read(youtubeApiKeyProvider);
  if (apiKey.isEmpty) {
    throw Exception('Missing YOUTUBE_API_KEY.');
  }

  final languageCode = await ref.read(userLearningLanguageProvider.future);
  final selectedLanguage = languageOptionByCode(languageCode);
  final query = Uri.encodeQueryComponent(
    '${selectedLanguage.name} grammar rules for beginners',
  );

  final url = Uri.parse(
    'https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&'
    'relevanceLanguage=${selectedLanguage.code}&maxResults=30&q=$query&key=$apiKey',
  );

  final response = await ref.read(httpClientProvider).get(url);
  if (response.statusCode != 200) {
    throw Exception('Failed to fetch grammar videos.');
  }

  final data = json.decode(response.body) as Map<String, dynamic>;
  final items = data['items'] as List<dynamic>? ?? const [];

  return items
      .map((item) => item as Map<String, dynamic>)
      .map((item) {
        final id =
            (item['id'] as Map<String, dynamic>? ?? {})['videoId']
                ?.toString() ??
            '';
        final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
        final title = snippet['title']?.toString() ?? '';
        final thumb =
            ((snippet['thumbnails'] as Map<String, dynamic>? ?? {})['high']
                        as Map<String, dynamic>? ??
                    {})['url']
                ?.toString() ??
            '';

        return GrammarVideoItem(videoId: id, title: title, thumbnailUrl: thumb);
      })
      .where((item) => item.videoId.isNotEmpty)
      .toList(growable: false);
});

class GrammarVideoPlayerPage extends StatefulWidget {
  final int initialIndex;
  final List<GrammarVideoItem> allVideos;

  const GrammarVideoPlayerPage({
    super.key,
    required this.initialIndex,
    required this.allVideos,
  });

  @override
  State<GrammarVideoPlayerPage> createState() => _GrammarVideoPlayerPageState();
}

class _GrammarVideoPlayerPageState extends State<GrammarVideoPlayerPage> {
  late YoutubePlayerController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = YoutubePlayerController(
      initialVideoId: widget.allVideos[_currentIndex].videoId,
      flags: const YoutubePlayerFlags(autoPlay: true, enableCaption: true),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _playAt(int index) {
    setState(() {
      _currentIndex = index;
      _controller.load(widget.allVideos[index].videoId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
      ),
      builder: (context, player) {
        return Scaffold(
          appBar: AppBar(title: const Text('Grammar Video')),
          body: Column(
            children: [
              player,
              Expanded(
                child: ListView.builder(
                  itemCount: widget.allVideos.length,
                  itemBuilder: (context, index) {
                    final video = widget.allVideos[index];
                    final isCurrent = index == _currentIndex;

                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: NeuCard(
                        cardColor:
                            isCurrent ? const Color(0xFFE8F7FF) : Colors.white,
                        child: ListTile(
                          leading:
                              video.thumbnailUrl.isNotEmpty
                                  ? Image.network(video.thumbnailUrl)
                                  : const Icon(Icons.play_circle),
                          title: Text(
                            video.title,
                            style: const TextStyle(fontFamily: 'Circular'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _playAt(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
