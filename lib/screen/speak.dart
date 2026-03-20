import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Speak extends ConsumerStatefulWidget {
  const Speak({super.key});

  @override
  ConsumerState<Speak> createState() => _Shadowing();
}

class _Shadowing extends ConsumerState<Speak> {
  late final AudioPlayer player;
  final ScrollController _scrollController = ScrollController();

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
    _setupAudio();
    _loadTranscript();

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

  Future<void> _setupAudio() async {
    await player.setAsset('assets/short_stories_in_french.mp3');
  }

  Future<void> _loadTranscript() async {
    final String jsonString = await rootBundle.loadString(
      'assets/alignment_output.json',
    );
    final Map<String, dynamic> root = json.decode(jsonString);
    final fragments = (root['fragments'] as List<dynamic>? ?? const []);

    final lines = <_TranscriptLineSeed>[];
    var reliableCount = 0;

    for (final item in fragments) {
      final map = item as Map<String, dynamic>;
      final lineGroup = (map['lines'] as List<dynamic>? ?? const []);
      if (lineGroup.isEmpty) continue;

      final text = lineGroup.first.toString().trim();
      if (text.isEmpty) continue;

      final begin = _parseMs(map['begin']);
      final end = _parseMs(map['end']);

      final hasTiming = end > begin && begin >= 0;
      if (hasTiming) {
        reliableCount++;
      }

      lines.add(
        _TranscriptLineSeed(
          text: text,
          startMs: begin,
          endMs: end,
          hasTiming: hasTiming,
          weight: _wordWeight(text),
        ),
      );
    }

    final hasReliableTimings =
        lines.isNotEmpty && reliableCount > lines.length * 0.2;
    final normalized = _buildAnchoredTimeline(lines);

    if (!mounted) return;
    setState(() {
      _sourceLines = lines;
      _lines = normalized;
      _hasReliableTimings = hasReliableTimings;
      _isLoading = false;
    });
  }

  int get _activeLineIndex {
    if (_lines.isEmpty) return 0;

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (_position >= line.start && _position <= line.end) {
        return i;
      }
    }

    // If no exact match, find nearest start
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

    final target = (active * 66.0) - 140;
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

    return Scaffold(
      appBar: AppBar(title: const Text('Shadow Reading')),
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
                  'Language: ${language.name} ${language.flag}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  _hasReliableTimings
                      ? 'Sync: alignment timestamps'
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
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _togglePlayPause,
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
                              child: Text(
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
                            ),
                          );
                        },
                      ),
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

  int _parseMs(dynamic raw) {
    final value = double.tryParse(raw?.toString() ?? '0') ?? 0;
    return (value * 1000).round();
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
