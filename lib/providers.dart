import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pareto_lingo/auth/login.dart';
import 'package:pareto_lingo/home.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pareto_lingo/screen/flashcard.dart';
import 'package:pareto_lingo/screen/rules.dart';
import 'package:pareto_lingo/screen/speak.dart';

import './models/user_dao.dart';

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

final userDaoProvider = ChangeNotifierProvider<UserDao>((ref) {
  return UserDao();
});

final authStateProvider = StreamProvider((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

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
    ],
  );
});
