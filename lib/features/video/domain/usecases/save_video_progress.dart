import 'package:pareto_lingo/features/video/domain/entities/video_progress.dart';
import 'package:pareto_lingo/features/video/domain/repositories/video_repository.dart';

class SaveVideoProgress {
  final VideoRepository _repository;

  const SaveVideoProgress(this._repository);

  Future<void> call(VideoProgress progress) {
    return _repository.saveProgress(progress);
  }
}
