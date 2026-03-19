import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neubrutalism_ui/neubrutalism_ui.dart';
import 'package:pareto_lingo/features/flashcard/presentation/providers/flashcard_providers.dart';

class FlashcardReviewScreen extends ConsumerStatefulWidget {
  final int? dailyLimit;

  const FlashcardReviewScreen({super.key, this.dailyLimit});

  @override
  ConsumerState<FlashcardReviewScreen> createState() =>
      _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends ConsumerState<FlashcardReviewScreen> {
  @override
  void initState() {
    super.initState();
    final int configuredLimit =
        widget.dailyLimit ??
        ref
            .read(dailyFlashcardLimitProvider)
            .maybeWhen(data: (limit) => limit, orElse: () => 10);

    ref
        .read(flashcardSessionControllerProvider.notifier)
        .initialize(dailyLimit: configuredLimit);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FlashcardSessionState>(flashcardSessionControllerProvider, (
      previous,
      next,
    ) {
      if (next.transientMessage != null &&
          next.transientMessage != previous?.transientMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.transientMessage!)));
        ref.read(flashcardSessionControllerProvider.notifier).dismissMessage();
      }

      if (next.isComplete && !next.isLoading && next.queue.isNotEmpty) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    });

    final state = ref.watch(flashcardSessionControllerProvider);
    final controller = ref.read(flashcardSessionControllerProvider.notifier);

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcards')),
        body: const Center(child: Text('No cards due now.')),
      );
    }

    final card = state.currentCard;
    if (card == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Flashcards (${state.currentIndex + 1}/${state.queue.length})',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: NeuCard(
                cardColor: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: Center(
                  child: Text(
                    state.showAnswer ? card.meaning : card.word,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Circular',
                    ),
                  ),
                ),
              ),
            ),
            if (!state.showAnswer)
              Padding(
                padding: const EdgeInsets.all(18),
                child: NeuTextButton(
                  borderRadius: BorderRadius.circular(8),
                  buttonColor: const Color(0xFF7dF9FF),
                  enableAnimation: true,
                  onPressed: controller.revealAnswer,
                  text: const Text(
                    'Show Answer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            if (state.showAnswer)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        NeuTextButton(
                          borderRadius: BorderRadius.circular(8),
                          enableAnimation: false,
                          onPressed: () => controller.rateCurrent(quality: 0),
                          buttonColor: Colors.red,
                          text: const Text(
                            'Again',
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        NeuTextButton(
                          enableAnimation: false,
                          buttonColor: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                          onPressed: () => controller.rateCurrent(quality: 2),
                          text: const Text(
                            'Hard',
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        NeuTextButton(
                          enableAnimation: false,
                          borderRadius: BorderRadius.circular(8),
                          buttonColor: Colors.blue,
                          onPressed: () => controller.rateCurrent(quality: 3),
                          text: const Text(
                            'Medium',
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        NeuTextButton(
                          enableAnimation: false,
                          buttonColor: Colors.green,
                          onPressed: () => controller.rateCurrent(quality: 5),
                          borderRadius: BorderRadius.circular(8),
                          text: const Text(
                            'Easy',
                            style: TextStyle(
                              fontFamily: 'Circular',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
