import 'package:flutter_test/flutter_test.dart';
import 'package:pareto_lingo/features/podcast/domain/entities/podcast_category.dart';

void main() {
  group('PodcastCategory mapping', () {
    test('query values are stable', () {
      expect(PodcastCategory.popular.query, 'france');
      expect(PodcastCategory.beginner.query, 'Easy French');
      expect(PodcastCategory.intermediate.query, 'Intermediate French');
      expect(PodcastCategory.advanced.query, 'Advanced French');
    });

    test('limits are correct per category', () {
      expect(PodcastCategory.popular.limit, 100);
      expect(PodcastCategory.beginner.limit, 20);
      expect(PodcastCategory.intermediate.limit, 20);
      expect(PodcastCategory.advanced.limit, 20);
    });
  });
}
