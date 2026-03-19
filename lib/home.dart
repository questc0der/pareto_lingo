import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pareto_lingo/features/podcast/presentation/screens/podcast_screen.dart';
import 'package:neubrutalism_ui/neubrutalism_ui.dart';
import 'package:pareto_lingo/components/header_card.dart';
import 'package:pareto_lingo/components/progress.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/flashcard/presentation/providers/flashcard_providers.dart';
import 'package:pareto_lingo/screen/settings.dart';
import 'package:pareto_lingo/screen/video.dart';

class HomeState extends ConsumerStatefulWidget {
  const HomeState({super.key});

  @override
  Home createState() => Home();
}

class Home extends ConsumerState<HomeState> {
  int currentPageIndex = 1;
  @override
  Widget build(BuildContext context) {
    final languageCode = ref
        .watch(userLearningLanguageProvider)
        .maybeWhen(
          data: (code) => code,
          orElse: () => ref.watch(selectedLearningLanguageProvider),
        );

    ref.watch(flashcardPrewarmProvider(languageCode));

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
        bottomNavigationBar: _buildBottomNavigationBar(),
        body:
            <Widget>[
              Column(children: [HeaderCard(), Expanded(child: Progress())]),
              PodcastScreen(),
              ShortVideoFeed(),
              const SettingsScreen(),
            ][currentPageIndex],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      destinations: <Widget>[
        NavigationDestination(
          icon: NeuIconButton(
            onPressed:
                () => setState(() {
                  currentPageIndex = 0;
                }),
            buttonWidth: MediaQuery.of(context).size.width / 7,
            buttonHeight: MediaQuery.of(context).size.height / 20,
            borderRadius: BorderRadius.circular(8),
            buttonColor: Colors.white,
            enableAnimation: true,
            icon: Icon(Icons.home),
          ),
          label: "Home",
        ),
        NavigationDestination(
          icon: NeuIconButton(
            onPressed:
                () => setState(() {
                  currentPageIndex = 1;
                }),
            buttonWidth: MediaQuery.of(context).size.width / 7,
            buttonHeight: MediaQuery.of(context).size.height / 20,
            borderRadius: BorderRadius.circular(8),
            buttonColor: Colors.white,
            enableAnimation: true,
            icon: Icon(Icons.podcasts),
          ),
          label: "Podcast",
        ),
        NavigationDestination(
          icon: NeuIconButton(
            onPressed:
                () => setState(() {
                  currentPageIndex = 2;
                }),
            buttonWidth: MediaQuery.of(context).size.width / 7,
            buttonHeight: MediaQuery.of(context).size.height / 20,
            borderRadius: BorderRadius.circular(8),
            buttonColor: Colors.white,
            enableAnimation: true,
            icon: Icon(Icons.video_library_rounded),
          ),
          label: "Video",
        ),
        NavigationDestination(
          icon: NeuIconButton(
            onPressed:
                () => setState(() {
                  currentPageIndex = 3;
                }),
            buttonWidth: MediaQuery.of(context).size.width / 7,
            buttonHeight: MediaQuery.of(context).size.height / 20,
            borderRadius: BorderRadius.circular(8),
            buttonColor: Colors.white,
            enableAnimation: true,
            icon: Icon(Icons.settings),
          ),
          label: "Setting",
        ),
      ],
      selectedIndex: currentPageIndex,
      onDestinationSelected: (int index) {
        setState(() {
          currentPageIndex = index;
        });
      },
    );
  }
}
