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

    final lectureTopic = bootstrapContentAsync.maybeWhen(
      data:
          (content) =>
              content.lectureTopics.isNotEmpty
                  ? content.lectureTopics.first
                  : 'Daily lecture',
      orElse: () => selectedLanguage.lectureTopics.first,
    );

    return ListView(
      padding: EdgeInsets.all(6),
      children: [
        Row(
          children: [
            Expanded(child: _buildStudiedCard(context, flashcardStatsAsync)),
            SizedBox(width: 7),
            Expanded(child: _buildRemainingCard(context, flashcardStatsAsync)),
          ],
        ),
        SizedBox(height: 16),
        _flashCardSection(context, selectedLanguage.name, topWordsCount),
        SizedBox(height: 16),
        _speakingSection(context),
        SizedBox(height: 16),
        _rulesSection(context, lectureTopic),
        SizedBox(height: 16),
        _readingSection(context, readingSnippet),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context, {
    String? count,
    String? mode,
    double? height,
    double? width,
    String? title,
    String? description,
    String? buttonText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: NeuContainer(
        height: height,
        width: width,
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (count != null)
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Circular',
                  ),
                ),
              if (mode != null)
                Text(
                  mode,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Circular',
                  ),
                ),
              if (title != null)
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Circular',
                  ),
                ),
              if (description != null)
                Text(description, style: TextStyle(fontFamily: 'Circular')),
              if (buttonText != null)
                NeuTextButton(
                  borderRadius: BorderRadius.circular(8),
                  buttonColor: Color(0xFF7DF9FF),
                  buttonHeight: 40,
                  buttonWidth: 80,
                  onPressed: () {
                    if (buttonText == "Start") {
                      context.push('/flashcard');
                    } else if (buttonText == "Speak") {
                      context.push('/speak');
                    } else if (buttonText == "Study") {
                      context.push('/rules');
                    }
                  },
                  enableAnimation: true,
                  text: Text(
                    buttonText,
                    style: TextStyle(
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

  Widget _buildStudiedCard(
    BuildContext context,
    AsyncValue<FlashcardStats> statsAsync,
  ) {
    final studied = statsAsync.maybeWhen(
      data: (stats) => stats.studied,
      orElse: () => 0,
    );

    return _buildCard(
      context,
      count: '$studied',
      mode: "Studied",
      height: MediaQuery.of(context).size.width / 2.5,
    );
  }

  Widget _buildRemainingCard(
    BuildContext context,
    AsyncValue<FlashcardStats> statsAsync,
  ) {
    final remaining = statsAsync.maybeWhen(
      data: (stats) => stats.remaining,
      orElse: () => 0,
    );

    return _buildCard(
      context,
      count: '$remaining',
      mode: "Remaining",
      height: MediaQuery.of(context).size.width / 2.5,
    );
  }

  Widget _flashCardSection(
    BuildContext context,
    String languageName,
    int topWordsCount,
  ) {
    return _buildCard(
      context,
      title: "Flashcards",
      buttonText: "Start",
      description:
          "Learn the top $topWordsCount most used $languageName words — just 10 words a day, or customize your own pace.",
      height: MediaQuery.of(context).size.height / 5,
    );
  }

  Widget _speakingSection(BuildContext context) {
    return _buildCard(
      context,
      mode: "Speaking",
      buttonText: "Speak",
      description:
          "Practice speaking by repeating after the narrator. Tap to play or pause the audio anytime.",
      height: MediaQuery.of(context).size.height / 5,
    );
  }

  Widget _rulesSection(BuildContext context, String lectureTopic) {
    return _buildCard(
      context,
      mode: "Grammar Rules",
      buttonText: "Study",
      description:
          "Master grammar through clear lessons. Next lecture: $lectureTopic.",
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
      mode: "Daily Reading",
      description: condensedText,
      height: MediaQuery.of(context).size.height / 5,
    );
  }
}
