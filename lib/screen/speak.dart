import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class Speak extends StatefulWidget {
  const Speak({super.key});

  @override
  State<Speak> createState() => _Shadowing();
}

class _Shadowing extends State<Speak> {
  late final AudioPlayer player;
  List<dynamic> data = [];
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    setupAudio();
    _loadJson();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (status) => debugPrint('Speech status: $status'),
        onError: (error) => debugPrint('Speech error: $error'),
      );
      setState(() {});
    } catch (e) {
      debugPrint('Speech initialization failed: $e');
      _speechEnabled = false;
    }
  }

  void _startListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not initialized')),
      );
      return;
    }

    try {
      await _speechToText.listen(onResult: _onSpeechResult);
      setState(() {});
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
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
    return Scaffold(
      body: Column(
        children: [
          Text(
            _speechToText.isListening
                ? _lastWords
                : _speechEnabled
                ? 'Tap Speak to start'
                : 'Speech not Available',
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (!isPlaying) {
                  unawaited(player.play());
                } else {
                  unawaited(player.pause());
                }
                setState(() {
                  isPlaying = !isPlaying;
                });
              },
              child: Container(
                width: double.infinity,
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
                              child: SelectableText(
                                item['lines'][0],
                                style: TextStyle(
                                  fontFamily: 'Circular',
                                  fontSize: 18,
                                  color: Colors.black,
                                ),
                                onSelectionChanged: (selection, cause) {
                                  if (!selection.isCollapsed) {
                                    item['lines'][0].substring(
                                      selection.start,
                                      selection.end,
                                    );
                                  }
                                },
                                contextMenuBuilder: (
                                  context,
                                  editableTextState,
                                ) {
                                  return AdaptiveTextSelectionToolbar.editableText(
                                    editableTextState: editableTextState,
                                  );
                                },
                              ),
                            );
                          },
                        ),
              ),
            ),
          ),
          Row(
            children: [
              ElevatedButton(
                onPressed:
                    _speechToText.isNotListening
                        ? _startListening
                        : _stopListening,
                child: Text("Speak"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
