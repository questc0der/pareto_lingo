import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/flashcard/presentation/providers/flashcard_providers.dart';
import 'package:pareto_lingo/features/learning/presentation/providers/learning_bootstrap_providers.dart';
import 'package:neubrutalism_ui/neubrutalism_ui.dart';

class Progress extends ConsumerWidget {
  const Progress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flashcardStatsAsync = ref.watch(flashcardStatsProvider);
    final languageCode = ref
        .watch(userLearningLanguageProvider)
        .maybeWhen(
          data: (code) => code,
          orElse: () => supportedLearningLanguages.first.code,
        );
    final selectedLanguage = languageOptionByCode(languageCode);
    final bootstrapContentAsync = ref.watch(
      learningBootstrapContentProvider(languageCode),
    );

    final topWordsCount = bootstrapContentAsync.maybeWhen(
      data: (content) => content.topWords.length,
      orElse: () => 1000,
    );

    final readingSnippet = bootstrapContentAsync.maybeWhen(
      data: (content) => content.readingText,
      orElse: () => selectedLanguage.readingText,
    );

    final studied = flashcardStatsAsync.maybeWhen(
      data: (s) => s.studied,
      orElse: () => 0,
    );
    final remaining = max(0, topWordsCount - studied);

    return ListView(
      padding: const EdgeInsets.all(6),
      children: [
        // ── Vocabulary progress ring ─────────────────────────────────
        _VocabularyProgressCard(
          studied: studied,
          total: topWordsCount,
          languageName: selectedLanguage.name,
        ),
        const SizedBox(height: 12),
        // ── Stats row ────────────────────────────────────────────────
        Row(
          children: [
            Expanded(child: _statCard(context, '$studied', 'Studied')),
            const SizedBox(width: 7),
            Expanded(child: _statCard(context, '$remaining', 'Remaining')),
          ],
        ),
        const SizedBox(height: 16),
        _flashCardSection(context, selectedLanguage.name, topWordsCount),
        const SizedBox(height: 16),
        _speakingSection(context),
        const SizedBox(height: 16),
        _listeningSection(context),
        const SizedBox(height: 16),
        _readingSection(context, readingSnippet),
      ],
    );
  }

  Widget _statCard(BuildContext context, String count, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: NeuContainer(
        height: MediaQuery.of(context).size.width / 2.5,
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Circular',
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Circular',
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    String? mode,
    double? height,
    String? description,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: NeuContainer(
        height: height,
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mode != null)
                Text(
                  mode,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Circular',
                  ),
                ),
              if (description != null)
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Circular',
                    color: Colors.black54,
                  ),
                ),
              if (buttonText != null)
                NeuTextButton(
                  borderRadius: BorderRadius.circular(8),
                  buttonColor: const Color(0xFF7DF9FF),
                  buttonHeight: 40,
                  buttonWidth: 80,
                  onPressed: onPressed,
                  enableAnimation: true,
                  text: Text(
                    buttonText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Circular',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flashCardSection(
    BuildContext context,
    String languageName,
    int topWordsCount,
  ) {
    return _buildCard(
      context,
      mode: 'Flashcards',
      buttonText: 'Start',
      onPressed: () => context.push('/flashcard'),
      description:
          'Speak immediately: hear each word, repeat it, then reveal the meaning. Built from the top $topWordsCount most-used $languageName words.',
      height: MediaQuery.of(context).size.height / 5,
    );
  }

  Widget _speakingSection(BuildContext context) {
    return _buildCard(
      context,
      mode: 'Speaking',
      buttonText: 'Speak',
      onPressed: () => context.push('/speak'),
      description:
          'Practice speaking by repeating after the narrator. Tap to play or pause the audio anytime.',
      height: MediaQuery.of(context).size.height / 5,
    );
  }

  Widget _listeningSection(BuildContext context) {
    return _buildCard(
      context,
      mode: 'Listening Match',
      buttonText: 'Play',
      onPressed: () => context.push('/listening'),
      description:
          'Duolingo-style listening practice: hear a word and match it to the right meaning.',
      height: MediaQuery.of(context).size.height / 5,
    );
  }

  Widget _readingSection(BuildContext context, String readingText) {
    final condensedText =
        readingText.length > 130
            ? '${readingText.substring(0, 130)}...'
            : readingText;

    return _buildCard(
      context,
      mode: 'Daily Reading',
      description: condensedText,
      height: MediaQuery.of(context).size.height / 5,
    );
  }
}

/// Animated circular ring showing vocabulary mastery (studied / total).
class _VocabularyProgressCard extends StatelessWidget {
  final int studied;
  final int total;
  final String languageName;

  const _VocabularyProgressCard({
    required this.studied,
    required this.total,
    required this.languageName,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : (studied / total).clamp(0.0, 1.0);
    final percentLabel = '${(pct * 100).toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: NeuContainer(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              // Ring
              SizedBox(
                width: 100,
                height: 100,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOut,
                  builder: (context, value, _) {
                    return CustomPaint(
                      painter: _RingPainter(value),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              percentLabel,
                              style: const TextStyle(
                                fontFamily: 'Circular',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const Text(
                              'done',
                              style: TextStyle(
                                fontFamily: 'Circular',
                                fontSize: 11,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 20),
              // Text info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$languageName Vocabulary',
                      style: const TextStyle(
                        fontFamily: 'Circular',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$studied of $total core words mastered',
                      style: const TextStyle(
                        fontFamily: 'Circular',
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF7DF9FF),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  const _RingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const strokeWidth = 8.0;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.grey.shade200
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = const Color(0xFF7DF9FF)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
