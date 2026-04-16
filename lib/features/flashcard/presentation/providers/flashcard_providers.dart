import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pareto_lingo/features/learning/presentation/providers/learning_bootstrap_providers.dart';
import 'package:pareto_lingo/features/flashcard/data/repositories/hive_flashcard_repository.dart';
import 'package:pareto_lingo/features/flashcard/domain/entities/flashcard_item.dart';
import 'package:pareto_lingo/features/flashcard/domain/repositories/flashcard_repository.dart';
import 'package:pareto_lingo/features/flashcard/domain/services/fsrs_scheduler.dart';
import 'package:pareto_lingo/features/flashcard/domain/services/srs_scheduler.dart';
import 'package:pareto_lingo/features/flashcard/domain/usecases/get_due_flashcards.dart';
import 'package:pareto_lingo/features/flashcard/domain/usecases/review_flashcard.dart';
import 'package:pareto_lingo/models/flashcard_model.dart';

class FlashcardStats {
  final int studied;
  final int remaining;

  const FlashcardStats({required this.studied, required this.remaining});
}

const _nativeLanguageKey = 'native_language_code';

final flashcardBoxProvider = Provider<Box<Flashcard>>((ref) {
  return Hive.box<Flashcard>('flashcards');
});

final appSettingsBoxProvider = Provider<Box<String>>((ref) {
  return Hive.box<String>('app_settings');
});

final dailyFlashcardLimitProvider = StreamProvider<int>((ref) async* {
  final box = ref.read(appSettingsBoxProvider);

  int parseLimit() {
    final raw = box.get('daily_flashcards_limit');
    final parsed = int.tryParse(raw ?? '10') ?? 10;
    return parsed.clamp(5, 100);
  }

  yield parseLimit();

  await for (final _ in box.watch(key: 'daily_flashcards_limit')) {
    yield parseLimit();
  }
});

Future<void> setDailyFlashcardLimit(WidgetRef ref, int value) async {
  final clamped = value.clamp(5, 100);
  await ref
      .read(appSettingsBoxProvider)
      .put('daily_flashcards_limit', clamped.toString());
}

Future<bool> addCustomFlashcard(
  WidgetRef ref, {
  required String word,
  required String meaning,
  String? exampleSentence,
}) async {
  final normalizedWord = word.trim();
  final normalizedMeaning = meaning.trim();

  if (normalizedWord.isEmpty || normalizedMeaning.isEmpty) {
    return false;
  }

  final box = ref.read(flashcardBoxProvider);

  final alreadyExists = box.values.any((card) {
    return card.word.trim().toLowerCase() == normalizedWord.toLowerCase();
  });

  if (alreadyExists) {
    return false;
  }

  await box.add(
    Flashcard(
      word: normalizedWord,
      meaning: normalizedMeaning,
      interval: 1,
      repetitions: 0,
      dueDate: DateTime.now(),
      exampleSentence:
          exampleSentence?.trim().isEmpty == true
              ? null
              : exampleSentence?.trim(),
    ),
  );

  return true;
}

final flashcardRepositoryProvider = Provider<FlashcardRepository>((ref) {
  return HiveFlashcardRepository(ref.read(flashcardBoxProvider));
});

final flashcardStatsProvider = StreamProvider<FlashcardStats>((ref) async* {
  final box = ref.read(flashcardBoxProvider);

  FlashcardStats compute() {
    final allCards = box.values.toList(growable: false);
    final studiedCount = allCards.where((card) => card.repetitions > 0).length;
    final remainingCount = (allCards.length - studiedCount).clamp(
      0,
      allCards.length,
    );

    return FlashcardStats(studied: studiedCount, remaining: remainingCount);
  }

  yield compute();

  await for (final _ in box.watch()) {
    yield compute();
  }
});

final syncFlashcardDeckProvider = FutureProvider.family<void, String>((
  ref,
  languageCode,
) async {
  const targetDeckSize = 1000;
  final flashcardBox = ref.read(flashcardBoxProvider);
  final appSettingsBox = ref.read(appSettingsBoxProvider);
  final targetMeaningLanguage = _targetMeaningLanguageForDeck(
    languageCode,
    appSettingsBox,
  );
  final bootstrapContent = await ref.read(
    learningBootstrapContentProvider(languageCode).future,
  );

  final deckWords = bootstrapContent.topWords;
  if (deckWords.isEmpty && flashcardBox.isEmpty) {
    return;
  }

  final backendDeck = await ref
      .read(languageBootstrapRemoteDataSourceProvider)
      .fetchFlashcardDeck(
        languageCode: languageCode,
        limit: 1000,
        targetLanguage: targetMeaningLanguage,
      );

  final currentDeckLanguage = appSettingsBox.get('flashcard_deck_language');
  final hasStudyProgress = flashcardBox.values.any(
    (card) => card.repetitions > 0,
  );

  await _normalizeExistingDeckMeanings(flashcardBox);

  if (currentDeckLanguage == null &&
      flashcardBox.isNotEmpty &&
      hasStudyProgress) {
    await appSettingsBox.put('flashcard_deck_language', languageCode);
    return;
  }

  // If user started with a partial local deck, enrich it when remote data appears.
  if (backendDeck.isNotEmpty && flashcardBox.length < targetDeckSize) {
    await _mergeMissingDeckFromPairs(
      flashcardBox,
      backendDeck
          .map((entry) => (word: entry.word, meaning: entry.meaning))
          .toList(growable: false),
      maxSize: targetDeckSize,
    );
  }

  final shouldRebuildByLanguage = currentDeckLanguage != languageCode;
  final shouldRebuildBySize = flashcardBox.length < targetDeckSize;
  final shouldRebuild =
      (shouldRebuildByLanguage || shouldRebuildBySize) && !hasStudyProgress;

  if (!shouldRebuild) {
    if (languageCode == 'fr' && !hasStudyProgress) {
      final hasIdenticalMeanings = flashcardBox.values.any(
        (card) => card.word.trim() == card.meaning.trim(),
      );

      if (hasIdenticalMeanings) {
        await _reseedFrenchDeckFromAsset(flashcardBox);
      }
    }
    return;
  }

  // Keep existing deck if online sources are temporarily unavailable.
  if (deckWords.isEmpty && flashcardBox.isNotEmpty) {
    await appSettingsBox.put('flashcard_deck_language', languageCode);
    return;
  }

  if (languageCode == 'fr') {
    if (backendDeck.length >= 100) {
      await _seedDeckFromPairs(
        flashcardBox,
        backendDeck
            .map((entry) => (word: entry.word, meaning: entry.meaning))
            .toList(growable: false),
      );
    } else {
      await _reseedFrenchDeckFromAsset(flashcardBox);
    }
  } else {
    if (backendDeck.length >= 100) {
      await _seedDeckFromPairs(
        flashcardBox,
        backendDeck
            .map((entry) => (word: entry.word, meaning: entry.meaning))
            .toList(growable: false),
      );
    } else {
      await flashcardBox.clear();
      // Use putAll for a large batch — much faster than sequential add()
      final entries = <dynamic, Flashcard>{};
      int key = 0;
      for (final word in deckWords.take(targetDeckSize)) {
        entries[key++] = Flashcard(
          word: word,
          meaning: _fallbackMeaningForWord(word),
        );
      }
      await flashcardBox.putAll(entries);
    }
  }

  await appSettingsBox.put('flashcard_deck_language', languageCode);
});

Future<void> _reseedFrenchDeckFromAsset(Box<Flashcard> flashcardBox) async {
  await flashcardBox.clear();
  final jsonString = await rootBundle.loadString('assets/french_words.json');
  final List<dynamic> data = jsonDecode(jsonString);

  final entries = <dynamic, Flashcard>{};
  int key = 0;
  for (final item in data.take(1000)) {
    entries[key++] = Flashcard(
      word: item['word'].toString(),
      meaning: item['meaning'].toString(),
    );
  }
  await flashcardBox.putAll(entries);
}

Future<void> _mergeMissingDeckFromPairs(
  Box<Flashcard> flashcardBox,
  List<({String word, String meaning})> pairs, {
  required int maxSize,
}) async {
  if (pairs.isEmpty) return;

  final existingWords =
      flashcardBox.values.map((card) => card.word.trim().toLowerCase()).toSet();

  for (final pair in pairs) {
    if (flashcardBox.length >= maxSize) {
      break;
    }

    final word = pair.word.trim();
    if (word.isEmpty) continue;

    final normalizedWord = word.toLowerCase();
    if (existingWords.contains(normalizedWord)) {
      continue;
    }

    final meaning =
        pair.meaning.trim().isEmpty
            ? _fallbackMeaningForWord(word)
            : pair.meaning.trim();

    await flashcardBox.add(Flashcard(word: word, meaning: meaning));
    existingWords.add(normalizedWord);
  }
}

Future<void> _seedDeckFromPairs(
  Box<Flashcard> flashcardBox,
  List<({String word, String meaning})> pairs,
) async {
  await flashcardBox.clear();
  // Batch write — significantly faster than sequential add() for 1000 records
  final entries = <dynamic, Flashcard>{};
  int key = 0;
  for (final pair in pairs.take(1000)) {
    final normalizedMeaning =
        pair.meaning.trim().isEmpty
            ? _fallbackMeaningForWord(pair.word)
            : pair.meaning;
    entries[key++] = Flashcard(word: pair.word, meaning: normalizedMeaning);
  }
  await flashcardBox.putAll(entries);
}

Future<void> _normalizeExistingDeckMeanings(Box<Flashcard> flashcardBox) async {
  for (var index = 0; index < flashcardBox.length; index++) {
    final key = flashcardBox.keyAt(index);
    final card = flashcardBox.get(key);
    if (card == null) continue;

    final meaning = card.meaning.trim();
    final isPlaceholder =
        meaning.isEmpty || meaning == '—' || meaning == '-' || meaning == '...';

    if (isPlaceholder) {
      card.meaning = _fallbackMeaningForWord(card.word);
      await card.save();
    }
  }
}

String _fallbackMeaningForWord(String word) {
  return 'meaning: ${word.trim()}';
}

String _targetMeaningLanguageForDeck(
  String languageCode,
  Box<String> settings,
) {
  if (languageCode.toLowerCase() == 'en') {
    final native = settings.get(_nativeLanguageKey)?.trim().toLowerCase();
    if (native != null &&
        (native == 'fr' || native == 'zh' || native == 'en')) {
      return native;
    }
    return 'fr';
  }

  return 'en';
}

// ── FSRS ─────────────────────────────────────────────────────────────────────
final srsSchedulerProvider = Provider<SrsScheduler>((ref) {
  return const FsrsScheduler();
});

final getDueFlashcardsProvider = Provider<GetDueFlashcards>((ref) {
  return GetDueFlashcards(ref.read(flashcardRepositoryProvider));
});

/// Prewarms the deck (sync) then loads due cards into memory.
/// The session screen reads from this cache — so it opens instantly.
final flashcardPrewarmProvider =
    FutureProvider.family<List<FlashcardItem>, String>((
      ref,
      languageCode,
    ) async {
      await ref.watch(syncFlashcardDeckProvider(languageCode).future);

      final rawLimit = ref
          .read(appSettingsBoxProvider)
          .get('daily_flashcards_limit');
      final dailyLimit = (int.tryParse(rawLimit ?? '10') ?? 10).clamp(5, 100);

      return ref.read(getDueFlashcardsProvider)(limit: dailyLimit);
    });

final reviewFlashcardProvider = Provider<ReviewFlashcard>((ref) {
  return ReviewFlashcard(
    ref.read(flashcardRepositoryProvider),
    ref.read(srsSchedulerProvider),
  );
});

// ── Session ───────────────────────────────────────────────────────────────────
class FlashcardSessionState {
  final bool isLoading;
  final List<FlashcardItem> queue;
  final List<FlashcardItem> sessionRepeats;
  final int currentIndex;
  final bool showAnswer;
  final bool isComplete;
  final String? transientMessage;

  const FlashcardSessionState({
    this.isLoading = false,
    this.queue = const [],
    this.sessionRepeats = const [],
    this.currentIndex = 0,
    this.showAnswer = false,
    this.isComplete = false,
    this.transientMessage,
  });

  FlashcardSessionState copyWith({
    bool? isLoading,
    List<FlashcardItem>? queue,
    List<FlashcardItem>? sessionRepeats,
    int? currentIndex,
    bool? showAnswer,
    bool? isComplete,
    String? transientMessage,
    bool clearTransientMessage = false,
  }) {
    return FlashcardSessionState(
      isLoading: isLoading ?? this.isLoading,
      queue: queue ?? this.queue,
      sessionRepeats: sessionRepeats ?? this.sessionRepeats,
      currentIndex: currentIndex ?? this.currentIndex,
      showAnswer: showAnswer ?? this.showAnswer,
      isComplete: isComplete ?? this.isComplete,
      transientMessage:
          clearTransientMessage
              ? null
              : (transientMessage ?? this.transientMessage),
    );
  }

  FlashcardItem? get currentCard {
    if (queue.isEmpty || currentIndex >= queue.length) return null;
    return queue[currentIndex];
  }
}

class FlashcardSessionController extends StateNotifier<FlashcardSessionState> {
  final GetDueFlashcards _getDueFlashcards;
  final ReviewFlashcard _reviewFlashcard;

  FlashcardSessionController(this._getDueFlashcards, this._reviewFlashcard)
    : super(const FlashcardSessionState());

  /// Initialize from a pre-loaded list (no Hive scan on screen open).
  void initializeFromPrewarmed(List<FlashcardItem> prewarmedCards) {
    state = FlashcardSessionState(
      isLoading: false,
      queue: prewarmedCards,
      sessionRepeats: const [],
      currentIndex: 0,
      showAnswer: false,
      isComplete: prewarmedCards.isEmpty,
    );
  }

  /// Fallback: load due cards fresh (used if prewarm wasn't available).
  Future<void> initialize({required int dailyLimit}) async {
    state = state.copyWith(isLoading: true, clearTransientMessage: true);
    final dueCards = await _getDueFlashcards(limit: dailyLimit);

    state = FlashcardSessionState(
      isLoading: false,
      queue: dueCards,
      sessionRepeats: const [],
      currentIndex: 0,
      showAnswer: false,
      isComplete: dueCards.isEmpty,
    );
  }

  void revealAnswer() {
    state = state.copyWith(showAnswer: true);
  }

  void dismissMessage() {
    state = state.copyWith(clearTransientMessage: true);
  }

  Future<void> rateCurrent({required int quality}) async {
    final card = state.currentCard;
    if (card == null) return;

    await _reviewFlashcard(card: card, quality: quality);

    final updatedRepeats = <FlashcardItem>[...state.sessionRepeats];
    if (quality < 5) {
      updatedRepeats.add(card);
    }

    if (state.currentIndex < state.queue.length - 1) {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        showAnswer: false,
        sessionRepeats: updatedRepeats,
      );
      return;
    }

    if (updatedRepeats.isNotEmpty) {
      state = state.copyWith(
        queue: updatedRepeats,
        sessionRepeats: const [],
        currentIndex: 0,
        showAnswer: false,
        transientMessage: 'Repeating cards rated other than Easy.',
      );
      return;
    }

    state = state.copyWith(
      isComplete: true,
      transientMessage: 'Review session complete!',
    );
  }
}

final flashcardSessionControllerProvider =
    StateNotifierProvider<FlashcardSessionController, FlashcardSessionState>((
      ref,
    ) {
      return FlashcardSessionController(
        ref.read(getDueFlashcardsProvider),
        ref.read(reviewFlashcardProvider),
      );
    });
