import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pareto_lingo/auth/login.dart';
import 'package:pareto_lingo/core/auth/auth_providers.dart';
import 'package:pareto_lingo/features/podcast/presentation/models/podcast_route_args.dart';
import 'package:pareto_lingo/features/podcast/presentation/screens/podcast_episode_list_screen.dart';
import 'package:pareto_lingo/home.dart';
import 'package:pareto_lingo/screen/flashcard.dart';
import 'package:pareto_lingo/screen/rules.dart';
import 'package:pareto_lingo/screen/speak.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(
      FirebaseAuth.instance.authStateChanges(),
    ),
    redirect: (context, state) {
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/';

      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const HomeState()),
      GoRoute(path: '/login', builder: (context, state) => const Login()),
      GoRoute(
        path: '/flashcard',
        builder: (context, state) => FlashCardReviewScreen(),
      ),
      GoRoute(path: '/speak', builder: (context, state) => Speak()),
      GoRoute(path: '/rules', builder: (context, state) => GrammarRules()),
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
