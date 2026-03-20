import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:pareto_lingo/models/flashcard_model.dart';

Future<void> seedFlashcards() async {
  final box = Hive.box<Flashcard>('flashcards');

  if (box.isNotEmpty) return;

  final jsonString = await rootBundle.loadString('assets/french_words.json');
  final List<dynamic> data = jsonDecode(jsonString);
  final cards =
      data
          .map(
            (item) => Flashcard(
              word: item['word'] as String,
              meaning: item['meaning'] as String,
            ),
          )
          .toList();

  await box.addAll(cards);
}
