import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:neubrutalism_ui/neubrutalism_ui.dart';
import 'package:pareto_lingo/features/flashcard/presentation/providers/flashcard_providers.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';

class FlashcardReviewScreen extends ConsumerStatefulWidget {
  final int? dailyLimit;

  const FlashcardReviewScreen({super.key, this.dailyLimit});

  @override
  ConsumerState<FlashcardReviewScreen> createState() =>
      _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends ConsumerState<FlashcardReviewScreen>
    with SingleTickerProviderStateMixin {
  bool _initialized = false;
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    // Try to use the prewarmed card list from the home screen for instant open.
    final languageCode = ref
        .read(userLearningLanguageProvider)
        .maybeWhen(data: (c) => c, orElse: () => 'fr');

    final prewarmed = ref.read(flashcardPrewarmProvider(languageCode));
    prewarmed.whenData((cards) {
      ref
          .read(flashcardSessionControllerProvider.notifier)
          .initializeFromPrewarmed(cards);
    });

    // Fallback: if prewarm isn't ready yet, load fresh (shows spinner).
    if (!prewarmed.hasValue) {
      final int configuredLimit =
          widget.dailyLimit ??
          ref
              .read(dailyFlashcardLimitProvider)
              .maybeWhen(data: (l) => l, orElse: () => 10);
      ref
          .read(flashcardSessionControllerProvider.notifier)
          .initialize(dailyLimit: configuredLimit);
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _revealWithAnimation(FlashcardSessionController controller) async {
    await _flipController.forward();
    controller.revealAnswer();
  }

  void _onRate(FlashcardSessionController controller, int quality) {
    _flipController.reset();
    controller.rateCurrent(quality: quality);
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
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              const Text(
                'All caught up! 🎉',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('No cards due right now. Come back later.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    final card = state.currentCard;
    if (card == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final total = state.queue.length;
    final current = state.currentIndex + 1;
    final progress = current / total;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Flashcards  $current / $total',
          style: const TextStyle(
            fontFamily: 'Circular',
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFF7DF9FF),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Card ──────────────────────────────────────────────────────
            Expanded(
              child: AnimatedBuilder(
                animation: _flipAnimation,
                builder: (context, child) {
                  return NeuCard(
                    cardColor: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Word or meaning depending on flip state
                            Text(
                              state.showAnswer ? card.meaning : card.word,
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Circular',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            // Example sentence (only shown when answer is revealed)
                            if (state.showAnswer &&
                                card.exampleSentence != null &&
                                card.exampleSentence!.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 12),
                              Text(
                                card.exampleSentence!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Circular',
                                  color: Colors.grey.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            // FSRS difficulty badge
                            if (state.showAnswer) ...[
                              const SizedBox(height: 16),
                              _buildDifficultyBadge(card.difficulty),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // ── Buttons ───────────────────────────────────────────────────
            if (!state.showAnswer)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: NeuTextButton(
                  borderRadius: BorderRadius.circular(12),
                  buttonColor: const Color(0xFF7dF9FF),
                  enableAnimation: true,
                  onPressed: () => _revealWithAnimation(controller),
                  text: const Text(
                    'Show Answer',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            if (state.showAnswer)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ratingButton(
                          label: 'Again',
                          sublabel: '< 1 min',
                          color: const Color(0xFFFF5252),
                          onTap: () => _onRate(controller, 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ratingButton(
                          label: 'Hard',
                          sublabel: 'difficult',
                          color: const Color(0xFFFF9800),
                          onTap: () => _onRate(controller, 2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ratingButton(
                          label: 'Good',
                          sublabel: 'remembered',
                          color: const Color(0xFF448AFF),
                          onTap: () => _onRate(controller, 3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ratingButton(
                          label: 'Easy',
                          sublabel: 'effortless',
                          color: const Color(0xFF4CAF50),
                          onTap: () => _onRate(controller, 5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _ratingButton({
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return NeuTextButton(
      borderRadius: BorderRadius.circular(12),
      enableAnimation: false,
      buttonColor: color,
      onPressed: onTap,
      text: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label\n',
              style: const TextStyle(
                fontFamily: 'Circular',
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            TextSpan(
              text: sublabel,
              style: const TextStyle(
                fontFamily: 'Circular',
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDifficultyBadge(double difficulty) {
    final pct = ((difficulty - 1) / 9).clamp(0.0, 1.0);
    final color = Color.lerp(Colors.green, Colors.red, pct)!;
    final label =
        difficulty < 3
            ? 'Easy word'
            : difficulty < 6
            ? 'Medium word'
            : 'Hard word';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Circular',
        ),
      ),
    );
  }
}
