import 'package:pareto_lingo/features/video/domain/entities/learning_video.dart';
import 'package:pareto_lingo/features/video/domain/repositories/video_repository.dart';

class GetLearningVideos {
  final VideoRepository _repository;

  const GetLearningVideos(this._repository);

  Future<List<LearningVideo>> call({required String languageCode}) {
    return _repository.getLearningVideos(languageCode: languageCode);
  }
}
