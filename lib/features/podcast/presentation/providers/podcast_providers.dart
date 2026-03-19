import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/podcast/data/datasources/podcast_remote_data_source.dart';
import 'package:pareto_lingo/features/podcast/data/repositories/podcast_repository_impl.dart';
import 'package:pareto_lingo/features/podcast/domain/entities/podcast_category.dart';
import 'package:pareto_lingo/features/podcast/domain/entities/podcast_episode.dart';
import 'package:pareto_lingo/features/podcast/domain/entities/podcast_item.dart';
import 'package:pareto_lingo/features/podcast/domain/repositories/podcast_repository.dart';
import 'package:pareto_lingo/features/podcast/domain/usecases/get_podcast_episodes.dart';
import 'package:pareto_lingo/features/podcast/domain/usecases/get_podcasts_by_category.dart';
import 'package:podcast_search/podcast_search.dart';

final podcastSearchProvider = Provider<Search>((ref) {
  return Search();
});

final podcastRemoteDataSourceProvider = Provider<PodcastRemoteDataSource>((
  ref,
) {
  return PodcastRemoteDataSource(ref.read(podcastSearchProvider));
});

final podcastRepositoryProvider = Provider<PodcastRepository>((ref) {
  return PodcastRepositoryImpl(ref.read(podcastRemoteDataSourceProvider));
});

final getPodcastsByCategoryProvider = Provider<GetPodcastsByCategory>((ref) {
  return GetPodcastsByCategory(ref.read(podcastRepositoryProvider));
});

final getPodcastEpisodesProvider = Provider<GetPodcastEpisodes>((ref) {
  return GetPodcastEpisodes(ref.read(podcastRepositoryProvider));
});

final podcastCatalogProvider = FutureProvider.family<
  List<PodcastItem>,
  PodcastCategory
>((ref, category) async {
  final userLanguageCode = await ref.read(userLearningLanguageProvider.future);
  return ref.read(getPodcastsByCategoryProvider)(
    category,
    languageCode: userLanguageCode,
  );
});

final podcastEpisodesProvider =
    FutureProvider.family<List<PodcastEpisode>, String>((ref, feedUrl) {
      return ref.read(getPodcastEpisodesProvider)(feedUrl);
    });

final podcastAudioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});

class PodcastPlaybackState {
  final int? currentPlayingIndex;
  final String? currentPlayingUrl;
  final bool isLoading;

  const PodcastPlaybackState({
    this.currentPlayingIndex,
    this.currentPlayingUrl,
    this.isLoading = false,
  });

  PodcastPlaybackState copyWith({
    int? currentPlayingIndex,
    String? currentPlayingUrl,
    bool? isLoading,
    bool clearCurrentPlayingIndex = false,
    bool clearCurrentPlayingUrl = false,
  }) {
    return PodcastPlaybackState(
      currentPlayingIndex:
          clearCurrentPlayingIndex
              ? null
              : (currentPlayingIndex ?? this.currentPlayingIndex),
      currentPlayingUrl:
          clearCurrentPlayingUrl
              ? null
              : (currentPlayingUrl ?? this.currentPlayingUrl),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PodcastPlaybackController extends StateNotifier<PodcastPlaybackState> {
  final AudioPlayer _audioPlayer;

  PodcastPlaybackController(this._audioPlayer)
    : super(const PodcastPlaybackState());

  Future<String?> playEpisode({
    required String audioUrl,
    required int index,
  }) async {
    try {
      final previousUrl = state.currentPlayingUrl;
      final requiresSourceLoad =
          previousUrl != audioUrl || _audioPlayer.audioSource == null;

      state = state.copyWith(
        isLoading: requiresSourceLoad,
        currentPlayingIndex: index,
        currentPlayingUrl: audioUrl,
      );

      if (previousUrl != audioUrl) {
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(audioUrl);
      } else {
        if (_audioPlayer.audioSource == null) {
          await _audioPlayer.setUrl(audioUrl);
        }
      }

      await _audioPlayer.play();
      state = state.copyWith(isLoading: false);
      return null;
    } catch (_) {
      state = state.copyWith(isLoading: false);
      return 'Unable to play this episode right now.';
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    state = state.copyWith(isLoading: false);
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    state = state.copyWith(
      clearCurrentPlayingIndex: true,
      clearCurrentPlayingUrl: true,
    );
  }
}

final podcastPlaybackControllerProvider =
    StateNotifierProvider<PodcastPlaybackController, PodcastPlaybackState>((
      ref,
    ) {
      return PodcastPlaybackController(ref.read(podcastAudioPlayerProvider));
    });
