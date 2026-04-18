import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';
import 'package:pareto_lingo/features/engagement/presentation/providers/engagement_providers.dart';

class HeaderCard extends ConsumerWidget {
  const HeaderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final displayName = profile?.displayName ?? 'Learner';
    final profileImageUrl = profile?.profileImageUrl;

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
          PopupMenuButton<String>(
            tooltip: 'Learning language',
            onSelected: (value) async {
              if (value.startsWith('lang:')) {
                final code = value.replaceFirst('lang:', '');
                await setLearningLanguage(ref, code);
              }
            },
            itemBuilder: (context) {
              return [
                for (final option in supportedLearningLanguages)
                  PopupMenuItem<String>(
                    value: 'lang:${option.code}',
                    child: Row(
                      children: [
                        Text(option.flag),
                        const SizedBox(width: 8),
                        Expanded(child: Text(option.name)),
                        if (option.code == language.code)
                          const Icon(Icons.check_rounded, size: 16),
                      ],
                    ),
                  ),
              ];
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF7DF9FF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Row(
                children: [
                  Text(language.flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 5),
                  const Icon(Icons.expand_more_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
