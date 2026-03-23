import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pareto_lingo/features/flashcard/presentation/providers/flashcard_providers.dart';
import 'package:pareto_lingo/features/news/domain/entities/news_article.dart';
import 'package:pareto_lingo/features/news/presentation/providers/news_providers.dart';

class NewsDetailScreen extends ConsumerStatefulWidget {
  final String languageCode;
  final NewsArticle article;

  const NewsDetailScreen({
    super.key,
    required this.languageCode,
    required this.article,
  });

  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  late final FlutterTts _tts;

  String _selectedText = '';
  bool _isSpeaking = false;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      newsDetailProvider((
        languageCode: widget.languageCode,
        article: widget.article,
      )),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('News Detail'),
        actions: [
          IconButton(
            tooltip:
                ref.watch(isNewsArticleSavedProvider(widget.article.pageId))
                    ? 'Remove from saved'
                    : 'Save article',
            onPressed: () async {
              final article = detailAsync.maybeWhen(
                data: (value) => value,
                orElse: () => widget.article,
              );
              await toggleSavedNewsArticle(ref, article);
            },
            icon: Icon(
              ref.watch(isNewsArticleSavedProvider(widget.article.pageId))
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
            ),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildContent(widget.article),
        data: _buildContent,
      ),
    );
  }

  Widget _buildContent(NewsArticle article) {
    final textBody =
        article.content.isEmpty ? article.description : article.content;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child:
                  article.thumbnailUrl.isNotEmpty
                      ? Image.network(
                        article.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderImage(),
                      )
                      : _placeholderImage(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            article.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _metaText(article),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _toggleTts(textBody),
                icon: Icon(
                  _isSpeaking
                      ? Icons.stop_rounded
                      : Icons.record_voice_over_rounded,
                ),
                label: Text(_isSpeaking ? 'Stop Dub Audio' : 'Dub Audio'),
              ),
              OutlinedButton.icon(
                onPressed:
                    _selectedText.isEmpty || _isTranslating
                        ? null
                        : () => _translateSelection(_selectedText),
                icon: const Icon(Icons.translate_rounded),
                label: Text(
                  _selectedText.isEmpty
                      ? 'Select text to translate'
                      : 'Translate "$_selectedText"',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SelectableText(
            textBody.isEmpty ? 'No article body available.' : textBody,
            onSelectionChanged: (selection, _) {
              final raw = selection.textInside(textBody).trim();
              final cleaned =
                  raw
                      .replaceAll(RegExp("[^a-zA-ZÀ-ÖØ-öø-ÿ\\-\\'\\s]"), '')
                      .trim();
              if (!mounted) return;
              setState(() {
                _selectedText = cleaned;
              });
            },
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          if (article.articleUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              article.articleUrl,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.article_outlined, size: 36),
    );
  }

  Future<void> _toggleTts(String text) async {
    if (_isSpeaking) {
      await _tts.stop();
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      return;
    }

    final body = text.trim();
    if (body.isEmpty) return;

    final locale = _ttsLocaleFromLanguage(widget.languageCode);
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(0.42);

    if (!mounted) return;
    setState(() => _isSpeaking = true);
    await _tts.speak(body);
  }

  Future<void> _translateSelection(String selected) async {
    setState(() => _isTranslating = true);
    try {
      final translated = await ref
          .read(wikinewsServiceProvider)
          .translateText(
            text: selected,
            sourceLanguage: widget.languageCode,
            targetLanguage: 'en',
          );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Translation'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selected: $selected'),
                  const SizedBox(height: 8),
                  Text('English: $translated'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final added = await addCustomFlashcard(
                      ref,
                      word: selected,
                      meaning: translated,
                      exampleSentence: widget.article.title,
                    );

                    if (!mounted || !dialogContext.mounted) return;
                    Navigator.of(dialogContext).pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          added
                              ? 'Added to flashcards.'
                              : 'Word already exists in flashcards.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Add to Flashcards'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  String _ttsLocaleFromLanguage(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'fr':
        return 'fr-FR';
      case 'es':
        return 'es-ES';
      case 'de':
        return 'de-DE';
      default:
        return 'en-US';
    }
  }

  String _metaText(NewsArticle article) {
    final source = article.source.trim().isEmpty ? 'News' : article.source;
    final date = article.publishedAt;
    if (date == null) return source;

    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$source • ${date.year}-$month-$day $hour:$minute';
  }
}
