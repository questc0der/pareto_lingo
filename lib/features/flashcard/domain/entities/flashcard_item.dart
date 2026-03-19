class FlashcardItem {
  final String id;
  final String word;
  final String meaning;
  final int interval;
  final int repetitions;
  final int easeFactorPermille;
  final DateTime dueDate;

  const FlashcardItem({
    required this.id,
    required this.word,
    required this.meaning,
    required this.interval,
    required this.repetitions,
    required this.easeFactorPermille,
    required this.dueDate,
  });
}
