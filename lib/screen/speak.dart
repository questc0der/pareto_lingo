import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

class Speak extends StatefulWidget {
  const Speak({super.key});

  @override
  State<Speak> createState() => _Shadowing();
}

class _Shadowing extends State<Speak> {
  late final AudioPlayer player;
  List<dynamic> data = [];

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    setupAudio();
    _loadJson();
  }

  Future<void> setupAudio() async {
    await player.setAsset('assets/short_stories_in_french.mp3');
  }

  Future<void> _loadJson() async {
    final String jsonString = await rootBundle.loadString(
      'assets/alignment_output.json',
    );
    Map<String, dynamic> root = json.decode(jsonString);
    List<dynamic> fragments = root['fragments'];

    if (!mounted) return;
    setState(() {
      data = fragments;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),

            child:
                data.isEmpty
                    ? Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        final item = data[index];
                        return Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            item['lines'][0],
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ),
        Row(
          children: [
            ElevatedButton(
              onPressed: () {
                player.play();
              },
              child: Text("Play"),
            ),
            ElevatedButton(
              onPressed: () {
                player.pause();
              },
              child: Text("Pause"),
            ),
          ],
        ),
      ],
    );
  }
}
