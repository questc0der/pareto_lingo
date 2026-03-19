import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pareto_lingo/features/video/presentation/providers/video_providers.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoFeedScreen extends ConsumerStatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  ConsumerState<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends ConsumerState<VideoFeedScreen> {
  late final PageController _pageController;
  final List<YoutubePlayerController> _controllers = [];
  int _controllerCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllers(List<String> videoIds) {
    if (_controllerCount == videoIds.length) return;

    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers.clear();

    _controllers.addAll(
      videoIds.map(
        (id) => YoutubePlayerController(
          initialVideoId: id,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
            enableCaption: true,
          ),
        ),
      ),
    );

    _controllerCount = videoIds.length;
    if (_controllers.isNotEmpty) {
      _controllers.first.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(learningVideosProvider);

    return videosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (videos) {
        if (videos.isEmpty) {
          return const Center(child: Text('No learning videos available.'));
        }

        _syncControllers(videos.map((v) => v.id).toList(growable: false));

        return Scaffold(
          body: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            onPageChanged: (index) async {
              final previousIndex = ref.read(selectedVideoIndexProvider);
              ref.read(selectedVideoIndexProvider.notifier).state = index;

              for (var i = 0; i < _controllers.length; i++) {
                if (i == index) {
                  _controllers[i].play();
                } else {
                  _controllers[i].pause();
                }
              }

              final previousVideo = videos[previousIndex];
              await ref
                  .read(videoProgressControllerProvider.notifier)
                  .save(videoId: previousVideo.id, progress: 1.0);
            },
            itemBuilder: (context, index) {
              final video = videos[index];

              return Stack(
                children: [
                  Positioned.fill(
                    child: YoutubePlayer(
                      controller: _controllers[index],
                      aspectRatio: 9 / 16,
                      showVideoProgressIndicator: true,
                      progressIndicatorColor: Colors.blue,
                      progressColors: const ProgressBarColors(
                        playedColor: Colors.red,
                        handleColor: Colors.redAccent,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 90,
                    left: 20,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: Text(
                        video.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: Colors.black,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}