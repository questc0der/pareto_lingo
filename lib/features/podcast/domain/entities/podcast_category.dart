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
        return 'france';
      case PodcastCategory.beginner:
        return 'Easy French';
      case PodcastCategory.intermediate:
        return 'Intermediate French';
      case PodcastCategory.advanced:
        return 'Advanced French';
    }
  }

  String queryForLanguage(String languageCode) {
    final normalizedCode = languageCode.toLowerCase();

    switch (this) {
      case PodcastCategory.popular:
        return switch (normalizedCode) {
          'es' => 'spanish language learning',
          'de' => 'german language learning',
          _ => 'french language learning',
        };
      case PodcastCategory.beginner:
        return switch (normalizedCode) {
          'es' => 'Easy Spanish',
          'de' => 'Easy German',
          _ => 'Easy French',
        };
      case PodcastCategory.intermediate:
        return switch (normalizedCode) {
          'es' => 'Intermediate Spanish',
          'de' => 'Intermediate German',
          _ => 'Intermediate French',
        };
      case PodcastCategory.advanced:
        return switch (normalizedCode) {
          'es' => 'Advanced Spanish',
          'de' => 'Advanced German',
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
