enum PodcastCategory { popular, beginner, intermediate, advanced }

extension PodcastCategoryX on PodcastCategory {
  String get title {
    switch (this) {
      case PodcastCategory.popular:
        return 'Popular Podcast';
      case PodcastCategory.beginner:
        return 'Beginners Podcast';
      case PodcastCategory.intermediate:
        return 'Intermediate Podcast';
      case PodcastCategory.advanced:
        return 'Advanced Podcast';
    }
  }

  String get query {
    switch (this) {
      case PodcastCategory.popular:
        return 'chinese podcast';
      case PodcastCategory.beginner:
        return 'Easy Chinese';
      case PodcastCategory.intermediate:
        return 'Intermediate Chinese';
      case PodcastCategory.advanced:
        return 'Advanced Chinese';
    }
  }

  String queryForLanguage(String languageCode) {
    final normalizedCode = languageCode.toLowerCase();

    switch (this) {
      case PodcastCategory.popular:
        return switch (normalizedCode) {
          'zh' => 'chinese language learning',
          'en' => 'english language learning',
          _ => 'french language learning',
        };
      case PodcastCategory.beginner:
        return switch (normalizedCode) {
          'zh' => 'Easy Chinese',
          'en' => 'Easy English',
          _ => 'Easy French',
        };
      case PodcastCategory.intermediate:
        return switch (normalizedCode) {
          'zh' => 'Intermediate Chinese',
          'en' => 'Intermediate English',
          _ => 'Intermediate French',
        };
      case PodcastCategory.advanced:
        return switch (normalizedCode) {
          'zh' => 'Advanced Chinese',
          'en' => 'Advanced English',
          _ => 'Advanced French',
        };
    }
  }

  int get limit {
    switch (this) {
      case PodcastCategory.popular:
        return 100;
      case PodcastCategory.beginner:
      case PodcastCategory.intermediate:
      case PodcastCategory.advanced:
        return 20;
    }
  }
}
