import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pareto_lingo/components/header_card.dart';
import 'package:pareto_lingo/components/progress.dart';

class HomeState extends ConsumerStatefulWidget {
  const HomeState({super.key});

  @override
  Home createState() => Home();
}

class Home extends ConsumerState<HomeState> {
  int currentPageIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: Column(children: [HeaderCard(), Expanded(child: Progress())]),
    );
  }

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      destinations: [
        NavigationDestination(icon: Icon(Icons.home), label: "Home"),
        NavigationDestination(icon: Icon(Icons.podcasts), label: "Podcast"),
        NavigationDestination(
          icon: Icon(Icons.video_library_rounded),
          label: "Video",
        ),
        NavigationDestination(icon: Icon(Icons.settings), label: "Setting"),
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
