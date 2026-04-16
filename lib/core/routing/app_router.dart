import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:pareto_lingo/features/podcast/presentation/models/podcast_route_args.dart';
import 'package:pareto_lingo/features/podcast/presentation/screens/podcast_episode_list_screen.dart';
import 'package:pareto_lingo/home.dart';
import 'package:pareto_lingo/screen/flashcard.dart';
import 'package:pareto_lingo/screen/listening_match.dart';
import 'package:pareto_lingo/screen/onboarding_language.dart';
import 'package:pareto_lingo/screen/speak.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final appSettings = Hive.box<String>('app_settings');
  final hasSelectedLanguage =
      (appSettings.get('selected_learning_language') ?? '').trim().isNotEmpty;

  return GoRouter(
    initialLocation: hasSelectedLanguage ? '/' : '/onboarding',
    redirect: (context, state) {
      final selectedLanguage =
          (appSettings.get('selected_learning_language') ?? '').trim();
      final hasLanguage = selectedLanguage.isNotEmpty;
      final isOnboarding = state.matchedLocation == '/onboarding';

      if (!hasLanguage && !isOnboarding) return '/onboarding';
      if (hasLanguage && isOnboarding) return '/';

      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const HomeState()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingLanguageScreen(),
      ),
      GoRoute(
        path: '/flashcard',
        builder: (context, state) => FlashCardReviewScreen(),
      ),
      GoRoute(
        path: '/listening',
        builder: (context, state) => const ListeningMatchScreen(),
      ),
      GoRoute(path: '/speak', builder: (context, state) => Speak()),
      GoRoute(
        path: '/podcast_list',
        builder: (context, state) {
          final extra = state.extra;

          if (extra is PodcastListArgs) {
            return PodcastEpisodeListScreen(args: extra);
          }

          if (extra is Map) {
            return PodcastEpisodeListScreen(
              args: PodcastListArgs(
                feedUrl: (extra['content'] ?? '').toString(),
                imageUrl: (extra['image'] ?? '').toString(),
              ),
            );
          }

          return const Scaffold(
            body: Center(child: Text('Invalid podcast route arguments.')),
          );
        },
      ),
    ],
  );
});
