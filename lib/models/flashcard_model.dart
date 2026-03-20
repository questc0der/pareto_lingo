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

  // FSRS fields — new, backward-compatible (default values safe for old records)
  @HiveField(6)
  double stability;

  @HiveField(7)
  double difficulty;

  @HiveField(8)
  int lapses;

  @HiveField(9)
  String? exampleSentence;

  Flashcard({
    required this.word,
    required this.meaning,
    this.interval = 1,
    this.easeFactor = 250,
    DateTime? dueDate,
    this.repetitions = 0,
    this.stability = 0.0,
    this.difficulty = 5.0,
    this.lapses = 0,
    this.exampleSentence,
  }) : dueDate = dueDate ?? DateTime.now();

  /// Helper: get cards due today or earlier, limited
  static List<Flashcard> dueCards(List<Flashcard> all, int limit) {
    final now = DateTime.now();
    final soon = now.add(const Duration(minutes: 5));
    final due = all.where((c) => !c.dueDate.isAfter(soon));
    return due.take(limit).toList();
  }
}
