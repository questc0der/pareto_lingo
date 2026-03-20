import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/flashcard/presentation/providers/flashcard_providers.dart';

class OnboardingLanguageScreen extends ConsumerStatefulWidget {
  const OnboardingLanguageScreen({super.key});

  @override
  ConsumerState<OnboardingLanguageScreen> createState() =>
      _OnboardingLanguageScreenState();
}

class _OnboardingLanguageScreenState
    extends ConsumerState<OnboardingLanguageScreen> {
  String? _selectedCode;
  bool _isPreparing = false;
  String? _setupError;

  @override
  void initState() {
    super.initState();
    _selectedCode = supportedLearningLanguages.first.code;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedLanguage = languageOptionByCode(_selectedCode);

    if (_isPreparing) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.85, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 58,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Preparing your deck...',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fetching top words and setting up your first session.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const LinearProgressIndicator(minHeight: 6),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.96, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOut,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: theme.colorScheme.surfaceContainer,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              selectedLanguage.flag,
                              style: const TextStyle(fontSize: 26),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Choose your learning language',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'This sets up flashcards, podcasts, and news for your journey.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _SetupTag(
                              icon: Icons.style_rounded,
                              label: 'Flashcards',
                            ),
                            _SetupTag(
                              icon: Icons.newspaper_rounded,
                              label: 'News',
                            ),
                            _SetupTag(
                              icon: Icons.podcasts_rounded,
                              label: 'Podcasts',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_setupError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _setupError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: supportedLearningLanguages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final language = supportedLearningLanguages[index];
                    final isSelected = language.code == _selectedCode;
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 260 + (index * 70)),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - value) * 12),
                            child: child,
                          ),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color:
                              isSelected
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surface,
                          border: Border.all(
                            color:
                                isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant,
                            width: isSelected ? 1.6 : 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            setState(() => _selectedCode = language.code);
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          leading: Text(
                            language.flag,
                            style: const TextStyle(fontSize: 26),
                          ),
                          title: Text(
                            language.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text(
                            'Learn through speaking, news, and podcasts',
                          ),
                          trailing: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child:
                                isSelected
                                    ? Icon(
                                      Icons.check_circle_rounded,
                                      key: const ValueKey('selected'),
                                      color: theme.colorScheme.primary,
                                    )
                                    : const Icon(
                                      Icons.radio_button_unchecked_rounded,
                                      key: ValueKey('unselected'),
                                    ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.colorScheme.surfaceContainer,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          _selectedCode == null || _isPreparing
                              ? null
                              : () async {
                                final code = _selectedCode!;
                                setState(() {
                                  _setupError = null;
                                  _isPreparing = true;
                                });

                                try {
                                  await setLearningLanguage(ref, code);
                                  await ref.read(
                                    syncFlashcardDeckProvider(code).future,
                                  );
                                } catch (_) {
                                  if (!mounted) return;
                                  setState(() {
                                    _setupError =
                                        'Could not finish setup online. You can still continue and the app will use local content.';
                                    _isPreparing = false;
                                  });
                                  return;
                                }

                                if (!context.mounted) return;
                                context.go('/');
                              },
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Start Learning'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SetupTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
