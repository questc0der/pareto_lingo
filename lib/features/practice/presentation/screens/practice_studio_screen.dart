import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive/hive.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/engagement/presentation/providers/engagement_providers.dart';
import 'package:pareto_lingo/models/flashcard_model.dart';

const _kBg = Color(0xFFF5F5F0);
const _kCyan = Color(0xFF7DF9FF);
const _kYellow = Color(0xFFFFE566);
const _kMint = Color(0xFFB8F56A);

class PracticeStudioScreen extends ConsumerStatefulWidget {
  const PracticeStudioScreen({super.key});

  @override
  ConsumerState<PracticeStudioScreen> createState() => _PracticeStudioScreenState();
}

class _PracticeStudioScreenState extends ConsumerState<PracticeStudioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final FlutterTts _tts;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tts = FlutterTts();
    _tts.awaitSpeakCompletion(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      markDailyEngagement(ref);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String languageCode, String text) async {
    final locale = switch (languageCode) {
      'fr' => 'fr-FR',
      'zh' => 'zh-CN',
      'en' => 'en-US',
      _ => 'en-US',
    };
    await _tts.stop();
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(0.43);
    await _tts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = ref
        .watch(userLearningLanguageProvider)
        .maybeWhen(data: (code) => code, orElse: () => 'fr');
    final language = languageOptionByCode(languageCode);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: _kMint,
                border: Border(bottom: BorderSide(color: Colors.black, width: 2.5)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${language.flag} Practice Studio',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Beginner-first dialogues and active recall challenges',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: _kCyan,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.black54,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                      tabs: const [
                        Tab(text: 'Mini-Dialogues'),
                        Tab(text: 'Active Recall'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _DialoguesTab(
                    languageCode: languageCode,
                    onSpeak: (text) => _speak(languageCode, text),
                  ),
                  _ActiveRecallTab(languageCode: languageCode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogueLine {
  final bool speakerA;
  final String target;
  final String english;

  const _DialogueLine({
    required this.speakerA,
    required this.target,
    required this.english,
  });
}

class _Scenario {
  final String id;
  final String title;
  final String subtitle;
  final List<_DialogueLine> fr;
  final List<_DialogueLine> zh;
  final List<_DialogueLine> en;

  const _Scenario({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.fr,
    required this.zh,
    required this.en,
  });

  List<_DialogueLine> linesFor(String code) {
    return switch (code) {
      'fr' => fr,
      'zh' => zh,
      'en' => en,
      _ => en,
    };
  }
}

const _scenarios = <_Scenario>[
  _Scenario(
    id: 'food',
    title: 'Ordering Food',
    subtitle: 'Cafe and restaurant basics',
    fr: [
      _DialogueLine(speakerA: true, target: 'Bonjour, je veux un café.', english: 'Hello, I want a coffee.'),
      _DialogueLine(speakerA: false, target: 'Avec lait ou sans lait?', english: 'With milk or without milk?'),
      _DialogueLine(speakerA: true, target: 'Avec lait, s\'il vous plaît.', english: 'With milk, please.'),
      _DialogueLine(speakerA: false, target: 'Très bien. C\'est cinq euros.', english: 'Great. That is five euros.'),
    ],
    zh: [
      _DialogueLine(speakerA: true, target: '你好，我要一杯咖啡。', english: 'Hello, I want a coffee.'),
      _DialogueLine(speakerA: false, target: '要牛奶吗？', english: 'Do you want milk?'),
      _DialogueLine(speakerA: true, target: '要，谢谢。', english: 'Yes, thank you.'),
      _DialogueLine(speakerA: false, target: '好的，一共五块。', english: 'Okay, total is five.'),
    ],
    en: [
      _DialogueLine(speakerA: true, target: 'Hello, I want a coffee.', english: 'Hello, I want a coffee.'),
      _DialogueLine(speakerA: false, target: 'With milk or without milk?', english: 'With milk or without milk?'),
      _DialogueLine(speakerA: true, target: 'With milk, please.', english: 'With milk, please.'),
      _DialogueLine(speakerA: false, target: 'Great. That is five dollars.', english: 'Great. That is five dollars.'),
    ],
  ),
  _Scenario(
    id: 'directions',
    title: 'Asking Directions',
    subtitle: 'Get around with confidence',
    fr: [
      _DialogueLine(speakerA: true, target: 'Excusez-moi, où est la gare?', english: 'Excuse me, where is the station?'),
      _DialogueLine(speakerA: false, target: 'La gare est à droite.', english: 'The station is on the right.'),
      _DialogueLine(speakerA: true, target: 'C\'est loin?', english: 'Is it far?'),
      _DialogueLine(speakerA: false, target: 'Non, cinq minutes à pied.', english: 'No, five minutes on foot.'),
    ],
    zh: [
      _DialogueLine(speakerA: true, target: '请问，车站在哪里？', english: 'Excuse me, where is the station?'),
      _DialogueLine(speakerA: false, target: '车站在右边。', english: 'The station is on the right.'),
      _DialogueLine(speakerA: true, target: '远吗？', english: 'Is it far?'),
      _DialogueLine(speakerA: false, target: '不远，走路五分钟。', english: 'Not far, five minutes by foot.'),
    ],
    en: [
      _DialogueLine(speakerA: true, target: 'Excuse me, where is the station?', english: 'Excuse me, where is the station?'),
      _DialogueLine(speakerA: false, target: 'The station is on the right.', english: 'The station is on the right.'),
      _DialogueLine(speakerA: true, target: 'Is it far?', english: 'Is it far?'),
      _DialogueLine(speakerA: false, target: 'No, five minutes on foot.', english: 'No, five minutes on foot.'),
    ],
  ),
  _Scenario(
    id: 'intro',
    title: 'Introducing Yourself',
    subtitle: 'Meet people naturally',
    fr: [
      _DialogueLine(speakerA: true, target: 'Salut, je m\'appelle Alex.', english: 'Hi, my name is Alex.'),
      _DialogueLine(speakerA: false, target: 'Enchanté, moi c\'est Lina.', english: 'Nice to meet you, I am Lina.'),
      _DialogueLine(speakerA: true, target: 'Je suis étudiant.', english: 'I am a student.'),
      _DialogueLine(speakerA: false, target: 'Moi aussi, à bientôt!', english: 'Me too, see you soon!'),
    ],
    zh: [
      _DialogueLine(speakerA: true, target: '你好，我叫Alex。', english: 'Hi, my name is Alex.'),
      _DialogueLine(speakerA: false, target: '很高兴认识你，我叫Lina。', english: 'Nice to meet you, I am Lina.'),
      _DialogueLine(speakerA: true, target: '我是学生。', english: 'I am a student.'),
      _DialogueLine(speakerA: false, target: '我也是，回头见！', english: 'Me too, see you!'),
    ],
    en: [
      _DialogueLine(speakerA: true, target: 'Hi, my name is Alex.', english: 'Hi, my name is Alex.'),
      _DialogueLine(speakerA: false, target: 'Nice to meet you, I am Lina.', english: 'Nice to meet you, I am Lina.'),
      _DialogueLine(speakerA: true, target: 'I am a student.', english: 'I am a student.'),
      _DialogueLine(speakerA: false, target: 'Me too, see you soon!', english: 'Me too, see you soon!'),
    ],
  ),
];

class _DialoguesTab extends StatefulWidget {
  final String languageCode;
  final ValueChanged<String> onSpeak;

  const _DialoguesTab({required this.languageCode, required this.onSpeak});

  @override
  State<_DialoguesTab> createState() => _DialoguesTabState();
}

class _DialoguesTabState extends State<_DialoguesTab> {
  int _scenarioIndex = 0;
  bool _roleA = true;
  final Set<int> _translated = <int>{};

  @override
  Widget build(BuildContext context) {
    final scenario = _scenarios[_scenarioIndex];
    final lines = scenario.linesFor(widget.languageCode);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _scenarios.length; i++)
              _chip(
                label: _scenarios[i].title,
                selected: _scenarioIndex == i,
                onTap: () {
                  setState(() {
                    _scenarioIndex = i;
                    _translated.clear();
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  scenario.subtitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              _chip(
                label: _roleA ? 'Practice A side' : 'Practice B side',
                selected: true,
                onTap: () => setState(() => _roleA = !_roleA),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < lines.length; i++)
          _DialogueBubble(
            line: lines[i],
            isUserSide: lines[i].speakerA == _roleA,
            showTranslation: _translated.contains(i),
            onToggleTranslation: () {
              setState(() {
                if (_translated.contains(i)) {
                  _translated.remove(i);
                } else {
                  _translated.add(i);
                }
              });
            },
            onSpeak: () => widget.onSpeak(lines[i].target),
          ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kCyan : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: selected
              ? const [BoxShadow(offset: Offset(2, 2), color: Colors.black)]
              : null,
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}

class _DialogueBubble extends StatelessWidget {
  final _DialogueLine line;
  final bool isUserSide;
  final bool showTranslation;
  final VoidCallback onToggleTranslation;
  final VoidCallback onSpeak;

  const _DialogueBubble({
    required this.line,
    required this.isUserSide,
    required this.showTranslation,
    required this.onToggleTranslation,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isUserSide ? _kYellow : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [BoxShadow(offset: Offset(2, 2), color: Colors.black)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isUserSide ? 'Your line' : 'Partner line',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.volume_up_rounded, size: 20),
                onPressed: onSpeak,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.translate_rounded, size: 20),
                onPressed: onToggleTranslation,
              ),
            ],
          ),
          Text(
            line.target,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (showTranslation) ...[
            const SizedBox(height: 6),
            Text(
              line.english,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveRecallTab extends StatefulWidget {
  final String languageCode;

  const _ActiveRecallTab({required this.languageCode});

  @override
  State<_ActiveRecallTab> createState() => _ActiveRecallTabState();
}

class _ActiveRecallTabState extends State<_ActiveRecallTab> {
  final Random _random = Random();
  late Box<Flashcard> _box;

  int _modeIndex = 0;
  final TextEditingController _answerController = TextEditingController();
  bool _showHint = false;
  String _feedback = '';

  List<Flashcard> _pool = const [];
  Flashcard? _current;
  Timer? _timer;
  int _timeLeft = 60;
  int _timedScore = 0;
  bool _timedRunning = false;

  @override
  void initState() {
    super.initState();
    _box = Hive.box<Flashcard>('flashcards');
    _pool = _box.values.where((c) => c.word.trim().isNotEmpty).take(1000).toList();
    _nextQuestion();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _nextQuestion() {
    if (_pool.isEmpty) return;
    _answerController.clear();
    _showHint = false;
    _feedback = '';
    _current = _pool[_random.nextInt(_pool.length)];
    setState(() {});
  }

  bool _matches(String user, String expected) {
    return user.trim().toLowerCase() == expected.trim().toLowerCase();
  }

  void _checkAnswer() {
    final current = _current;
    if (current == null) return;

    final correct = _matches(_answerController.text, current.word);
    setState(() {
      _feedback = correct ? 'Correct!' : 'Not yet. Try again.';
    });

    if (correct) {
      if (_modeIndex == 2 && _timedRunning) {
        _timedScore += 1;
      }
      _nextQuestion();
    }
  }

  void _startTimedMode() {
    _timer?.cancel();
    setState(() {
      _modeIndex = 2;
      _timeLeft = 60;
      _timedScore = 0;
      _timedRunning = true;
      _feedback = '';
    });
    _nextQuestion();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft <= 1) {
        timer.cancel();
        setState(() {
          _timeLeft = 0;
          _timedRunning = false;
          _feedback = 'Time up! Score: $_timedScore';
        });
        return;
      }

      setState(() {
        _timeLeft -= 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;

    if (_pool.isEmpty || current == null) {
      return const Center(
        child: Text('No flashcards available yet.'),
      );
    }

    final prompt = switch (_modeIndex) {
      0 => 'Say this in target language: ${current.meaning}',
      1 => _fillBlankPrompt(current),
      _ => 'Timed recall: ${current.meaning}',
    };

    final firstChar = current.word.trim().isEmpty
      ? ''
      : current.word.trim().substring(0, 1);
    final hint = _modeIndex == 1
      ? 'Hint: word length ${current.word.length}'
      : 'Hint: starts with "$firstChar"';

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _modeChip('Say It', 0),
            _modeChip('Fill Blank', 1),
            _modeChip('Timed 60s', 2),
          ],
        ),
        const SizedBox(height: 12),
        if (_modeIndex == 2)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kYellow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Row(
              children: [
                Text('Time: $_timeLeft', style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('Score: $_timedScore', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _timedRunning ? null : _startTimedMode,
                  child: Text(_timedRunning ? 'Running' : 'Start'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: const [BoxShadow(offset: Offset(3, 3), color: Colors.black)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Challenge', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(prompt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: _answerController,
                decoration: const InputDecoration(
                  hintText: 'Type your answer…',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _checkAnswer(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton(onPressed: _checkAnswer, child: const Text('Check')),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => setState(() => _showHint = true),
                    child: const Text('Hint'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: _nextQuestion, child: const Text('Skip')),
                ],
              ),
              if (_showHint) ...[
                const SizedBox(height: 6),
                Text(hint, style: const TextStyle(color: Colors.black54)),
              ],
              if (_feedback.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _feedback,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _feedback.startsWith('Correct') ? Colors.green.shade700 : Colors.deepOrange,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeChip(String label, int index) {
    final selected = _modeIndex == index;
    return GestureDetector(
      onTap: () {
        _timer?.cancel();
        setState(() {
          _modeIndex = index;
          _timedRunning = false;
        });
        _nextQuestion();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kCyan : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }

  String _fillBlankPrompt(Flashcard card) {
    return switch (widget.languageCode) {
      'fr' => 'Complète: Je ___ français.',
      'zh' => '填空: 我___中文。',
      'en' => 'Fill: I ___ English.',
      _ => 'Fill in the blank.',
    };
  }
}
