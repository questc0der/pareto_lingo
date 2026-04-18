import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:neubrutalism_ui/neubrutalism_ui.dart';
import 'package:pareto_lingo/core/content/mandarin_pinyin_lookup.dart';
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
  String _sessionLanguageCode = 'fr';
  String? _lastAutoSpokenCardId;
  bool _isSpeaking = false;
  bool _speechEnabled = false;
  bool _isListening = false;
  String _recognizedPhrase = '';
  int? _pronunciationScore;
  Map<String, String> _pinyinByWord = const {};
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  late final FlutterTts _tts;
  late final SpeechToText _speechToText;

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

    _tts = FlutterTts();
    _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });
    _tts.setCancelHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });

    _speechToText = SpeechToText();
    _initializeSpeechRecognition();
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
    _sessionLanguageCode = languageCode;
    if (languageCode == 'zh') {
      MandarinPinyinLookup.load().then((map) {
        if (!mounted) return;
        setState(() => _pinyinByWord = map);
      });
    }

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
    _stopListening();
    _tts.stop();
    _flipController.dispose();
    super.dispose();
  }

  void _revealWithAnimation(FlashcardSessionController controller) async {
    await _flipController.forward();
    controller.revealAnswer();
  }

  void _onRate(FlashcardSessionController controller, int quality) {
    _stopListening();
    setState(() {
      _recognizedPhrase = '';
      _pronunciationScore = null;
    });
    _flipController.reset();
    controller.rateCurrent(quality: quality);
  }

  Future<void> _initializeSpeechRecognition() async {
    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' || status == 'done') {
          setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
    );

    if (!mounted) return;
    setState(() => _speechEnabled = available);
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _speechToText.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  Future<void> _toggleRepeatListening(String targetWord) async {
    if (_isListening) {
      await _stopListening();
      return;
    }

    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition is unavailable on this device.'),
        ),
      );
      return;
    }

    setState(() {
      _recognizedPhrase = '';
      _pronunciationScore = null;
    });

    final localeId = _sttLocaleFromLanguage(_sessionLanguageCode);
    final didStart = await _speechToText.listen(
      localeId: localeId,
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 2),
      listenOptions: SpeechListenOptions(partialResults: true),
      onResult: (result) {
        if (!mounted) return;
        final recognized = result.recognizedWords.trim();
        if (recognized.isEmpty) return;

        setState(() {
          _recognizedPhrase = recognized;
          _pronunciationScore = _computePronunciationScore(
            expected: targetWord,
            recognized: recognized,
          );

          if (result.finalResult) {
            _isListening = false;
          }
        });
      },
    );

    if (!mounted) return;
    setState(() => _isListening = didStart);
  }

  Future<void> _speakWord(String word) async {
    final text = word.trim();
    if (text.isEmpty) return;

    await _tts.stop();
    await _tts.setLanguage(_ttsLocaleFromLanguage(_sessionLanguageCode));
    await _tts.setSpeechRate(0.43);
    if (!mounted) return;
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  Future<void> _speakMeaning(String meaning) async {
    final text = meaning.trim();
    if (text.isEmpty) return;

    await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    if (!mounted) return;
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  String _ttsLocaleFromLanguage(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'fr':
        return 'fr-FR';
      case 'zh':
        return 'zh-CN';
      case 'en':
        return 'en-US';
      default:
        return 'en-US';
    }
  }

  String _sttLocaleFromLanguage(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'fr':
        return 'fr-FR';
      case 'zh':
        return 'zh-CN';
      case 'en':
        return 'en-US';
      default:
        return 'en-US';
    }
  }

  int _computePronunciationScore({
    required String expected,
    required String recognized,
  }) {
    final expectedNorm = _normalizeForComparison(expected);
    final recognizedNorm = _normalizeForComparison(recognized);

    if (expectedNorm.isEmpty || recognizedNorm.isEmpty) return 0;
    if (expectedNorm == recognizedNorm) return 100;

    final recognizedTokens = recognizedNorm
        .split(' ')
        .where((t) => t.isNotEmpty);
    final candidates = <String>[recognizedNorm, ...recognizedTokens];

    var bestScore = 0;
    for (final candidate in candidates) {
      final maxLen =
          expectedNorm.length > candidate.length
              ? expectedNorm.length
              : candidate.length;
      if (maxLen == 0) continue;

      final distance = _levenshteinDistance(expectedNorm, candidate);
      final similarity = ((maxLen - distance) / maxLen).clamp(0.0, 1.0);
      final score = (similarity * 100).round();
      if (score > bestScore) {
        bestScore = score;
      }
    }

    return bestScore;
  }

  String _normalizeForComparison(String input) {
    final accentsReplaced = input
        .toLowerCase()
        .replaceAll(RegExp('[àáâãäå]'), 'a')
        .replaceAll(RegExp('[èéêë]'), 'e')
        .replaceAll(RegExp('[ìíîï]'), 'i')
        .replaceAll(RegExp('[òóôõö]'), 'o')
        .replaceAll(RegExp('[ùúûü]'), 'u')
        .replaceAll(RegExp('[ç]'), 'c')
        .replaceAll(RegExp('[ñ]'), 'n')
        .replaceAll(RegExp('[ß]'), 'ss');

    return accentsReplaced
        .replaceAll(RegExp('[^a-z0-9\\s\'-]'), ' ')
        .replaceAll(RegExp('\\s+'), ' ')
        .trim();
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final previous = List<int>.generate(b.length + 1, (i) => i);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        current[j] = [
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }

      for (var j = 0; j <= b.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous[b.length];
  }

  String _scoreLabel(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 55) return 'Keep going';
    return 'Try again';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FlashcardSessionState>(flashcardSessionControllerProvider, (
      previous,
      next,
    ) {
      final card = next.currentCard;
      if (card != null &&
          !next.showAnswer &&
          !next.isLoading &&
          card.id != _lastAutoSpokenCardId) {
        _lastAutoSpokenCardId = card.id;
        _stopListening();
        setState(() {
          _recognizedPhrase = '';
          _pronunciationScore = null;
        });
        _speakWord(card.word);
      }

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
                            if (!state.showAnswer &&
                                _sessionLanguageCode == 'zh' &&
                                (_pinyinByWord[card.word.trim()] ?? '')
                                    .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _pinyinByWord[card.word.trim()]!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Circular',
                                  color: Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed:
                                      _isSpeaking
                                          ? null
                                          : () => _speakWord(card.word),
                                  icon: const Icon(Icons.volume_up_rounded),
                                  label: const Text('Listen Word'),
                                ),
                                if (state.showAnswer)
                                  OutlinedButton.icon(
                                    onPressed:
                                        _isSpeaking
                                            ? null
                                            : () => _speakMeaning(card.meaning),
                                    icon: const Icon(
                                      Icons.record_voice_over_rounded,
                                    ),
                                    label: const Text('Listen Meaning'),
                                  ),
                              ],
                            ),
                            if (!state.showAnswer) ...[
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed:
                                    _isSpeaking
                                        ? null
                                        : () =>
                                            _toggleRepeatListening(card.word),
                                icon: Icon(
                                  _isListening
                                      ? Icons.stop_circle_outlined
                                      : Icons.mic_none_rounded,
                                ),
                                label: Text(
                                  _isListening
                                      ? 'Stop Listening'
                                      : 'Repeat After Audio',
                                ),
                              ),
                              if (_recognizedPhrase.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'You said: "$_recognizedPhrase"',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    fontFamily: 'Circular',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              if (_pronunciationScore != null) ...[
                                const SizedBox(height: 8),
                                _buildPronunciationScoreBadge(
                                  _pronunciationScore!,
                                ),
                              ],
                            ],
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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

  Widget _buildPronunciationScoreBadge(int score) {
    final clamped = score.clamp(0, 100);
    final color = Color.lerp(Colors.red, Colors.green, clamped / 100)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        'Pronunciation: $clamped% • ${_scoreLabel(clamped)}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontFamily: 'Circular',
        ),
      ),
    );
  }
}
