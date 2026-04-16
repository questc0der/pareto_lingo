import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/flashcard/presentation/providers/flashcard_providers.dart';

class ListeningMatchScreen extends ConsumerStatefulWidget {
  const ListeningMatchScreen({super.key});

  @override
  ConsumerState<ListeningMatchScreen> createState() =>
      _ListeningMatchScreenState();
}

class _ListeningQuestion {
  final String word;
  final String correctMeaning;
  final List<String> options;

  const _ListeningQuestion({
    required this.word,
    required this.correctMeaning,
    required this.options,
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
  String? _selectedOption;

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

    if (pool.length < 4) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _questions = const [];
      });
      return;
    }

    final shuffledPool = [...pool]..shuffle(_random);
    final picked = shuffledPool.take(_questionCount).toList(growable: false);

    final allMeanings = pool
        .map((card) => card.meaning.trim())
        .where((meaning) => meaning.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final built = <_ListeningQuestion>[];
    for (final card in picked) {
      final correct = card.meaning.trim();
      final distractors = allMeanings
        .where((meaning) => meaning != correct)
        .toList(growable: false)..shuffle(_random);

      final options = <String>[correct, ...distractors.take(3)]
        ..shuffle(_random);

      if (options.length < 2) continue;

      built.add(
        _ListeningQuestion(
          word: card.word.trim(),
          correctMeaning: correct,
          options: options,
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
      _selectedOption = null;
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

  Future<void> _speakCurrentWord() async {
    if (_questions.isEmpty || _index >= _questions.length) return;

    final languageCode = ref
        .read(userLearningLanguageProvider)
        .maybeWhen(data: (code) => code, orElse: () => 'fr');

    await _tts.stop();
    await _tts.setLanguage(_ttsLocaleFromLanguage(languageCode));
    await _tts.setSpeechRate(0.42);

    if (!mounted) return;
    setState(() => _isSpeaking = true);
    await _tts.speak(_questions[_index].word);
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

  Future<void> _selectOption(String option) async {
    if (_answered || _questions.isEmpty || _index >= _questions.length) return;

    final question = _questions[_index];
    final isCorrect = option == question.correctMeaning;

    setState(() {
      _selectedOption = option;
      _answered = true;
      if (isCorrect) {
        _score += 1;
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));
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
      _selectedOption = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_questions.isEmpty) {
      return Scaffold(
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
        appBar: AppBar(title: const Text('Listening Match')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 52,
                  color: Colors.amber,
                ),
                const SizedBox(height: 12),
                Text(
                  'Score: $_score / ${_questions.length}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadQuestions,
                  child: const Text('Play Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _questions[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text('Listening Match ${_index + 1}/${_questions.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Listen and choose the correct meaning',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSpeaking ? null : _speakCurrentWord,
              icon: const Icon(Icons.volume_up_rounded),
              label: Text(_isSpeaking ? 'Playing...' : 'Play Audio'),
            ),
            const SizedBox(height: 18),
            ...question.options.map((option) {
              final isCorrect = option == question.correctMeaning;
              final isSelected = option == _selectedOption;
              final color =
                  !_answered
                      ? null
                      : isCorrect
                      ? Colors.green.shade100
                      : (isSelected ? Colors.red.shade100 : null);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    title: Text(option),
                    onTap: () => _selectOption(option),
                  ),
                ),
              );
            }),
            const Spacer(),
            Text(
              'Score: $_score',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
