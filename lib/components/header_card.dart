import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/engagement/presentation/providers/engagement_providers.dart';

class HeaderCard extends ConsumerStatefulWidget {
  const HeaderCard({super.key});

  @override
  ConsumerState<HeaderCard> createState() => _HeaderCardState();
}

class _HeaderCardState extends ConsumerState<HeaderCard> {
  final TextEditingController _nameController = TextEditingController();
  bool _nameInvalid = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameInvalid = true);
      return;
    }
    await setLocalDisplayName(ref, name);
    setState(() {
      _nameInvalid = false;
    });
    ref.invalidate(currentUserProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final streakAsync = ref.watch(streakCounterProvider);
    final selectedLanguageCode = ref.watch(selectedLearningLanguageProvider);
    final streak = streakAsync.maybeWhen(
      data: (value) => value,
      orElse: () => 0,
    );

    final profile = profileAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );

    final language = languageOptionByCode(selectedLanguageCode);
    final displayName = (profile?.displayName ?? '').trim();
    final hasDisplayName = displayName.isNotEmpty;
    final profileImageUrl = profile?.profileImageUrl;

    if (!hasDisplayName && _nameController.text.isEmpty) {
      _nameController.text = getLocalDisplayName(ref);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [BoxShadow(offset: Offset(4, 4), color: Colors.black)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage:
                (profileImageUrl != null && profileImageUrl.trim().isNotEmpty)
                    ? NetworkImage(profileImageUrl)
                    : null,
            child:
                (profileImageUrl == null || profileImageUrl.trim().isEmpty)
                    ? const Icon(Icons.person)
                    : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDisplayName) ...[
                  Text(
                    'Hi, $displayName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep your learning streak alive',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Enter your name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _saveName(),
                            decoration: InputDecoration(
                              hintText: 'Your name',
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          onPressed: _saveName,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7DF9FF),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            side: const BorderSide(color: Colors.black, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_nameInvalid)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Name is required.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1C1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Row(
              children: [
                Text(
                  '$streak',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.deepOrange,
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7DF9FF),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Text(language.flag, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
