import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VideoItem {
  final String videoId;
  final String title;
  final String thumbnailUrl;

  VideoItem({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] ?? {};
    final thumbnails = snippet['thumbnails'] ?? {};
    return VideoItem(
      videoId: json['id']['videoId'] ?? '',
      title: snippet['title'] ?? '',
      thumbnailUrl: thumbnails['high']?['url'] ?? '',
    );
  }
}

class ShortVideoFeed extends StatefulWidget {
  const ShortVideoFeed({Key? key}) : super(key: key);

  @override
  _ShortVideoFeedState createState() => _ShortVideoFeedState();
}

class _ShortVideoFeedState extends State<ShortVideoFeed> {
  final String apiKey = 'AIzaSyDjBSUPKjC3e8-NDe4L9CrEoQovVIZC1fo';
  late PageController _pageController;
  late List<VideoItem> _videos = [];
  late List<YoutubePlayerController> _controllers = [];
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchShortVideos();
  }

  Future<void> _fetchShortVideos() async {
    final String url =
        'https://www.googleapis.com/youtube/v3/search?'
        'part=snippet&type=video&videoDuration=short&'
        'relevanceLanguage=fr&q="parler+français"+OR+"dialogue+français"&'
        'maxResults=100&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _videos =
            (data['items'] as List)
                .map((item) => VideoItem.fromJson(item))
                .where((v) => v.videoId.isNotEmpty)
                .toList();

        _controllers =
            _videos
                .map(
                  (video) => YoutubePlayerController(
                    initialVideoId: video.videoId,
                    flags: const YoutubePlayerFlags(
                      autoPlay: true,
                      mute: false,
                      enableCaption: true,
                    ),
                  ),
                )
                .toList();
      });

      if (_controllers.isNotEmpty) {
        _controllers[0].play();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildVideoPlayer(int index) {
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
          bottom: 60,
          left: 20,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            child: Text(
              _videos[index].title,
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
  }

  @override
  Widget build(BuildContext context) {
    if (_videos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _videos.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
          for (int i = 0; i < _controllers.length; i++) {
            if (i == index) {
              _controllers[i].play();
            } else {
              _controllers[i].pause();
            }
          }
        },
        itemBuilder: (context, index) {
          return GestureDetector(
            onDoubleTap: () {},
            child: _buildVideoPlayer(index),
          );
        },
      ),
    );
  }
}
