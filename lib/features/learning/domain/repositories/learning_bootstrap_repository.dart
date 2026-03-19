import 'package:pareto_lingo/features/learning/domain/entities/learning_bootstrap_content.dart';

abstract class LearningBootstrapRepository {
  Future<LearningBootstrapContent> getLanguageBootstrapContent(
    String languageCode,
  );
}
