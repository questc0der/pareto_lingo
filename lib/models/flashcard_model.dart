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

  /// Update SRS data based on quality: 0=Again, 3=Hard, 4=Medium, 5=Easy
  void updateReview(int quality) {
    if (quality < 3) {
      repetitions = 0;
      interval = 1;
    } else {
      repetitions++;
      if (repetitions == 1) {
        interval = 1;
      } else if (repetitions == 2) {
        interval = 6;
      } else {
        interval = (interval * (easeFactor / 100)).round();
      }
      // SM-2 ease factor formula
      double ef = easeFactor / 100;
      ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
      easeFactor = (ef * 100).round();
      if (easeFactor < 130) easeFactor = 130;
    }
    dueDate = DateTime.now().add(Duration(days: interval));
    save(); // persist changes
  }

  /// Helper: get cards due today or earlier, limited
  static List<Flashcard> dueCards(List<Flashcard> all, int limit) {
    final today = DateTime.now();
    final due = all.where((c) => !c.dueDate.isAfter(today));
    return due.take(limit).toList();
  }
}
