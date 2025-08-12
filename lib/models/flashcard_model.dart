import 'dart:async';

import 'package:hive/hive.dart';

part 'flashcard_model.g.dart';

@HiveType(typeId: 0)
class Flashcard extends HiveObject {
  @HiveField(0)
  String word;

  @HiveField(1)
  String meaning;

  @HiveField(2)
  int interval;

  @HiveField(3)
  int easeFactor;

  @HiveField(4)
  DateTime dueDate;

  @HiveField(5)
  int repetitions;

  Flashcard({
    required this.word,
    required this.meaning,
    this.interval = 1,
    this.easeFactor = 250,
    DateTime? dueDate,
    this.repetitions = 0,
  }) : dueDate = dueDate ?? DateTime.now();

  void updateReview(int quality) {
    if (quality < 3) {
      repetitions = 0;
      // For "Again", set a very short interval (e.g. 1 minute)
      interval = 0; // or some sentinel for immediate repetition
      dueDate = DateTime.now().add(Duration(minutes: 1));
    } else if (quality == 3) {
      // Medium, set a short interval (e.g. 10 minutes)
      repetitions++;
      interval = 10; // or your chosen value in minutes
      dueDate = DateTime.now().add(Duration(minutes: interval));
      // adjust easeFactor similarly
    } else {
      repetitions++;
      // existing spaced repetition formula, but with days
      interval = (interval * (easeFactor / 100)).round();
      dueDate = DateTime.now().add(Duration(days: interval));
      // adjust easeFactor similarly
    }
    save();
  }

  /// Helper: get cards due today or earlier, limited
  static List<Flashcard> dueCards(List<Flashcard> all, int limit) {
    final now = DateTime.now();
    final soon = now.add(Duration(minutes: 5));
    final due = all.where((c) => !c.dueDate.isAfter(soon));
    return due.take(limit).toList();
  }
}
