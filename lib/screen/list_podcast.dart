import 'package:flutter/material.dart';
import 'package:pareto_lingo/features/podcast/presentation/models/podcast_route_args.dart';
import 'package:pareto_lingo/features/podcast/presentation/screens/podcast_episode_list_screen.dart';

class ListPodcast extends StatelessWidget {
  final String content;
  final String image;

  const ListPodcast({super.key, required this.content, required this.image});

  @override
  Widget build(BuildContext context) {
    return PodcastEpisodeListScreen(
      args: PodcastListArgs(feedUrl: content, imageUrl: image),
    );
  }
}
