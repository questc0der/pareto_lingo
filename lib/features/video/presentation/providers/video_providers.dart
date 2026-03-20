import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/video/data/datasources/youtube_remote_data_source.dart';
import 'package:pareto_lingo/features/video/data/repositories/video_repository_impl.dart';
import 'package:pareto_lingo/features/video/domain/entities/learning_video.dart';
import 'package:pareto_lingo/features/video/domain/entities/video_progress.dart';
import 'package:pareto_lingo/features/video/domain/repositories/video_repository.dart';
import 'package:pareto_lingo/features/video/domain/usecases/get_learning_videos.dart';
import 'package:pareto_lingo/features/video/domain/usecases/get_video_progress.dart';
import 'package:pareto_lingo/features/video/domain/usecases/save_video_progress.dart';

final youtubeApiKeyProvider = Provider<String>((ref) {
  return const String.fromEnvironment('YOUTUBE_API_KEY', defaultValue: '');
});

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final videoProgressBoxProvider = Provider<Box<double>>((ref) {
  return Hive.box<double>('video_progress');
});

final youtubeRemoteDataSourceProvider = Provider<YoutubeRemoteDataSource>((
  ref,
) {
  return const YoutubeRemoteDataSource();
});

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  return VideoRepositoryImpl(
    ref.read(youtubeRemoteDataSourceProvider),
    ref.read(videoProgressBoxProvider),
  );
});

final getLearningVideosProvider = Provider<GetLearningVideos>((ref) {
  return GetLearningVideos(ref.read(videoRepositoryProvider));
});

final getVideoProgressProvider = Provider<GetVideoProgress>((ref) {
  return GetVideoProgress(ref.read(videoRepositoryProvider));
});

final saveVideoProgressProvider = Provider<SaveVideoProgress>((ref) {
  return SaveVideoProgress(ref.read(videoRepositoryProvider));
});

final learningVideosProvider = FutureProvider<List<LearningVideo>>((ref) async {
  final languageCode = await ref.read(userLearningLanguageProvider.future);
  return ref.read(getLearningVideosProvider)(languageCode: languageCode);
});

final selectedVideoIndexProvider = StateProvider<int>((ref) => 0);

final videoProgressProvider = FutureProvider.family<VideoProgress?, String>((
  ref,
  videoId,
) {
  return ref.read(getVideoProgressProvider)(videoId);
});

class VideoProgressController extends StateNotifier<AsyncValue<void>> {
  final SaveVideoProgress _saveVideoProgress;

  VideoProgressController(this._saveVideoProgress)
    : super(const AsyncData(null));

  Future<void> save({required String videoId, required double progress}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _saveVideoProgress(
        VideoProgress(videoId: videoId, progress: progress),
      ),
    );
  }
}

final videoProgressControllerProvider =
    StateNotifierProvider<VideoProgressController, AsyncValue<void>>((ref) {
      return VideoProgressController(ref.read(saveVideoProgressProvider));
    });
