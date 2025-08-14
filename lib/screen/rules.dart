import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:neubrutalism_ui/neubrutalism_ui.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class GrammarRules extends StatefulWidget {
  const GrammarRules({super.key});

  @override
  State<GrammarRules> createState() => _PlaylistState();
}

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
    final resourceId = snippet['resourceId'] ?? {};
    return VideoItem(
      videoId: resourceId['videoId'] ?? '',
      title: snippet['title'] ?? '',
      thumbnailUrl: snippet['thumbnails']?['medium']?['url'] ?? '',
    );
  }
}

class _PlaylistState extends State<GrammarRules> {
  final String apiKey = 'AIzaSyDjBSUPKjC3e8-NDe4L9CrEoQovVIZC1fo';
  final String playlistId = 'PLV1-QgpUU7N2TVWS6gEVMqEfAFjAl-DV6';

  Future<List<VideoItem>> fetchPlaylistVideos() async {
    final String url =
        'https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=$playlistId&maxResults=50&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final videos = data['items'] as List<dynamic>;
      return videos
          .map((item) => VideoItem.fromJson(item))
          .where((v) => v.videoId.isNotEmpty)
          .toList();
    } else {
      throw Exception('Failed to load videos: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Playlist Videos")),
      body: FutureBuilder<List<VideoItem>>(
        future: fetchPlaylistVideos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No videos found.'));
          }

          final videos = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView.builder(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return GestureDetector(
                  onTap: () {
                    if (video.videoId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => VideoPlayerPage(
                                videoId: video.videoId,
                                allVideos: videos,
                              ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid video id')),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: NeuCard(
                      cardColor: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // fixed height so layout is stable
                          SizedBox(
                            height: 200,
                            child:
                                video.thumbnailUrl.isNotEmpty
                                    ? Image.network(
                                      video.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder:
                                          (ctx, err, st) => const Center(
                                            child: Icon(Icons.broken_image),
                                          ),
                                    )
                                    : const Center(
                                      child: Icon(Icons.broken_image),
                                    ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
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
            ),
          );
        },
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String videoId;
  final List<VideoItem> allVideos;
  const VideoPlayerPage({
    super.key,
    required this.videoId,
    required this.allVideos,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late YoutubePlayerController _controller;
  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(autoPlay: true, enableCaption: true),
    );
  }

  @override
  void dispose() {
    // _controller.clo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final otherVideos =
        widget.allVideos.where((v) => v.videoId != widget.videoId).toList();
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
      ),
      builder: (context, player) {
        return Scaffold(
          appBar: AppBar(title: const Text('Video')),
          body: Column(
            children: [
              player,
              Expanded(
                child: ListView.builder(
                  itemCount: otherVideos.length,
                  itemBuilder: (context, index) {
                    final video = otherVideos[index];
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: NeuCard(
                        cardColor: Colors.white,
                        child: ListTile(
                          leading: Image.network(video.thumbnailUrl),
                          title: Text(
                            video.title,
                            style: TextStyle(fontFamily: 'Circular'),
                          ),
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => VideoPlayerPage(
                                      videoId: video.videoId,
                                      allVideos: widget.allVideos,
                                    ),
                              ),
                            );
                          },
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
