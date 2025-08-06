import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:pareto_lingo/models/flashcard_model.dart';

Future<void> seedFlashcards() async {
  final box = Hive.box<Flashcard>('flashcards');

  if (box.isNotEmpty) return;

  final jsonString = await rootBundle.loadString('assets/french_words.json');
  final List<dynamic> data = jsonDecode(jsonString);

  for (var item in data) {
    final card = Flashcard(word: item['word'], meaning: item['meaning']);
    await box.add(card);
  }
}
