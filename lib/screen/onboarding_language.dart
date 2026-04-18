import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/flashcard/presentation/providers/flashcard_providers.dart';

const _kBg = Color(0xFFF5F5F0);
const _kCyan = Color(0xFF7DF9FF);
const _kYellow = Color(0xFFFFE566);
const _kBorder = BorderSide(color: Colors.black, width: 2.5);
const _kShadow = [BoxShadow(offset: Offset(4, 4), color: Colors.black)];

class OnboardingLanguageScreen extends ConsumerStatefulWidget {
  const OnboardingLanguageScreen({super.key});

  @override
  ConsumerState<OnboardingLanguageScreen> createState() =>
      _OnboardingLanguageScreenState();
}

class _OnboardingLanguageScreenState
    extends ConsumerState<OnboardingLanguageScreen> {
  String? _selectedCode;
  String? _nativeLanguageCode;
  bool _isPreparing = false;
  String? _setupError;

  @override
  void initState() {
    super.initState();
    _selectedCode = supportedLearningLanguages.first.code;
    _nativeLanguageCode = supportedLearningLanguages.first.code;
  }

  @override
  Widget build(BuildContext context) {
    final selectedLanguage = languageOptionByCode(_selectedCode);

    if (_isPreparing) {
      return Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _kCyan,
                  borderRadius: BorderRadius.circular(16),
                  border: const Border.fromBorderSide(_kBorder),
                  boxShadow: _kShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome_rounded, size: 58),
                    SizedBox(height: 16),
                    Text(
                      'Preparing your deck...',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Setting up your first offline-ready session.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    SizedBox(height: 18),
                    LinearProgressIndicator(
                      minHeight: 8,
                      color: Colors.black,
                      backgroundColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(
                color: _kYellow,
                border: Border(bottom: _kBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.language_rounded, color: _kYellow),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Pick Your Learning Language',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _kCyan,
                        border: const Border.fromBorderSide(_kBorder),
                        boxShadow: _kShadow,
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
                                const Expanded(
                                  child: Text(
                                    'Choose your learning language',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'This sets up flashcards, podcasts, and news for your journey.',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
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
                    if (_setupError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _setupError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white,
                        border: const Border.fromBorderSide(_kBorder),
                        boxShadow: _kShadow,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'What language do you speak?',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'native-lang-${_nativeLanguageCode ?? 'none'}',
                              ),
                              initialValue: _nativeLanguageCode,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                                labelText: 'Your speaking language',
                              ),
                              items: supportedLearningLanguages
                                  .map(
                                    (language) => DropdownMenuItem<String>(
                                      value: language.code,
                                      child: Text(
                                        '${language.flag} ${language.name}',
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                setState(() {
                                  _nativeLanguageCode = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: supportedLearningLanguages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final language = supportedLearningLanguages[index];
                          final isSelected = language.code == _selectedCode;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: isSelected ? _kYellow : Colors.white,
                              border: const Border.fromBorderSide(_kBorder),
                              boxShadow: _kShadow,
                            ),
                            child: ListTile(
                              onTap: () {
                                setState(() {
                                  _selectedCode = language.code;
                                });
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text(
                                'Learn through speaking, news, and podcasts',
                              ),
                              trailing:
                                  isSelected
                                      ? const Icon(Icons.check_circle_rounded)
                                      : const Icon(
                                        Icons.radio_button_unchecked_rounded,
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
                        color: Colors.white,
                        border: const Border.fromBorderSide(_kBorder),
                        boxShadow: _kShadow,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: _kCyan,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Colors.black,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            onPressed:
                                _selectedCode == null ||
                                        _isPreparing ||
                                        _nativeLanguageCode == null
                                    ? null
                                    : () async {
                                      final code = _selectedCode!;
                                      setState(() {
                                        _setupError = null;
                                        _isPreparing = true;
                                      });

                                      try {
                                        await setLearningLanguage(ref, code);
                                        await setNativeLanguage(
                                          ref,
                                          _nativeLanguageCode!,
                                        );
                                        await ref.read(
                                          syncFlashcardDeckProvider(
                                            code,
                                          ).future,
                                        );
                                      } catch (_) {
                                        if (!mounted) return;
                                        setState(() {
                                          _setupError =
                                              'Could not finish setup online. You can still continue and the app will use local content.';
                                        });
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
          ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
        border: const Border.fromBorderSide(_kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.black87),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
