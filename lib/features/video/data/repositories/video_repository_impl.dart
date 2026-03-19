import 'package:hive/hive.dart';
import 'package:pareto_lingo/features/video/data/datasources/youtube_remote_data_source.dart';
import 'package:pareto_lingo/features/video/domain/entities/learning_video.dart';
import 'package:pareto_lingo/features/video/domain/entities/video_progress.dart';
import 'package:pareto_lingo/features/video/domain/repositories/video_repository.dart';

class VideoRepositoryImpl implements VideoRepository {
  final YoutubeRemoteDataSource _remoteDataSource;
  final Box<double> _progressBox;

  const VideoRepositoryImpl(this._remoteDataSource, this._progressBox);

  @override
  Future<List<LearningVideo>> getLearningVideos({
    required String languageCode,
  }) {
    return _remoteDataSource.fetchLearningVideos(languageCode: languageCode);
  }

  @override
  Future<VideoProgress?> getProgress(String videoId) async {
    final progress = _progressBox.get(videoId);
    if (progress == null) return null;
    return VideoProgress(videoId: videoId, progress: progress);
  }

  @override
  Future<void> saveProgress(VideoProgress progress) {
    return _progressBox.put(progress.videoId, progress.progress);
  }
}
