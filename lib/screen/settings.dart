import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pareto_lingo/features/engagement/presentation/providers/engagement_providers.dart';
import 'package:pareto_lingo/features/flashcard/presentation/providers/flashcard_providers.dart';
import 'package:pareto_lingo/features/news/presentation/providers/news_providers.dart';
import 'package:pareto_lingo/features/news/presentation/screens/news_detail_screen.dart';

// ─── Design tokens ───────────────────────────────────────────────────────────
const _kBg = Color(0xFFF5F5F0);
const _kAccent = Color(0xFF7DF9FF);
const _kAccentYellow = Color(0xFFFFE566);
const _kBorder = BorderSide(color: Colors.black, width: 2.5);
const _kShadow = [BoxShadow(offset: Offset(4, 4), color: Colors.black)];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyLimitAsync = ref.watch(dailyFlashcardLimitProvider);
    final savedNewsAsync = ref.watch(savedNewsProvider);
    final dailyLimit = dailyLimitAsync.maybeWhen(
      data: (v) => v,
      orElse: () => 10,
    );
    final reminderSettings = ref
        .watch(reminderSettingsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse:
              () => const ReminderSettings(
                enabled: false,
                time: TimeOfDay(hour: 20, minute: 0),
              ),
        );
    final streak = ref
        .watch(streakCounterProvider)
        .maybeWhen(data: (value) => value, orElse: () => 0);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Neo-brut header ───────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: _kAccentYellow,
                border: Border(bottom: _kBorder),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      color: _kAccentYellow,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Fine-tune your learning routine',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Body ─────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  // ── Daily flashcard goal ──────────────────────────
                  _SectionCard(
                    accentColor: _kAccent,
                    icon: Icons.auto_awesome_rounded,
                    title: 'Daily Flashcard Goal',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Big number display
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$dailyLimit',
                                style: const TextStyle(
                                  color: _kAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'cards per day\nConsistency beats volume.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 8,
                            activeTrackColor: Colors.black,
                            inactiveTrackColor: Colors.black26,
                            thumbColor: Colors.black,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12,
                            ),
                            overlayColor: Colors.black12,
                          ),
                          child: Slider(
                            value: dailyLimit.toDouble(),
                            min: 5,
                            max: 100,
                            divisions: 19,
                            label: '$dailyLimit',
                            onChanged:
                                (value) =>
                                    setDailyFlashcardLimit(ref, value.round()),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _Tag(label: '5 min'),
                            _Tag(label: '100 max'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Tips card ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kAccentYellow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 2.5),
                      boxShadow: _kShadow,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tips_and_updates_rounded, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Default is 10 cards/day. Science shows even 5–10 minutes daily beats cramming.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Daily reminder section ───────────────────────
                  _SectionCard(
                    accentColor: const Color(0xFFA7F89A),
                    icon: Icons.notifications_active_rounded,
                    title: 'Daily Reminder',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Practice reminder',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Switch(
                              value: reminderSettings.enabled,
                              onChanged:
                                  (value) => setReminderEnabled(ref, value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          reminderSettings.enabled
                              ? 'You will get notified daily at ${_fmtTime(context, reminderSettings.time)}.'
                              : 'Enable this to get a daily notification reminder.',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _NeuButton(
                          label:
                              'Reminder time: ${_fmtTime(context, reminderSettings.time)}',
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: reminderSettings.time,
                            );
                            if (picked == null) return;
                            await setReminderTime(ref, picked);
                            if (!reminderSettings.enabled) {
                              await setReminderEnabled(ref, true);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Current streak: $streak day${streak == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Saved articles ───────────────────────────────
                  _SectionCard(
                    accentColor: _kAccentYellow,
                    icon: Icons.bookmark_rounded,
                    title: 'Saved Articles',
                    child: savedNewsAsync.when(
                      loading:
                          () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(color: Colors.black),
                          ),
                      error:
                          (_, __) => const Text(
                            'Unable to load saved articles.',
                            style: TextStyle(color: Colors.black54),
                          ),
                      data: (articles) {
                        if (articles.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEEEE8),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.black26,
                                width: 1.5,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: Colors.black38,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No saved articles yet.\nSave them from the News tab.',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: [
                            for (final article in articles.take(15))
                              _SavedArticleTile(article: article, ref: ref),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtTime(BuildContext context, TimeOfDay time) {
  return time.format(context);
}

// ─── _SectionCard ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: _kShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              border: const Border(bottom: _kBorder),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

// ─── _SavedArticleTile ───────────────────────────────────────────────────────

class _SavedArticleTile extends StatelessWidget {
  final dynamic article;
  final WidgetRef ref;

  const _SavedArticleTile({required this.article, required this.ref});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => NewsDetailScreen(
                  languageCode: article.languageCode,
                  article: article,
                ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEE8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      article.languageCode.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => toggleSavedNewsArticle(ref, article),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: const Icon(Icons.delete_outline_rounded, size: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _Tag ────────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _NeuButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _NeuButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kAccent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(offset: Offset(2, 2), color: Colors.black),
          ],
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
