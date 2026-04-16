import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:pareto_lingo/features/learning/data/datasources/language_bootstrap_remote_data_source.dart';
import 'package:pareto_lingo/features/learning/data/repositories/learning_bootstrap_repository_impl.dart';
import 'package:pareto_lingo/features/learning/domain/entities/learning_bootstrap_content.dart';
import 'package:pareto_lingo/features/learning/domain/repositories/learning_bootstrap_repository.dart';
import 'package:pareto_lingo/features/learning/domain/usecases/get_learning_bootstrap_content.dart';

final learningHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final backendBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
});

final useRemoteContentProvider = Provider<bool>((ref) {
  const explicit = String.fromEnvironment(
    'USE_REMOTE_CONTENT',
    defaultValue: '',
  );
  if (explicit.isNotEmpty) {
    return explicit.toLowerCase() == 'true';
  }

  return ref.read(backendBaseUrlProvider).trim().isNotEmpty;
});

final learningBootstrapCacheBoxProvider = Provider<Box<String>>((ref) {
  return Hive.box<String>('learning_bootstrap_cache');
});

final languageBootstrapRemoteDataSourceProvider =
    Provider<LanguageBootstrapRemoteDataSource>((ref) {
      return LanguageBootstrapRemoteDataSource(
        ref.read(learningHttpClientProvider),
        ref.read(backendBaseUrlProvider),
        useRemoteSources: ref.read(useRemoteContentProvider),
      );
    });

final learningBootstrapRepositoryProvider =
    Provider<LearningBootstrapRepository>((ref) {
      return LearningBootstrapRepositoryImpl(
        ref.read(languageBootstrapRemoteDataSourceProvider),
        ref.read(learningBootstrapCacheBoxProvider),
      );
    });

final getLearningBootstrapContentProvider =
    Provider<GetLearningBootstrapContent>((ref) {
      return GetLearningBootstrapContent(
        ref.read(learningBootstrapRepositoryProvider),
      );
    });

final learningBootstrapContentProvider =
    FutureProvider.family<LearningBootstrapContent, String>((
      ref,
      languageCode,
    ) {
      return ref.read(getLearningBootstrapContentProvider)(languageCode);
    });
