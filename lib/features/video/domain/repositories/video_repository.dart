import 'package:pareto_lingo/features/video/domain/entities/learning_video.dart';
import 'package:pareto_lingo/features/video/domain/entities/video_progress.dart';

abstract class VideoRepository {
  Future<List<LearningVideo>> getLearningVideos({required String languageCode});

  Future<VideoProgress?> getProgress(String videoId);

  Future<void> saveProgress(VideoProgress progress);
}
