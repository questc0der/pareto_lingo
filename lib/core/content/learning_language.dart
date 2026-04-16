class LearningLanguageOption {
  final String code;
  final String name;
  final String flag;
  final String videoQuery;
  final String beginnerPodcastQuery;
  final String intermediatePodcastQuery;
  final String advancedPodcastQuery;
  final String popularPodcastQuery;
  final String readingText;
  final List<String> lectureTopics;

  const LearningLanguageOption({
    required this.code,
    required this.name,
    required this.flag,
    required this.videoQuery,
    required this.beginnerPodcastQuery,
    required this.intermediatePodcastQuery,
    required this.advancedPodcastQuery,
    required this.popularPodcastQuery,
    required this.readingText,
    required this.lectureTopics,
  });
}

const supportedLearningLanguages = <LearningLanguageOption>[
  LearningLanguageOption(
    code: 'fr',
    name: 'French',
    flag: '🇫🇷',
    videoQuery: 'parler français dialogue français',
    beginnerPodcastQuery: 'Easy French',
    intermediatePodcastQuery: 'Intermediate French',
    advancedPodcastQuery: 'Advanced French',
    popularPodcastQuery: 'france language learning',
    readingText:
        'Bonjour! Le français est une langue parlée sur plusieurs continents. '
        'Lire un peu chaque jour aide à enrichir le vocabulaire et à mieux comprendre '
        'les structures grammaticales.',
    lectureTopics: [
      'French pronunciation',
      'French grammar basics',
      'French conversation',
    ],
  ),
  LearningLanguageOption(
    code: 'zh',
    name: 'Mandarin',
    flag: '🇨🇳',
    videoQuery: '中文 对话 普通话 学习',
    beginnerPodcastQuery: 'Mandarin beginner podcast',
    intermediatePodcastQuery: 'Mandarin intermediate podcast',
    advancedPodcastQuery: 'Mandarin advanced podcast',
    popularPodcastQuery: 'mandarin chinese language learning',
    readingText:
        '你好！普通话是世界上使用人数最多的语言之一。每天阅读一点点有助于积累词汇，'
        '并更自然地掌握句子结构。',
    lectureTopics: [
      'Mandarin tones and pronunciation',
      'Mandarin grammar basics',
      'Mandarin conversation',
    ],
  ),
  LearningLanguageOption(
    code: 'en',
    name: 'English',
    flag: '🇬🇧',
    videoQuery: 'english conversation daily speaking',
    beginnerPodcastQuery: 'English beginner podcast',
    intermediatePodcastQuery: 'English intermediate podcast',
    advancedPodcastQuery: 'English advanced podcast',
    popularPodcastQuery: 'english language learning',
    readingText:
        'Hello! Reading short English texts every day helps you build vocabulary and '
        'understand natural sentence patterns for speaking with confidence.',
    lectureTopics: [
      'English pronunciation',
      'English grammar basics',
      'English conversation',
    ],
  ),
];

LearningLanguageOption languageOptionByCode(String? code) {
  return supportedLearningLanguages.firstWhere(
    (option) => option.code == code,
    orElse: () => supportedLearningLanguages.first,
  );
}
