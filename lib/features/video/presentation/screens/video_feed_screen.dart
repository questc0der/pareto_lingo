import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pareto_lingo/features/video/presentation/providers/video_providers.dart';
import 'package:video_player/video_player.dart';

class VideoFeedScreen extends ConsumerStatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  ConsumerState<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends ConsumerState<VideoFeedScreen> {
  late final PageController _pageController;
  VideoPlayerController? _controller;
  String? _activeVideoUrl;
  int _activeIndex = 0;
  bool _isMuted = false;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _activateVideo(String videoUrl) async {
    if (_activeVideoUrl == videoUrl && _controller != null) {
      if (!_controller!.value.isPlaying) {
        await _controller!.play();
      }
      return;
    }

    final previousController = _controller;
    try {
      final nextController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );

      await nextController.initialize();
      await nextController.setLooping(true);
      await nextController.setVolume(_isMuted ? 0 : 1);
      await nextController.play();

      if (!mounted) {
        await nextController.dispose();
        return;
      }

      setState(() {
        _controller = nextController;
        _activeVideoUrl = videoUrl;
        _videoFailed = false;
      });

      await previousController?.dispose();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videoFailed = true;
        _activeVideoUrl = videoUrl;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleMute() async {
    if (_controller == null) {
      return;
    }

    final nextMuted = !_isMuted;
    setState(() {
      _isMuted = nextMuted;
    });

    await _controller!.setVolume(nextMuted ? 0 : 1);
  }

  Widget _buildThumbnailBackdrop(String thumbnailUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          thumbnailUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return const ColoredBox(color: Colors.black26);
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black26, Colors.black54],
            ),
          ),
        ),
        const Center(
          child: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.black54,
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ],
    );
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

        if (_activeIndex >= videos.length) {
          _activeIndex = 0;
        }

        final activeVideo = videos[_activeIndex];
        if (_activeVideoUrl != activeVideo.videoUrl || _controller == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _activateVideo(activeVideo.videoUrl);
          });
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            onPageChanged: (index) async {
              final previousIndex = _activeIndex;
              setState(() {
                _activeIndex = index;
              });

              ref.read(selectedVideoIndexProvider.notifier).state = index;

              await _activateVideo(videos[index].videoUrl);

              final previousVideo = videos[previousIndex];
              await ref
                  .read(videoProgressControllerProvider.notifier)
                  .save(videoId: previousVideo.id, progress: 1.0);
            },
            itemBuilder: (context, index) {
              final video = videos[index];
              final isActive =
                  _controller != null &&
                  index == _activeIndex &&
                  _activeVideoUrl == video.videoUrl;

              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlayPause,
                      child:
                          isActive &&
                                  !_videoFailed &&
                                  _controller != null &&
                                  _controller!.value.isInitialized
                              ? FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _controller!.value.size.width,
                                  height: _controller!.value.size.height,
                                  child: VideoPlayer(_controller!),
                                ),
                              )
                              : _buildThumbnailBackdrop(video.thumbnailUrl),
                    ),
                  ),
                  if (isActive && _videoFailed)
                    Positioned.fill(
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Could not play this video',
                                  style: TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 8),
                                FilledButton.tonal(
                                  onPressed:
                                      () => _activateVideo(video.videoUrl),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Positioned(
                    top: 56,
                    left: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Text(
                          'Fun Shorts',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
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
                  Positioned(
                    right: 16,
                    bottom: 120,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'play_$index',
                          backgroundColor: Colors.black54,
                          onPressed: _togglePlayPause,
                          child: Icon(
                            (_controller?.value.isPlaying ?? false) && isActive
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FloatingActionButton.small(
                          heroTag: 'mute_$index',
                          backgroundColor: Colors.black54,
                          onPressed: _toggleMute,
                          child: Icon(
                            _isMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Text(
                              'Swipe ↓',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
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
