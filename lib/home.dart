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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [HeaderCard(), Expanded(child: Progress())]),
    );
  }
}
