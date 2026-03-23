import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:pareto_lingo/core/content/learning_language.dart';
import 'package:pareto_lingo/features/auth/presentation/providers/auth_providers.dart';

class HeaderCard extends ConsumerWidget {
  const HeaderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final appSettings = Hive.box<String>('app_settings');
    final streak = int.tryParse(appSettings.get('current_streak') ?? '0') ?? 0;

    final profile = profileAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );

    final language = languageOptionByCode(profile?.learningLanguage);
    final displayName = profile?.displayName ?? 'Learner';
    final profileImageUrl = profile?.profileImageUrl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage:
                      (profileImageUrl != null &&
                              profileImageUrl.trim().isNotEmpty)
                          ? NetworkImage(profileImageUrl)
                          : null,
                  child:
                      (profileImageUrl == null ||
                              profileImageUrl.trim().isEmpty)
                          ? const Icon(Icons.person)
                          : null,
                ),
                SizedBox(width: 10),
                Text(
                  displayName,
                  style: TextStyle(fontSize: 18, fontFamily: 'Circular'),
                ),
              ],
            ),
          ),

          // Right icon button
          Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Text('$streak'),
                SizedBox(width: 5),
                const Icon(
                  Icons.local_fire_department_sharp,
                  color: Colors.orange,
                ),
                SizedBox(width: 10),
                Text(language.flag),
                SizedBox(width: 5),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
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
                          child: Text('${option.flag} ${option.name}'),
                        ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
