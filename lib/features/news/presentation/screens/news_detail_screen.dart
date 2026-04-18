import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:pareto_lingo/features/flashcard/presentation/providers/flashcard_providers.dart';
import 'package:pareto_lingo/features/news/domain/entities/news_article.dart';
import 'package:pareto_lingo/features/news/presentation/providers/news_providers.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Design tokens ───────────────────────────────────────────────────────────
const _kBg = Color(0xFFF5F5F0);
const _kAccent = Color(0xFF7DF9FF);
const _kAccentYellow = Color(0xFFFFE566);
const _kBorder = BorderSide(color: Colors.black, width: 2.5);

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
    final isSaved =
        ref.watch(isNewsArticleSavedProvider(widget.article.pageId));

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Neo-brut header ───────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: _kAccent,
                border: Border(bottom: _kBorder),
              ),
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Row(
                children: [
                  _IconBtn(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Article',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                  _IconBtn(
                    icon: isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    onPressed: () async {
                      final article = detailAsync.maybeWhen(
                        data: (v) => v,
                        orElse: () => widget.article,
                      );
                      await toggleSavedNewsArticle(ref, article);
                    },
                  ),
                ],
              ),
            ),
            // ── Content ───────────────────────────────────────────────
            Expanded(
              child: detailAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => _buildContent(widget.article),
                data: _buildContent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(NewsArticle article) {
    final textBody = _resolveReadableBody(article);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero image ──────────────────────────────────────────────
          if (article.thumbnailUrl.isNotEmpty)
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black, width: 2.5),
                boxShadow: const [
                  BoxShadow(offset: Offset(4, 4), color: Colors.black)
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                article.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFEEEEE8),
                  child: const Icon(Icons.article_rounded,
                      size: 42, color: Colors.black26),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEE8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black, width: 2.5),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.article_rounded,
                  size: 42, color: Colors.black26),
            ),
          const SizedBox(height: 16),

          // ── Source + date pill ─────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _metaText(article),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),

          // ── Title ───────────────────────────────────────────────────
          Text(
            article.title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),

          // ── Action buttons ─────────────────────────────────────────
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionChip(
                icon: _isSpeaking
                    ? Icons.stop_rounded
                    : Icons.record_voice_over_rounded,
                label: _isSpeaking ? 'Stop' : 'Read Aloud',
                color: Colors.black,
                textColor: Colors.white,
                onTap: () => _toggleTts(textBody),
              ),
              _ActionChip(
                icon: Icons.translate_rounded,
                label: _selectedText.isEmpty
                    ? 'Select to Translate'
                    : 'Translate',
                color: _selectedText.isEmpty
                    ? Colors.grey.shade300
                    : _kAccentYellow,
                onTap: _selectedText.isEmpty || _isTranslating
                    ? null
                    : () => _translateSelection(_selectedText),
              ),
              if (article.articleUrl.isNotEmpty)
                _ActionChip(
                  icon: Icons.open_in_browser_rounded,
                  label: 'Open in Browser',
                  color: _kAccent,
                  onTap: () => _openInBrowser(article.articleUrl),
                ),
            ],
          ),

          // ── Selection hint ─────────────────────────────────────────
          if (_selectedText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _kAccentYellow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Text(
                'Selected: "$_selectedText"',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const SizedBox(height: 16),
          // ── Divider ────────────────────────────────────────────────
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // ── Article body ────────────────────────────────────────────
          if (textBody.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Column(
                children: [
                  const Text(
                    'Full article content unavailable here.',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap "Open in Browser" above to read the complete article.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            SelectableText(
              textBody,
              onSelectionChanged: (selection, _) {
                final raw = selection.textInside(textBody).trim();
                // Allow all Unicode characters (including CJK) — no latin-only filter
                final cleaned = raw.length > 200
                    ? raw.substring(0, 200).trim()
                    : raw;
                if (!mounted) return;
                setState(() => _selectedText = cleaned);
              },
              style: const TextStyle(
                fontSize: 16,
                height: 1.7,
                color: Colors.black87,
              ),
            ),

          const SizedBox(height: 24),
          // ── Open in browser button (bottom) ─────────────────────────
          if (article.articleUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _openInBrowser(article.articleUrl),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 2.5),
                  boxShadow: const [
                    BoxShadow(offset: Offset(4, 4), color: Colors.black38)
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_browser_rounded,
                        color: _kAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Open Full Article in Browser',
                      style: TextStyle(
                        color: _kAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _resolveReadableBody(NewsArticle article) {
    final content = article.content.trim();
    final description = article.description.trim();

    if (content.isNotEmpty && !_isUnreadableText(content)) {
      return content;
    }

    if (description.isNotEmpty && !_isUnreadableText(description)) {
      return description;
    }

    return '';
  }

  bool _isUnreadableText(String value) {
    final text = value.trimLeft();
    if (text.startsWith('{') || text.startsWith('[')) return true;

    final lower = text.toLowerCase();
    if (text.contains('{{') ||
        text.contains('}}') ||
        lower.contains('cewbot') ||
        lower.contains('headline item/header') ||
        lower.contains('fetch error')) {
      return true;
    }

    return false;
  }

  // ─── TTS ─────────────────────────────────────────────────────────────────╮

  Future<void> _toggleTts(String text) async {
    if (_isSpeaking) {
      await _tts.stop();
      if (!mounted) return;
      setState(() => _isSpeaking = false);
      return;
    }
    final body = text.trim();
    if (body.isEmpty) return;
    await _tts.setLanguage(_ttsLocale(widget.languageCode));
    await _tts.setSpeechRate(0.42);
    if (!mounted) return;
    setState(() => _isSpeaking = true);
    await _tts.speak(body);
  }

  // ─── Translation ──────────────────────────────────────────────────────────╮

  Future<void> _translateSelection(String selected) async {
    setState(() => _isTranslating = true);
    try {
      final translated = await ref.read(wikinewsServiceProvider).translateText(
            text: selected,
            sourceLanguage: widget.languageCode,
            targetLanguage: 'en',
          );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.black, width: 2.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Translation',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEE8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Original',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text(selected,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kAccent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('English',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text(translated,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final added = await addCustomFlashcard(
                            ref,
                            word: selected,
                            meaning: translated,
                            exampleSentence: widget.article.title,
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop();
                          messenger.showSnackBar(SnackBar(
                            content: Text(added
                                ? '✓ Added to flashcards.'
                                : 'Already in flashcards.'),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '+ Add to Flashcards',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Text('Close',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    // Capture messenger before async gap to avoid BuildContext across async gap lint
    final messenger = ScaffoldMessenger.of(context);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Copied URL to clipboard — paste in your browser.')),
      );
    }
  }

  String _ttsLocale(String languageCode) {
    return switch (languageCode.toLowerCase()) {
      'fr' => 'fr-FR',
      'zh' => 'zh-CN',
      'en' => 'en-US',
      _ => 'en-US',
    };
  }

  String _metaText(NewsArticle article) {
    final source =
        article.source.trim().isEmpty ? 'News' : article.source;
    final date = article.publishedAt;
    if (date == null) return source;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final mn = date.minute.toString().padLeft(2, '0');
    return '$source  ·  ${date.year}-$m-$d  $h:$mn';
  }
}

// ─── _ActionChip ────────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    this.textColor = Colors.black,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: onTap != null
              ? const [BoxShadow(offset: Offset(3, 3), color: Colors.black)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: textColor),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: textColor)),
          ],
        ),
      ),
    );
  }
}

// ─── _IconBtn ────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _IconBtn({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
