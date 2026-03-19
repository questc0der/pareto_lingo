import 'package:pareto_lingo/features/video/domain/entities/video_progress.dart';
import 'package:pareto_lingo/features/video/domain/repositories/video_repository.dart';

class GetVideoProgress {
  final VideoRepository _repository;

  const GetVideoProgress(this._repository);

  Future<VideoProgress?> call(String videoId) {
    return _repository.getProgress(videoId);
  }
}
