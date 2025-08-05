import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeState extends ConsumerStatefulWidget {
  const HomeState({super.key});

  @override
  Home createState() => Home();
}

class Home extends ConsumerState<HomeState> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text("This is ParetoLingo")));
  }
}
