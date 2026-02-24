import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(RecommendationsResponse, () {
    group('constructor', () {
      test('creates instance with required fields', () {
        const response = RecommendationsResponse(
          videos: [],
          source: 'popular',
        );

        expect(response.videos, isEmpty);
        expect(response.source, equals('popular'));
      });
    });

    group('isPersonalized', () {
      test('returns true when source is personalized', () {
        const response = RecommendationsResponse(
          videos: [],
          source: 'personalized',
        );

        expect(response.isPersonalized, isTrue);
      });

      test('returns false when source is popular', () {
        const response = RecommendationsResponse(
          videos: [],
          source: 'popular',
        );

        expect(response.isPersonalized, isFalse);
      });

      test('returns false when source is recent', () {
        const response = RecommendationsResponse(
          videos: [],
          source: 'recent',
        );

        expect(response.isPersonalized, isFalse);
      });

      test('returns false when source is error', () {
        const response = RecommendationsResponse(
          videos: [],
          source: 'error',
        );

        expect(response.isPersonalized, isFalse);
      });
    });
  });
}
