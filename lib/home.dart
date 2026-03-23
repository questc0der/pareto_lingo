import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pareto_lingo/features/podcast/presentation/screens/podcast_screen.dart';
import 'package:pareto_lingo/components/header_card.dart';
import 'package:pareto_lingo/components/progress.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/flashcard/presentation/providers/flashcard_providers.dart';
import 'package:pareto_lingo/features/news/presentation/screens/news_feed_screen.dart';
import 'package:pareto_lingo/screen/settings.dart';

class HomeState extends ConsumerStatefulWidget {
  const HomeState({super.key});

  @override
  Home createState() => Home();
}

class Home extends ConsumerState<HomeState> {
  int currentPageIndex = 0;

  static const _labels = ['Home', 'Podcast', 'News', 'Settings'];

  static const _icons = [
    Icons.home_rounded,
    Icons.podcasts_rounded,
    Icons.newspaper_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final languageCode = ref
        .watch(userLearningLanguageProvider)
        .maybeWhen(
          data: (code) => code,
          orElse: () => ref.watch(selectedLearningLanguageProvider),
        );

    // Trigger the prewarm so cards are ready before the user taps Start.
    // The value (List<FlashcardItem>) is read by FlashcardReviewScreen directly.
    ref.watch(flashcardPrewarmProvider(languageCode));

    final pages = <Widget>[
      const _HomeTab(),
      const PodcastScreen(),
      const NewsFeedScreen(),
      const SettingsScreen(),
    ];

    return PopScope(
      canPop: currentPageIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && currentPageIndex != 0) {
          setState(() {
            currentPageIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey<int>(currentPageIndex),
              child: pages[currentPageIndex],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final theme = Theme.of(context);

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        indicatorColor: theme.colorScheme.primaryContainer,
        backgroundColor: theme.colorScheme.surface,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ) ??
              TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              );
        }),
      ),
      child: NavigationBar(
        selectedIndex: currentPageIndex,
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        destinations: List.generate(
          _labels.length,
          (index) => NavigationDestination(
            icon: Icon(_icons[index]),
            selectedIcon: Icon(_icons[index], fill: 1),
            label: _labels[index],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return Column(children: const [HeaderCard(), Expanded(child: Progress())]);
  }
}
