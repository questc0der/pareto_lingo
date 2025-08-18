import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:podcast_search/podcast_search.dart';

class ListPodcast extends StatefulWidget {
  final String content;
  const ListPodcast({super.key, required this.content});

  @override
  State<ListPodcast> createState() => _Lists();
}

class _Lists extends State<ListPodcast> {
  final player = AudioPlayer();
  bool isPlaying = false;
  int? currentPlayingIndex;
  String? currentPlayingUrl;

  @override
  void initState() {
    super.initState();
    _fetchEpisodes();
  }

  Future<List<Map<String, String>>> _fetchEpisodes() async {
    var feed = await Feed.loadFeed(url: widget.content);
    return feed.episodes.map((e) {
      return {
        'title': e.title,
        'content': e.contentUrl ?? "no Content",
        'image': e.imageUrl ?? "No Url",
      };
    }).toList();
  }

  Future<void> _setAudio({required String url}) async {
    if (currentPlayingUrl != url) {
      await player.stop();
      await player.setUrl(url);
      currentPlayingUrl = url;
    }
    player.play();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, String>>>(
        future: _fetchEpisodes(),
        builder: (context, snapshot) {
          if (snapshot.hasData &&
              snapshot.connectionState == ConnectionState.done) {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                return _buildPlayerCard(
                  snapshot.data![index]['content']!,
                  snapshot.data![index]['title']!,
                  index,
                );
              },
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _buildPlayerCard(String audio, String title, int index) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 3,
        // height: MediaQuery.of(context).size.height / 1.5,
        child: Row(
          children: [
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final processingState = playerState?.processingState;
                final playing = playerState?.playing ?? false;

                if (processingState == ProcessingState.loading ||
                    processingState == ProcessingState.buffering) {
                  return Container(
                    margin: EdgeInsets.all(8.0),
                    width: 64.0,
                    height: 64.0,
                    child: const CircularProgressIndicator(),
                  );
                }

                if (index == currentPlayingIndex && playing) {
                  return IconButton(
                    icon: const Icon(Icons.pause),
                    iconSize: 64.0,
                    onPressed: () {
                      player.pause();
                      setState(() {}); // refresh UI
                    },
                  );
                }

                return IconButton(
                  icon: const Icon(Icons.play_arrow),
                  iconSize: 64.0,
                  onPressed: () async {
                    await _setAudio(url: audio);
                    setState(() {
                      currentPlayingIndex = index;
                    });
                  },
                );
              },
            ),
            Expanded(child: Text(title)),
          ],
        ),
      ),
    );
  }
}
