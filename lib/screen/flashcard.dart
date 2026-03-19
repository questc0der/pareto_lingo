import 'package:flutter/material.dart';
import 'package:pareto_lingo/features/flashcard/presentation/screens/flashcard_review_screen.dart';

class FlashCardReviewScreen extends StatelessWidget {
  final int? dailyLimit;

  const FlashCardReviewScreen({super.key, this.dailyLimit});

  @override
  Widget build(BuildContext context) {
    return FlashcardReviewScreen(dailyLimit: dailyLimit);
  }
}
