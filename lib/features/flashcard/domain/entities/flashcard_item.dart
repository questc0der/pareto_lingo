class FlashcardItem {
  final String id;
  final String word;
  final String meaning;
  final String? exampleSentence;
  final int interval;
  final int repetitions;
  final int easeFactorPermille;
  final DateTime dueDate;
  // FSRS fields
  final double stability;
  final double difficulty;
  final int lapses;

  const FlashcardItem({
    required this.id,
    required this.word,
    required this.meaning,
    this.exampleSentence,
    required this.interval,
    required this.repetitions,
    required this.easeFactorPermille,
    required this.dueDate,
    this.stability = 0.0,
    this.difficulty = 5.0,
    this.lapses = 0,
  });
}
