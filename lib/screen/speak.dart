import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';

class Speak extends ConsumerStatefulWidget {
  const Speak({super.key});

  @override
  ConsumerState<Speak> createState() => _Shadowing();
}

class _Shadowing extends ConsumerState<Speak> {
  late final AudioPlayer player;
  final ScrollController _scrollController = ScrollController();

  int _selectedChapterIndex = 0;
  List<_TranscriptLineSeed> _sourceLines = const [];
  List<_TranscriptLine> _lines = const [];
  bool _hasReliableTimings = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = true;
  int _lastAutoScrollLine = -1;

  static const _rewind = Duration(seconds: 10);
  static const _forward = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    _loadChapter(0);

    player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _position = position;
      });
      _autoScrollActiveLine();
    });

    player.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      setState(() {
        _duration = duration;
        if (_sourceLines.isNotEmpty) {
          _lines = _buildAnchoredTimeline(_sourceLines);
        }
      });
    });

    player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  Future<void> _loadChapter(int index) async {
    if (index < 0 || index >= _chapters.length) return;
    final chapter = _chapters[index];

    if (mounted) {
      setState(() {
        _isLoading = true;
        _selectedChapterIndex = index;
        _position = Duration.zero;
        _duration = Duration.zero;
        _lastAutoScrollLine = -1;
      });
    }

    await player.stop();
    await player.setAsset(chapter.audioAsset);

    final sourceLines = _buildSeedLines(chapter.entries);

    if (!mounted) return;
    setState(() {
      _sourceLines = sourceLines;
      _lines = _buildAnchoredTimeline(sourceLines);
      _hasReliableTimings = true;
      _isLoading = false;
    });
  }

  List<_TranscriptLineSeed> _buildSeedLines(List<_ChapterEntry> entries) {
    if (entries.isEmpty) return const [];

    final built = <_TranscriptLineSeed>[];
    for (var i = 0; i < entries.length; i++) {
      final current = entries[i];
      final nextStart =
          i < entries.length - 1
              ? entries[i + 1].start.inMilliseconds
              : current.start.inMilliseconds + 4500;
      final startMs = current.start.inMilliseconds;
      final endMs = nextStart <= startMs ? startMs + 1000 : nextStart;

      built.addAll(_splitSeedIntoChunks(current.text, startMs, endMs));
    }

    return built;
  }

  List<_TranscriptLineSeed> _splitSeedIntoChunks(
    String text,
    int startMs,
    int endMs,
  ) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return const [];

    final totalSpanMs = (endMs - startMs).clamp(1, 1 << 30);
    final minChunkMs = 1200;

    final rawChunks =
        cleaned
            .split(RegExp(r'(?<=[\.!\?;:,])\s+'))
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();

    if (rawChunks.length <= 1 || totalSpanMs <= minChunkMs * 2) {
      return [
        _TranscriptLineSeed(
          text: cleaned,
          startMs: startMs,
          endMs: endMs,
          hasTiming: true,
          weight: _wordWeight(cleaned),
        ),
      ];
    }

    final chunkWeights = rawChunks.map(_wordWeight).toList();
    final totalWeight = chunkWeights.fold<int>(0, (sum, w) => sum + w);
    final safeWeight = totalWeight <= 0 ? rawChunks.length : totalWeight;

    final seeds = <_TranscriptLineSeed>[];
    var cursor = startMs;

    for (var i = 0; i < rawChunks.length; i++) {
      final isLast = i == rawChunks.length - 1;
      final span =
          isLast
              ? endMs - cursor
              : ((chunkWeights[i] / safeWeight) * totalSpanMs).round();

      final boundedSpan = span.clamp(minChunkMs, totalSpanMs);
      final chunkStart = cursor;
      final chunkEnd =
          isLast ? endMs : (cursor + boundedSpan).clamp(chunkStart + 1, endMs);

      seeds.add(
        _TranscriptLineSeed(
          text: rawChunks[i],
          startMs: chunkStart,
          endMs: chunkEnd,
          hasTiming: true,
          weight: chunkWeights[i],
        ),
      );

      cursor = chunkEnd;
      if (cursor >= endMs) {
        break;
      }
    }

    if (seeds.isEmpty) {
      return [
        _TranscriptLineSeed(
          text: cleaned,
          startMs: startMs,
          endMs: endMs,
          hasTiming: true,
          weight: _wordWeight(cleaned),
        ),
      ];
    }

    return seeds;
  }

  int get _activeLineIndex {
    if (_lines.isEmpty) return 0;

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (_position >= line.start && _position <= line.end) {
        return i;
      }
    }

    var nearest = 0;
    var bestDiff = (_lines.first.start - _position).abs();
    for (var i = 1; i < _lines.length; i++) {
      final diff = (_lines[i].start - _position).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        nearest = i;
      }
    }

    return nearest;
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> _seekRelative(Duration delta) async {
    final target = _position + delta;
    final bounded =
        target < Duration.zero
            ? Duration.zero
            : (target > _duration ? _duration : target);
    await player.seek(bounded);
  }

  Future<void> _seekByLine(int lineIndex) async {
    if (_lines.isEmpty) return;
    await player.seek(_lines[lineIndex].start);
  }

  void _autoScrollActiveLine() {
    if (!_scrollController.hasClients || _lines.isEmpty) return;
    final active = _activeLineIndex;
    if (active == _lastAutoScrollLine) return;
    _lastAutoScrollLine = active;

    final target = (active * 74.0) - 150;
    final max = _scrollController.position.maxScrollExtent;
    final offset = target.clamp(0.0, max);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = ref
        .watch(userLearningLanguageProvider)
        .maybeWhen(
          data: (code) => code,
          orElse: () => ref.watch(selectedLearningLanguageProvider),
        );
    final language = languageOptionByCode(languageCode);
    final theme = Theme.of(context);
    final selectedChapter = _chapters[_selectedChapterIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Speaking Practice')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surfaceContainer,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book: La Ratatouille folle',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chapter: ${selectedChapter.title}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _chapters.length; i++)
                      ChoiceChip(
                        label: Text(_chapters[i].title),
                        selected: i == _selectedChapterIndex,
                        onSelected: (selected) {
                          if (!selected || i == _selectedChapterIndex) return;
                          _loadChapter(i);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Language: ${language.name} ${language.flag}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  _hasReliableTimings
                      ? 'Sync: chapter timestamps'
                      : 'Sync: weighted by text length',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(_fmt(_position), style: theme.textTheme.labelMedium),
                    Expanded(
                      child: Slider(
                        value:
                            _duration.inMilliseconds <= 0
                                ? 0
                                : _position.inMilliseconds
                                    .clamp(0, _duration.inMilliseconds)
                                    .toDouble(),
                        min: 0,
                        max:
                            _duration.inMilliseconds <= 0
                                ? 1
                                : _duration.inMilliseconds.toDouble(),
                        onChanged:
                            _duration.inMilliseconds <= 0
                                ? null
                                : (value) async {
                                  await player.seek(
                                    Duration(milliseconds: value.round()),
                                  );
                                },
                      ),
                    ),
                    Text(_fmt(_duration), style: theme.textTheme.labelMedium),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => _seekRelative(-_rewind),
                      icon: const Icon(Icons.replay_10_rounded),
                      tooltip: 'Back 10s',
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(_isPlaying ? 'Pause' : 'Play'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _seekRelative(_forward),
                      icon: const Icon(Icons.forward_10_rounded),
                      tooltip: 'Forward 10s',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      itemCount: _lines.length,
                      itemBuilder: (context, index) {
                        final isActive = index == _activeLineIndex;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _seekByLine(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color:
                                  isActive
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surface,
                              border: Border.all(
                                color:
                                    isActive
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fmt(_lines[index].start),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _lines[index].text,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontFamily: 'Circular',
                                    height: 1.35,
                                    fontWeight:
                                        isActive
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  int _wordWeight(String text) {
    final words = text.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return words.length.clamp(1, 40).toInt();
  }

  int _effectiveTotalMs(List<_TranscriptLineSeed> lines) {
    final maxKnown = lines
        .where((line) => line.hasTiming)
        .fold<int>(0, (m, line) => line.endMs > m ? line.endMs : m);

    if (_duration.inMilliseconds > 0) {
      return _duration.inMilliseconds;
    }

    final weightedFallback = lines.fold<int>(
      0,
      (sum, line) => sum + (line.weight * 450),
    );
    return [maxKnown, weightedFallback, 1000].reduce((a, b) => a > b ? a : b);
  }

  List<_TranscriptLine> _buildAnchoredTimeline(
    List<_TranscriptLineSeed> lines,
  ) {
    if (lines.isEmpty) {
      return const [];
    }

    final totalMillis = _effectiveTotalMs(lines);
    final starts = List<int>.filled(lines.length, 0);
    final ends = List<int>.filled(lines.length, 0);

    final knownIndices = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].hasTiming) {
        knownIndices.add(i);
        starts[i] = lines[i].startMs.clamp(0, totalMillis);
        ends[i] = lines[i].endMs.clamp(0, totalMillis);
      }
    }

    if (knownIndices.isEmpty) {
      return _buildPureWeightedTimeline(lines, totalMillis);
    }

    void fillWeightedRange({
      required int fromIndex,
      required int toIndex,
      required int startMs,
      required int endMs,
    }) {
      if (fromIndex > toIndex) return;

      final span = (endMs - startMs).clamp(1, totalMillis);
      final weights = [
        for (var i = fromIndex; i <= toIndex; i++) lines[i].weight,
      ];
      final sum = weights.fold<int>(0, (a, b) => a + b).clamp(1, 1 << 30);

      var cursor = startMs;
      for (var i = fromIndex; i <= toIndex; i++) {
        final isLast = i == toIndex;
        final part =
            isLast
                ? (startMs + span - cursor)
                : ((weights[i - fromIndex] / sum) * span).round();
        final safePart = part.clamp(1, span);

        starts[i] = cursor.clamp(0, totalMillis);
        cursor = (cursor + safePart).clamp(0, totalMillis);
        ends[i] = cursor;

        if (ends[i] <= starts[i]) {
          ends[i] = (starts[i] + 1).clamp(0, totalMillis);
        }
      }
    }

    final firstKnown = knownIndices.first;
    fillWeightedRange(
      fromIndex: 0,
      toIndex: firstKnown - 1,
      startMs: 0,
      endMs: starts[firstKnown],
    );

    for (var k = 0; k < knownIndices.length - 1; k++) {
      final left = knownIndices[k];
      final right = knownIndices[k + 1];

      if (right == left + 1) {
        continue;
      }

      fillWeightedRange(
        fromIndex: left + 1,
        toIndex: right - 1,
        startMs: ends[left],
        endMs: starts[right],
      );
    }

    final lastKnown = knownIndices.last;
    fillWeightedRange(
      fromIndex: lastKnown + 1,
      toIndex: lines.length - 1,
      startMs: ends[lastKnown],
      endMs: totalMillis,
    );

    return [
      for (var i = 0; i < lines.length; i++)
        _TranscriptLine(
          text: lines[i].text,
          start: Duration(milliseconds: starts[i]),
          end: Duration(milliseconds: ends[i]),
          hasTiming: lines[i].hasTiming,
          weight: lines[i].weight,
        ),
    ];
  }

  List<_TranscriptLine> _buildPureWeightedTimeline(
    List<_TranscriptLineSeed> lines,
    int totalMillis,
  ) {
    final totalWeight = lines.fold<int>(0, (sum, line) => sum + line.weight);
    final safeTotalWeight = totalWeight <= 0 ? lines.length : totalWeight;

    var cursor = 0;
    final weighted = <_TranscriptLine>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final spanMillis =
          i == lines.length - 1
              ? totalMillis - cursor
              : ((line.weight / safeTotalWeight) * totalMillis).round();

      final start = Duration(milliseconds: cursor.clamp(0, totalMillis));
      cursor += spanMillis.clamp(1, totalMillis);
      final end = Duration(milliseconds: cursor.clamp(1, totalMillis));

      weighted.add(
        _TranscriptLine(
          text: line.text,
          start: start,
          end: end,
          hasTiming: false,
          weight: line.weight,
        ),
      );
    }

    return weighted;
  }
}

class _TranscriptLineSeed {
  final String text;
  final int startMs;
  final int endMs;
  final bool hasTiming;
  final int weight;

  const _TranscriptLineSeed({
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.hasTiming,
    required this.weight,
  });
}

class _TranscriptLine {
  final String text;
  final Duration start;
  final Duration end;
  final bool hasTiming;
  final int weight;

  const _TranscriptLine({
    required this.text,
    required this.start,
    required this.end,
    required this.hasTiming,
    required this.weight,
  });
}

class _ChapterAudioTranscript {
  final String title;
  final String audioAsset;
  final List<_ChapterEntry> entries;

  const _ChapterAudioTranscript({
    required this.title,
    required this.audioAsset,
    required this.entries,
  });
}

class _ChapterEntry {
  final Duration start;
  final String text;

  const _ChapterEntry({required this.start, required this.text});
}

const List<_ChapterAudioTranscript> _chapters = [
  _ChapterAudioTranscript(
    title: 'Chapitre 1',
    audioAsset:
        'assets/La Ratatouille Folle - Chapitre 1 - Teach Yourself Languages - Open Road.mp3',
    entries: [
      _ChapterEntry(
        start: Duration(seconds: 0),
        text: "la ratatouille folle chapitre 1 la",
      ),
      _ChapterEntry(start: Duration(seconds: 7), text: "préparation"),
      _ChapterEntry(
        start: Duration(seconds: 10),
        text: "daniel vient nous dit julie de la porte",
      ),
      _ChapterEntry(start: Duration(seconds: 14), text: "de la maison"),
      _ChapterEntry(
        start: Duration(seconds: 16),
        text: "qu'est ce que tu veux je lis je lui",
      ),
      _ChapterEntry(
        start: Duration(seconds: 19),
        text: "réponds aujourd'hui on voyage en france",
      ),
      _ChapterEntry(
        start: Duration(seconds: 23),
        text: "tu te rappelles bien sûr je prépare ma",
      ),
      _ChapterEntry(
        start: Duration(seconds: 29),
        text: "valise où sont mes ben dit julie je",
      ),
      _ChapterEntry(
        start: Duration(seconds: 34),
        text: "m'appelle daniel g 24 ans julie et ma",
      ),
      _ChapterEntry(
        start: Duration(seconds: 38),
        text: "soeur nous vivons dans la même maison à",
      ),
      _ChapterEntry(
        start: Duration(seconds: 41),
        text: "londres julie à 23 ans",
      ),
      _ChapterEntry(
        start: Duration(seconds: 44),
        text: "nos parents s'appelle arthur est claire",
      ),
      _ChapterEntry(
        start: Duration(seconds: 48),
        text: "nous préparons notre voyage en france où",
      ),
      _ChapterEntry(
        start: Duration(seconds: 51),
        text: "nous serons étudiants en échange",
      ),
      _ChapterEntry(start: Duration(seconds: 53), text: "international"),
      _ChapterEntry(
        start: Duration(seconds: 55),
        text: "nous apprenons le français et nous avons",
      ),
      _ChapterEntry(
        start: Duration(seconds: 58),
        text: "déjà beaucoup appris je suis grand je",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 3),
        text: "mesure 1 m 87 g les",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 7),
        text: "chacun est un peu long j'ai les yeux",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 10),
        text: "verts et une grande bouche",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 12),
        text: "je fais beaucoup de sport j'ai de bonnes",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 16),
        text: "jambes parce que je cours tous les",
      ),
      _ChapterEntry(start: Duration(minutes: 1, seconds: 18), text: "matins"),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 20),
        text: "ma soeur julie a aussi les cheveux",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 25),
        text: "châtains mais ses cheveux sont plus",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 28),
        text: "longs que les miens elle n'a pas les",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 30),
        text: "yeux verts elle a les yeux marron comme",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 33),
        text: "mon père mes yeux sont de la même",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 37),
        text: "couleur que ceux de ma mère mon père",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 40),
        text: "arthur et poète il est auteur de",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 45),
        text: "plusieurs livres",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 46),
        text: "il a écrit",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 48),
        text: "douze livres sur le mariage la douleur",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 50),
        text: "le courage et la beauté il exprime",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 55),
        text: "beaucoup d'émotion dans ses douze livres",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 58),
        text: "ma mère est professeur de sciences",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 1),
        text: "naturelles elle étudie le corps humain",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 3),
        text: "en particulier le ventre ces études",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 7),
        text: "concernent la présence de matière dans",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 10),
        text: "le corps humain",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 11),
        text: "je suis très fier de mes parents ça fait",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 15),
        text: "40 ans qu'ils sont mariés cette année",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 18),
        text: "mes parents savent parler français il",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 21),
        text: "nous parle en français pour qu'on",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 22),
        text: "pratique mon père entre dans ma chambre",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 26),
        text: "ils nous regardent ils voient que je ne",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 30),
        text: "suis pas encore habillé daniel dépêche",
      ),
      _ChapterEntry(start: Duration(minutes: 2, seconds: 34), text: "toi"),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 34),
        text: "nous voulons vous amener à l'aéroport je",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 39),
        text: "suis obligé d'aller au bureau",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 40),
        text: "aujourd'hui je n'ai pas beaucoup de",
      ),
      _ChapterEntry(start: Duration(minutes: 2, seconds: 43), text: "temps"),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 44),
        text: "ne t'inquiète pas papa je m'habille tout",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 47),
        text: "de suite où est ta soeur elle est dans",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 51),
        text: "sa chambre",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 53),
        text: "mon père va dans la chambre de ma soeur",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 55),
        text: "pour parler avec elle julie le regarde",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3),
        text: "bonjour papa tu veux quelque chose oui",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 4),
        text: "je dis ton frère est en train de",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 7),
        text: "s'habiller",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 7),
        text: "je veux que vous preniez ça mon père lui",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 11),
        text: "montre une liasse de billets julie est",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 14),
        text: "très surprise c'est beaucoup d'argent",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 16),
        text: "dit elle ta mère et moi nous avons",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 20),
        text: "beaucoup économisé nous voulons payer une",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 23),
        text: "partie de votre voyage en france",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 25),
        text: "merci papa je vais le dire à daniel",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 30),
        text: "julie se retourne pour sortir de sa",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 32),
        text: "chambre au daniel tu es là et tu es",
      ),
      _ChapterEntry(start: Duration(minutes: 3, seconds: 37), text: "habillée"),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 39),
        text: "cet argent est pour nous deux merci papa",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 43),
        text: "ça nous sera très utile maintenant votre",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 47),
        text: "mère et moi allons vous emmener en",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 49),
        text: "voiture à l'aéroport venait quelques",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 53),
        text: "minutes plus tard nous sortons de la",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 55),
        text: "maison nous allons à l'aéroport dans la",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 58),
        text: "voiture de la mère julie est très",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4),
        text: "nerveuse elle est nerveuse",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 3),
        text: "en général je lis ma chérie lui dit ma",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 9),
        text: "mère ça va je suis très nerveuse plus",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 13),
        text: "répond-t-elle pourquoi je ne connais",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 18),
        text: "personne en france",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 19),
        text: "je connais seulement daniel ne",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 22),
        text: "t'inquiète pas je suis sûr qu'à",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 24),
        text: "marseille il y a des gens très gentils",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 26),
        text: "et très sympathique et n'oublie pas",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 29),
        text: "l'ami de daniel arnaud oui maman je sais",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 34),
        text: "mais je suis nerveuse il y a une queue",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 38),
        text: "très longue à l'aéroport beaucoup de",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 41),
        text: "personnes voyagent pour le travail",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 43),
        text: "certains partent en vacances je me",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 47),
        text: "rapproche de julie",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 48),
        text: "je lui dis ça va mieux oui daniel",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 53),
        text: "j'étais très nerveuse dans la voiture",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 56),
        text: "oui c'est vrai mais tout ira bien",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5),
        text: "mon ami arnaud à marseille est très",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 2),
        text: "gentil il aide les étudiants en échange",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 5),
        text: "international comme nous nos parents",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 9),
        text: "nous sert dans leurs bras nous leur",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 12),
        text: "disons au revoir",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 13),
        text: "julie et moi nous passons aux contrôles",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 16),
        text: "de sûreté",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 18),
        text: "daniel joly on vous aime c'est",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 22),
        text: "dernière chose que nous entendons une",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 25),
        text: "heure plus tard nous montons dans",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 27),
        text: "l'avion l'avion décolle en direction de",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 29),
        text: "marseille",
      ),
    ],
  ),
  _ChapterAudioTranscript(
    title: 'Chapitre 2',
    audioAsset: 'assets/chapter_2_en_france.mp3',
    entries: [
      _ChapterEntry(
        start: Duration(seconds: 1),
        text: "excusez-moi on est où je demande au",
      ),
      _ChapterEntry(
        start: Duration(seconds: 3),
        text: "conducteur on est arrivé à Nice comment",
      ),
      _ChapterEntry(
        start: Duration(seconds: 6),
        text: "on est à Nice oh non c'est pas",
      ),
      _ChapterEntry(start: Duration(seconds: 15), text: "possible Hello"),
      _ChapterEntry(start: Duration(seconds: 41), text: "[Musique]"),
      _ChapterEntry(start: Duration(minutes: 1), text: "à"),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 4),
        text: "lingosta chapitre 2 en",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 8),
        text: "France l'avion a atterri à Marseille mon",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 12),
        text: "ami arnaud nous attend à l'aéroport il me",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 16),
        text: "sert dans ses bras bien fort salut",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 19),
        text: "Daniel tu es enfin ici salut Arnaud je",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 23),
        text: "suis content de te voir mon ami Arnaud",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 26),
        text: "regarde ma sœur Julie Arnaud cher ami je",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 30),
        text: "te présente ma sœur Julie Arnaud",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 34),
        text: "s'approche de Julie et lui dit bonjour",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 37),
        text: "salut Julie enchanté de te connaître ma",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 41),
        text: "sœur est timide elle est toujours timide",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 44),
        text: "quand elle rencontre deux nouvelles",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 46),
        text: "personnes salut Arnaud ta sœur est très",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 49),
        text: "timide n'est-ce pas mais dit Arnaud en",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 51),
        text: "souriant oui c'est vrai mais elle est",
      ),
      _ChapterEntry(start: Duration(minutes: 1, seconds: 54), text: "très"),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 56),
        text: "sympathique un peu plus tard nous",
      ),
      _ChapterEntry(
        start: Duration(minutes: 1, seconds: 59),
        text: "prenons un",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2),
        text: "le taxi coûte 50 € de l'aéroport au",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 4),
        text: "centre de Marseille c'est le mois de",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 7),
        text: "juin et il fait très chaud le soleil en",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 10),
        text: "Méditerranée est toujours très",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 13),
        text: "chaud nous arrivons à notre nouvel",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 16),
        text: "appartement via Arnaud Arnaud nous aide",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 19),
        text: "avec nos valises c'est l'heure du",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 22),
        text: "déjeuner Julie et moi nous avons",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 26),
        text: "très faim Arnaud on a très faim on peut manger",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 30),
        text: "il y a des restaurants près d'ici quel",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 32),
        text: "type de cuisine ils servent dans l'un des",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 35),
        text: "restaurants la ratatouille est folle ils",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 38),
        text: "servent une très bonne ratatouille vous",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 41),
        text: "devez prendre l'autobus pour y aller",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 44),
        text: "dans l'autre ils servent du poisson frais",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 48),
        text: "et délicieux c'est juste à côté d'ici",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 51),
        text: "Julie tu veux manger une ratatouille je",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 54),
        text: "demande à ma sœur bien sûr Daniel j'ai",
      ),
      _ChapterEntry(
        start: Duration(minutes: 2, seconds: 58),
        text: "très faim mon ami Arnaud reste dans",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3),
        text: "l'appartement il travaille dans une",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 3),
        text: "école primaire l'après-midi il a des",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 6),
        text: "devoirs à corriger et après ça il a une",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 9),
        text: "classe à l'école il aime beaucoup",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 11),
        text: "travailler avec les enfants jeunes Julie",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 15),
        text: "et moi nous allons au restaurant la",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 18),
        text: "ratatouille",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 20),
        text: "folle Julie je me demande quel bus il",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 23),
        text: "faut prendre pour aller au restaurant de",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 25),
        text: "ratatouille je ne sais pas il faut",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 28),
        text: "demander à quelqu'un regarde de là le",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 31),
        text: "monsieur a la chemise blanche et jaune",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 34),
        text: "va lui demander le monsieur à la chemise",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 37),
        text: "blanche et jaune nous Salut Bonjour je",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 41),
        text: "peux vous aider oui comment on va au",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 44),
        text: "restaurant la ratatouille est folle c'est",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 47),
        text: "facile il faut prendre l'autobus 35 ici",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 51),
        text: "cet autobus va directement dans la rue",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 53),
        text: "de la ratatouille folle mais il y a un",
      ),
      _ChapterEntry(
        start: Duration(minutes: 3, seconds: 57),
        text: "problème quel problème cet autobus est",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 1),
        text: "en général très plein Julie et moi",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 4),
        text: "parlons de prendre l'autobus pour aller",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 6),
        text: "au restaurant elle semble",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 10),
        text: "inquiète Daniel le restaurant de",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 13),
        text: "ratatouille peut-être bien mais n",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 16),
        text: "pourrions peut-être manger au restaurant",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 18),
        text: "de poisson je ne veux pas prendre un",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 21),
        text: "autobus plein j'ai une idée Julie je peux",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 24),
        text: "prendre l'autobus 35 pour aller au",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 26),
        text: "restaurant la ratatouille est folle tu",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 29),
        text: "peux manger au restaurant de poisson",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 31),
        text: "pourquoi tu veux faire comme ça parce",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 34),
        text: "que comme ça on peut comparer les",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 37),
        text: "restaurants d'accord bonne idée je",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 39),
        text: "t'appelle sur ton téléphone",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 42),
        text: "portable je prends l'autobus suivant",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 45),
        text: "j'ai très sommeil je m'endors plus tard",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 48),
        text: "quand je me réveille l'autobus est",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 51),
        text: "arrêté il n'y a personne d'autre d dans",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 54),
        text: "sauf le conducteur excusez-moi on est où",
      ),
      _ChapterEntry(
        start: Duration(minutes: 4, seconds: 58),
        text: "je demande au conducteur on est arrivé à",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5),
        text: "Nice comment on est à Nice oh non c'est",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 4),
        text: "pas possible je prends mon téléphone",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 7),
        text: "portable dans ma poche j'essie d'appeler",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 10),
        text: "ma sœur mais mon téléphone portable n'a",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 13),
        text: "plus de batterie je ne peux pas",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 15),
        text: "l'allumer je sors de l'autobus je suis à",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 18),
        text: "Nice Nice est très loin de Marseille je",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 22),
        text: "me suis endormi dans l'autobus et il m'a",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 25),
        text: "amené jusqu'à Nice que veux-je faire",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 28),
        text: "maintenant je me promène dans rue de",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 30),
        text: "Nice je cherche une cabine",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 34),
        text: "téléphonique enfin je vois une vieille",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 38),
        text: "dame excusez-moi madame où est-ce que je",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 40),
        text: "peux trouver une cabine téléphonique au",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 43),
        text: "coin de la rue il y a un jeune homme",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 45),
        text: "merci beaucoup je vous souhaite une",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 48),
        text: "bonne journée de rien bonne journée je",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 53),
        text: "vérifie ma montre il est 5h de",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 56),
        text: "l'après-midi ma sœur ne sait pas où je",
      ),
      _ChapterEntry(
        start: Duration(minutes: 5, seconds: 58),
        text: "suis elle est sûrement très",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 1),
        text: "inquiète j'entre dans la cabine",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 4),
        text: "téléphonique oh non je ne me rappelle",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 6),
        text: "pas du numéro de téléphone de Julie",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 8),
        text: "grâce à mon portable je ne peux pas",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 11),
        text: "l'allumer j'ai un téléphone maintenant",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 14),
        text: "mais pas de numéro que veux-je faire je",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 18),
        text: "vais chercher un restaurant où manger",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 20),
        text: "j'ai très",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 23),
        text: "faim j'entre dans un restaurant le",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 26),
        text: "serveur s'approche bonjour bonjour que",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 30),
        text: "désirez-vous je regarde rapidement à la",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 33),
        text: "carte je voudrais un verre d'eau de la",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 38),
        text: "ratatouille au serveur pardon je ne vous",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 42),
        text: "ai pas bien compris je ris très fort les",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 45),
        text: "gens du restaurant mais regarde je m'en",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 47),
        text: "fous c'est trop drôle je montre du doigt",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 52),
        text: "le mot ratatouille sur le menu le serveur",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 55),
        text: "comprend je vais enfin avoir quelque",
      ),
      _ChapterEntry(
        start: Duration(minutes: 6, seconds: 57),
        text: "chose à manger je ne devrais pas rire",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7),
        text: "aussi fort mais c'est drôle on voulait",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 2),
        text: "manger de la ratatouille et maintenant",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 5),
        text: "je suis ici à manger de la ratatouille à",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 10),
        text: "Nice ma sœur ne sait pas où je suis que",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 14),
        text: "puis- je faire maintenant mon portable",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 16),
        text: "ne fonctionne pas il y a une cabine",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 18),
        text: "téléphonique mais je n'ai pas le numéro",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 21),
        text: "de ma sœur ça y est je sais je vais",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 24),
        text: "appeler à",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 25),
        text: "Londres je retourne à la cabine",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 28),
        text: "téléphonique je compose le numéro de",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 31),
        text: "téléphone de mes parents à Londres ça",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 33),
        text: "sont quatre fois enfant ma mère Claire",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 37),
        text: "répond bonjour bonjour Maman c'est",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 39),
        text: "Daniel bonjour Mon Chéri comment tu vas",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 42),
        text: "comment ça va à Marseille maman j'ai un",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 45),
        text: "problème que s'est passé-t-il mon fils",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 47),
        text: "il s'est passé quelqu chose de grave non",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 50),
        text: "c'est pas ça maman s'il te plaît appelle",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 53),
        text: "Julie dis-lui que je suis à Nice mon",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 55),
        text: "téléphone portable n'a plus de batterie",
      ),
      _ChapterEntry(
        start: Duration(minutes: 7, seconds: 58),
        text: "à Nice qu'est-ce que tu fais c'est une",
      ),
      _ChapterEntry(
        start: Duration(minutes: 8, seconds: 1),
        text: "longue histoire maman je décide de",
      ),
      _ChapterEntry(
        start: Duration(minutes: 8, seconds: 4),
        text: "trouver une chambre d'hôtel je peux",
      ),
      _ChapterEntry(
        start: Duration(minutes: 8, seconds: 6),
        text: "retourner à Marseille demain j'arrive à",
      ),
      _ChapterEntry(
        start: Duration(minutes: 8, seconds: 9),
        text: "un hôtel je paye pour une nuit j'entre",
      ),
      _ChapterEntry(
        start: Duration(minutes: 8, seconds: 12),
        text: "dans ma chambre je me déshabille je me",
      ),
      _ChapterEntry(
        start: Duration(minutes: 8, seconds: 16),
        text: "couche je m'endors tout de suite quelle",
      ),
      _ChapterEntry(
        start: Duration(minutes: 8, seconds: 19),
        text: "journée de",
      ),
      _ChapterEntry(
        start: Duration(minutes: 8, seconds: 22),
        text: "fou feedb",
      ),
      _ChapterEntry(
        start: Duration(minutes: 8, seconds: 29),
        text: "[Musique]",
      ),
      _ChapterEntry(
        start: Duration(minutes: 8, seconds: 35),
        text: "c'est fini ici",
      ),
      _ChapterEntry(
        start: Duration(minutes: 8, seconds: 36),
        text: "[Musique]",
      ),
    ],
  ),
];
