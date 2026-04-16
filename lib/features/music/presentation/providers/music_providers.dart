import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pareto_lingo/features/music/data/services/music_service.dart';
import 'package:pareto_lingo/features/music/domain/entities/music_track.dart';

final musicHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final musicServiceProvider = Provider<MusicService>((ref) {
  return MusicService(ref.read(musicHttpClientProvider));
});

final musicSearchProvider = FutureProvider.family<
  List<MusicTrack>,
  ({String languageCode, String query})
>((ref, args) async {
  try {
    return await ref
        .read(musicServiceProvider)
        .searchSongs(
          query: args.query,
          languageCode: args.languageCode,
          limit: 20,
        );
  } catch (_) {
    return const [];
  }
});
