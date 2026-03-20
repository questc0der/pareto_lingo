import 'dart:math';

import 'package:pareto_lingo/features/flashcard/domain/entities/flashcard_item.dart';
import 'package:pareto_lingo/features/flashcard/domain/services/srs_scheduler.dart';

/// Pure-Dart FSRS-4.5 implementation.
///
/// Rating mapping (to match existing UI buttons):
///   0 → Again (1)
///   2 → Hard  (2)
///   3 → Good  (3)
///   5 → Easy  (4)
///
/// Reference: https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm
class FsrsScheduler implements SrsScheduler {
  const FsrsScheduler();

  // FSRS-4.5 default weights (w0..w18) from the open-spaced-repetition project
  static const List<double> _w = [
    0.4072, 1.1829, 3.1262, 15.4722,
    7.2102, 0.5316, 1.0651, 0.0589,
    1.5330, 0.1544, 1.0064, 1.9395,
    0.1100, 0.2900, 2.2700, 0.1500,
    2.9898, 0.5100, 0.4300,
  ];

  static const double _requestRetention = 0.9; // target 90% retention
  static const double _decayFactor = -0.5;
  static const double _stabilityFactor = 0.9;

  /// Convert the existing 0/2/3/5 rating to FSRS 1-4 rating.
  int _toFsrsRating(int quality) {
    if (quality <= 0) return 1; // Again
    if (quality <= 2) return 2; // Hard
    if (quality <= 3) return 3; // Good
    return 4;                   // Easy
  }

  /// Initial stability for a new card based on first rating.
  double _initialStability(int rating) => _w[rating - 1];

  /// Initial difficulty for a new card based on first rating.
  double _initialDifficulty(int rating) {
    return (_w[4] - exp(_w[5] * (rating - 1)) + 1).clamp(1.0, 10.0);
  }

  /// Recall probability given stability [s] and elapsed days [t].
  double _retrievability(double stability, int elapsedDays) {
    return pow(1 + _stabilityFactor * elapsedDays / stability, _decayFactor)
        .toDouble();
  }

  /// Next interval in days that achieves [_requestRetention].
  int _nextInterval(double stability) {
    final interval = stability / _stabilityFactor *
        (pow(_requestRetention, 1.0 / _decayFactor) - 1);
    return interval.round().clamp(1, 36500);
  }

  /// Stability after a successful recall.
  double _stabilityAfterRecall({
    required double oldStability,
    required double difficulty,
    required double retrievability,
    required int rating,
  }) {
    final hardPenalty = rating == 2 ? _w[15] : 1.0;
    final easyBonus  = rating == 4 ? _w[16] : 1.0;
    return oldStability *
        (exp(_w[8]) *
            (11 - difficulty) *
            pow(oldStability, -_w[9]) *
            (exp((1 - retrievability) * _w[10]) - 1) *
            hardPenalty *
            easyBonus +
            1);
  }

  /// Stability after a lapse (failed recall).
  double _stabilityAfterLapse({
    required double oldStability,
    required double difficulty,
    required double retrievability,
  }) {
    return _w[11] *
        pow(difficulty, -_w[12]) *
        (pow(oldStability + 1, _w[13]) - 1) *
        exp((1 - retrievability) * _w[14]);
  }

  /// Updated difficulty after a rating.
  double _nextDifficulty(double difficulty, int rating) {
    final delta = _w[6] * (rating - 3);
    final updated = difficulty - delta +
        _w[7] * (difficulty - _initialDifficulty(3)) * (difficulty - 1) / 9;
    return updated.clamp(1.0, 10.0);
  }

  @override
  SrsSchedule schedule({
    required FlashcardItem card,
    required int quality,
    required DateTime reviewedAt,
  }) {
    final rating = _toFsrsRating(quality);
    final isNew = card.repetitions == 0 && card.stability == 0.0;

    double newStability;
    double newDifficulty;
    int newLapses = card.lapses;
    int newRepetitions;

    if (isNew) {
      // First review — initialise from rating
      newStability  = _initialStability(rating);
      newDifficulty = _initialDifficulty(rating);
      newRepetitions = rating >= 3 ? 1 : 0;
    } else {
      final elapsedDays = reviewedAt.difference(card.dueDate).inDays.abs();
      final r = _retrievability(card.stability, elapsedDays);
      newDifficulty = _nextDifficulty(card.difficulty, rating);

      if (rating == 1) {
        // Lapse
        newLapses = card.lapses + 1;
        newStability = _stabilityAfterLapse(
          oldStability: card.stability,
          difficulty: newDifficulty,
          retrievability: r,
        );
        newRepetitions = 0;
      } else {
        newStability = _stabilityAfterRecall(
          oldStability: card.stability,
          difficulty: newDifficulty,
          retrievability: r,
          rating: rating,
        );
        newRepetitions = card.repetitions + 1;
      }
    }

    // "Again" cards come back in 1 minute during the session
    if (rating == 1) {
      return SrsSchedule(
        interval: 0,
        repetitions: newRepetitions,
        easeFactorPermille: card.easeFactorPermille,
        dueDate: reviewedAt.add(const Duration(minutes: 1)),
        stability: newStability,
        difficulty: newDifficulty,
        lapses: newLapses,
      );
    }

    final intervalDays = _nextInterval(newStability);
    return SrsSchedule(
      interval: intervalDays,
      repetitions: newRepetitions,
      easeFactorPermille: card.easeFactorPermille, // kept for compat
      dueDate: reviewedAt.add(Duration(days: intervalDays)),
      stability: newStability,
      difficulty: newDifficulty,
      lapses: newLapses,
    );
  }
}
