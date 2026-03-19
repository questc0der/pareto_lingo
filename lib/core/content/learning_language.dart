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
    code: 'es',
    name: 'Spanish',
    flag: '🇪🇸',
    videoQuery: 'hablar español diálogo español',
    beginnerPodcastQuery: 'Easy Spanish',
    intermediatePodcastQuery: 'Intermediate Spanish',
    advancedPodcastQuery: 'Advanced Spanish',
    popularPodcastQuery: 'spanish language learning',
    readingText:
        'Hola! El español se habla en muchos países. Leer textos cortos todos los días '
        'mejora la comprensión y ayuda a memorizar nuevas palabras en contexto.',
    lectureTopics: [
      'Spanish pronunciation',
      'Spanish grammar basics',
      'Spanish conversation',
    ],
  ),
  LearningLanguageOption(
    code: 'de',
    name: 'German',
    flag: '🇩🇪',
    videoQuery: 'deutsch sprechen deutsch dialog',
    beginnerPodcastQuery: 'Easy German',
    intermediatePodcastQuery: 'Intermediate German',
    advancedPodcastQuery: 'Advanced German',
    popularPodcastQuery: 'german language learning',
    readingText:
        'Hallo! Deutsch zu lernen wird einfacher, wenn man regelmäßig kurze Texte liest. '
        'So erkennt man Satzmuster und erweitert den Wortschatz systematisch.',
    lectureTopics: [
      'German pronunciation',
      'German grammar basics',
      'German conversation',
    ],
  ),
];

LearningLanguageOption languageOptionByCode(String? code) {
  return supportedLearningLanguages.firstWhere(
    (option) => option.code == code,
    orElse: () => supportedLearningLanguages.first,
  );
}
