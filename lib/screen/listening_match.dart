import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/core/content/mandarin_pinyin_lookup.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/flashcard/presentation/providers/flashcard_providers.dart';

const _kBg = Color(0xFFF5F5F0);
const _kCyan = Color(0xFF7DF9FF);
const _kYellow = Color(0xFFFFE566);
const _kMint = Color(0xFFB8F56A);
const _kPink = Color(0xFFFF9ECF);

class ListeningMatchScreen extends ConsumerStatefulWidget {
  const ListeningMatchScreen({super.key});

  @override
  ConsumerState<ListeningMatchScreen> createState() =>
      _ListeningMatchScreenState();
}

class _ListeningQuestion {
  final String targetWord;
  final String correctMeaning;
  final List<String> wordOptions;
  final List<String> meaningOptions;

  const _ListeningQuestion({
    required this.targetWord,
    required this.correctMeaning,
    required this.wordOptions,
    required this.meaningOptions,
  });
}

class _ListeningMatchScreenState extends ConsumerState<ListeningMatchScreen> {
  static const int _questionCount = 10;
  final Random _random = Random();
  late final FlutterTts _tts;

  List<_ListeningQuestion> _questions = const [];
  int _index = 0;
  int _score = 0;
  bool _isLoading = true;
  bool _isSpeaking = false;
  bool _answered = false;
  String? _selectedWord;
  String? _selectedMeaning;
  bool? _wasCorrect;
  Map<String, String> _pinyinByWord = const {};

  @override
  void initState() {
    super.initState();

    _tts = FlutterTts();
    _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (!mounted) return;
      setState(() => _isSpeaking = false);
    });

    MandarinPinyinLookup.load().then((map) {
      if (!mounted) return;
      setState(() => _pinyinByWord = map);
    });

    _loadQuestions();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final box = ref.read(flashcardBoxProvider);

    final pool = box.values
        .where((card) => card.word.trim().isNotEmpty)
        .where((card) => !_isPlaceholderMeaning(card.meaning))
        .toList(growable: false);

    if (pool.length < 8) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _questions = const [];
      });
      return;
    }

    final shuffledPool = [...pool]..shuffle(_random);
    final picked = shuffledPool.take(_questionCount).toList(growable: false);

    final built = <_ListeningQuestion>[];
    for (final card in picked) {
      final targetWord = card.word.trim();
      final correctMeaning = card.meaning.trim();

      final wordDistractors = pool
        .where((item) => item.word.trim() != targetWord)
        .map((item) => item.word.trim())
        .where((word) => word.isNotEmpty)
        .toSet()
        .toList(growable: false)..shuffle(_random);

      final meaningDistractors = pool
        .where((item) => item.meaning.trim() != correctMeaning)
        .map((item) => item.meaning.trim())
        .where((meaning) => meaning.isNotEmpty)
        .toSet()
        .toList(growable: false)..shuffle(_random);

      final wordOptions = <String>[targetWord, ...wordDistractors.take(3)]
        ..shuffle(_random);
      final meaningOptions = <String>[
        correctMeaning,
        ...meaningDistractors.take(3),
      ]..shuffle(_random);

      if (wordOptions.length < 4 || meaningOptions.length < 4) continue;

      built.add(
        _ListeningQuestion(
          targetWord: targetWord,
          correctMeaning: correctMeaning,
          wordOptions: wordOptions,
          meaningOptions: meaningOptions,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _questions = built;
      _index = 0;
      _score = 0;
      _isLoading = false;
      _answered = false;
      _selectedWord = null;
      _selectedMeaning = null;
      _wasCorrect = null;
    });
  }

  bool _isPlaceholderMeaning(String meaning) {
    final value = meaning.trim();
    if (value.isEmpty) return true;
    return value == '?' ||
        value == '？' ||
        value == '-' ||
        value == '—' ||
        value == '...' ||
        value.startsWith('meaning:');
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

  Future<void> _speak(String text) async {
    final languageCode = ref
        .read(userLearningLanguageProvider)
        .maybeWhen(data: (code) => code, orElse: () => 'fr');

    await _tts.stop();
    await _tts.setLanguage(_ttsLocaleFromLanguage(languageCode));
    await _tts.setSpeechRate(0.42);
    if (!mounted) return;
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  Future<void> _playPrompt() async {
    if (_questions.isEmpty || _index >= _questions.length) return;
    await _speak(_questions[_index].targetWord);
  }

  Future<void> _selectWord(String word) async {
    if (_answered || _questions.isEmpty || _index >= _questions.length) return;
    setState(() => _selectedWord = word);
    await _speak(word);
  }

  Future<void> _selectMeaning(String meaning) async {
    if (_answered || _questions.isEmpty || _index >= _questions.length) return;
    if (_selectedWord == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tap a word card first.')));
      return;
    }

    final question = _questions[_index];
    final isCorrect =
        _selectedWord == question.targetWord &&
        meaning == question.correctMeaning;

    setState(() {
      _selectedMeaning = meaning;
      _answered = true;
      _wasCorrect = isCorrect;
      if (isCorrect) _score += 1;
    });

    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;

    if (_index >= _questions.length - 1) {
      setState(() {
        _index = _questions.length;
      });
      return;
    }

    setState(() {
      _index += 1;
      _answered = false;
      _selectedWord = null;
      _selectedMeaning = null;
      _wasCorrect = null;
    });
  }

  Color _feedbackColor() {
    if (_wasCorrect == null) return Colors.white;
    return _wasCorrect! ? _kMint : _kPink;
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = ref
        .watch(userLearningLanguageProvider)
        .maybeWhen(data: (code) => code, orElse: () => 'fr');
    final language = languageOptionByCode(languageCode);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(title: const Text('Listening Match')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Not enough flashcards with meanings yet. Study or sync your deck, then try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_index >= _questions.length) {
      return Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _kCyan,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(offset: Offset(5, 5), color: Colors.black),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_rounded, size: 58),
                    const SizedBox(height: 10),
                    const Text(
                      'Session Complete',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Score: $_score / ${_questions.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: _kCyan,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      onPressed: _loadQuestions,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Play Again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final question = _questions[_index];

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: _kCyan,
                border: Border.all(color: Colors.black, width: 2.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${language.flag} Listening Match ${_index + 1}/${_questions.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pick a word card, hear its pronunciation, then choose its meaning.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Panel(
                      color: _kYellow,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Score: $_score',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: _kYellow,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                            ),
                            onPressed: _isSpeaking ? null : _playPrompt,
                            icon: const Icon(Icons.volume_up_rounded),
                            label: Text(
                              _isSpeaking ? 'Playing...' : 'Play Prompt',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Panel(
                      color: _feedbackColor(),
                      child: Text(
                        _wasCorrect == null
                            ? 'Step 1: tap a word card. Step 2: tap the matching meaning.'
                            : (_wasCorrect!
                                ? 'Correct pair!'
                                : 'Incorrect pair. Prompt word: ${question.targetWord}'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Words',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: question.wordOptions
                          .map((word) {
                            final selected = _selectedWord == word;
                            final pinyin =
                                languageCode == 'zh'
                                    ? (_pinyinByWord[word.trim()] ?? '')
                                    : '';
                            return _SelectableCard(
                              label: word,
                              sublabel: pinyin,
                              selected: selected,
                              accent: _kCyan,
                              onTap: () => _selectWord(word),
                            );
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Meanings',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: question.meaningOptions
                              .map((meaning) {
                                final selected = _selectedMeaning == meaning;
                                return _SelectableCard(
                                  label: meaning,
                                  selected: selected,
                                  accent: _kYellow,
                                  onTap: () => _selectMeaning(meaning),
                                  maxWidth:
                                      MediaQuery.of(context).size.width - 40,
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Color color;
  final Widget child;

  const _Panel({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
      ),
      child: child,
    );
  }
}

class _SelectableCard extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final double? maxWidth;

  const _SelectableCard({
    required this.label,
    this.sublabel,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = selected ? Colors.black : Colors.white;
    final textColor = selected ? accent : Colors.black;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 260),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [
              BoxShadow(offset: Offset(3, 3), color: Colors.black),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              if ((sublabel ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  sublabel!.trim(),
                  style: TextStyle(
                    color:
                        selected
                            ? accent.withValues(alpha: 0.8)
                            : Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
