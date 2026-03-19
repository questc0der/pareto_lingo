import 'package:pareto_lingo/features/learning/domain/entities/learning_bootstrap_content.dart';
import 'package:pareto_lingo/features/learning/domain/repositories/learning_bootstrap_repository.dart';

class GetLearningBootstrapContent {
  final LearningBootstrapRepository _repository;

  const GetLearningBootstrapContent(this._repository);

  Future<LearningBootstrapContent> call(String languageCode) {
    return _repository.getLanguageBootstrapContent(languageCode);
  }
}
