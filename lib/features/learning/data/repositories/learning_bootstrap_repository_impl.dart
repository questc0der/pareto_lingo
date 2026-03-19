import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:pareto_lingo/features/learning/data/datasources/language_bootstrap_remote_data_source.dart';
import 'package:pareto_lingo/features/learning/domain/entities/learning_bootstrap_content.dart';
import 'package:pareto_lingo/features/learning/domain/repositories/learning_bootstrap_repository.dart';

class LearningBootstrapRepositoryImpl implements LearningBootstrapRepository {
  final LanguageBootstrapRemoteDataSource _remoteDataSource;
  final Box<String> _cacheBox;

  const LearningBootstrapRepositoryImpl(this._remoteDataSource, this._cacheBox);

  @override
  Future<LearningBootstrapContent> getLanguageBootstrapContent(
    String languageCode,
  ) async {
    try {
      final remoteContent = await _remoteDataSource.fetchContent(languageCode);
      await _cacheBox.put(languageCode, jsonEncode(_toJson(remoteContent)));
      return remoteContent;
    } catch (_) {
      final cachedRaw = _cacheBox.get(languageCode);
      if (cachedRaw == null) rethrow;

      final cachedMap = jsonDecode(cachedRaw) as Map<String, dynamic>;
      return _fromJson(cachedMap);
    }
  }

  Map<String, dynamic> _toJson(LearningBootstrapContent content) {
    return {
      'languageCode': content.languageCode,
      'topWords': content.topWords,
      'lectureTopics': content.lectureTopics,
      'readingText': content.readingText,
    };
  }

  LearningBootstrapContent _fromJson(Map<String, dynamic> json) {
    return LearningBootstrapContent(
      languageCode: json['languageCode'].toString(),
      topWords: (json['topWords'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      lectureTopics: (json['lectureTopics'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      readingText: json['readingText'].toString(),
    );
  }
}
