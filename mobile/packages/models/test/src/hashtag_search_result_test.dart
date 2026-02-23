// ABOUTME: Tests for HashtagSearchResult model.
// ABOUTME: Tests JSON parsing, field handling, and equality.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(HashtagSearchResult, () {
    group('constructor', () {
      test('creates instance with required fields', () {
        const result = HashtagSearchResult(tag: 'bitcoin');

        expect(result.tag, equals('bitcoin'));
        expect(result.videoCount, isNull);
        expect(result.score, isNull);
        expect(result.totalViews, isNull);
        expect(result.momentum, isNull);
      });

      test('creates instance with all optional fields', () {
        const result = HashtagSearchResult(
          tag: 'nostr',
          videoCount: 156,
          score: 95.2,
          totalViews: 45000,
          momentum: 1.8,
        );

        expect(result.tag, equals('nostr'));
        expect(result.videoCount, equals(156));
        expect(result.score, equals(95.2));
        expect(result.totalViews, equals(45000));
        expect(result.momentum, equals(1.8));
      });
    });

    group('fromJson', () {
      test('parses hashtag field', () {
        final json = {
          'hashtag': 'bitcoin',
          'video_count': 156,
        };

        final result = HashtagSearchResult.fromJson(json);

        expect(result.tag, equals('bitcoin'));
        expect(result.videoCount, equals(156));
      });

      test('falls back to tag field when hashtag is absent', () {
        final json = {
          'tag': 'funny',
          'score': 95.2,
        };

        final result = HashtagSearchResult.fromJson(json);

        expect(result.tag, equals('funny'));
        expect(result.score, equals(95.2));
      });

      test('hashtag field takes precedence over tag field', () {
        final json = {
          'hashtag': 'preferred',
          'tag': 'fallback',
        };

        final result = HashtagSearchResult.fromJson(json);

        expect(result.tag, equals('preferred'));
      });

      test('parses video_count as int', () {
        final json = {
          'hashtag': 'test',
          'video_count': 42,
        };

        final result = HashtagSearchResult.fromJson(json);

        expect(result.videoCount, equals(42));
      });

      test('parses video_count as string', () {
        final json = {
          'hashtag': 'test',
          'video_count': '100',
        };

        final result = HashtagSearchResult.fromJson(json);

        expect(result.videoCount, equals(100));
      });

      test('parses videoCount (camelCase) as int', () {
        final json = {
          'tag': 'test',
          'videoCount': 200,
        };

        final result = HashtagSearchResult.fromJson(json);

        expect(result.videoCount, equals(200));
      });

      test('parses score as double', () {
        final json = {
          'hashtag': 'trending',
          'score': 95.2,
        };

        final result = HashtagSearchResult.fromJson(json);

        expect(result.score, equals(95.2));
      });

      test('parses score from int', () {
        final json = {
          'hashtag': 'trending',
          'score': 95,
        };

        final result = HashtagSearchResult.fromJson(json);

        expect(result.score, equals(95.0));
      });

      test('parses totalViews from total_views (snake_case)', () {
        final json = {
          'hashtag': 'popular',
          'total_views': 45000,
        };

        final result = HashtagSearchResult.fromJson(json);

        expect(result.totalViews, equals(45000));
      });

      test('parses totalViews from totalViews (camelCase)', () {
        final json = {
          'tag': 'popular',
          'totalViews': 30000.5,
        };

        final result = HashtagSearchResult.fromJson(json);

        expect(result.totalViews, equals(30000.5));
      });

      test('parses momentum', () {
        final json = {
          'tag': 'rising',
          'momentum': 1.8,
        };

        final result = HashtagSearchResult.fromJson(json);

        expect(result.momentum, equals(1.8));
      });

      test('handles missing optional fields', () {
        final json = {'hashtag': 'minimal'};

        final result = HashtagSearchResult.fromJson(json);

        expect(result.tag, equals('minimal'));
        expect(result.videoCount, isNull);
        expect(result.score, isNull);
        expect(result.totalViews, isNull);
        expect(result.momentum, isNull);
      });

      test('handles missing tag field', () {
        final json = <String, dynamic>{'video_count': 10};

        final result = HashtagSearchResult.fromJson(json);

        expect(result.tag, isEmpty);
      });

      test('parses all fields from trending endpoint format', () {
        final json = {
          'tag': 'funny',
          'score': 95.2,
          'videoCount': 156,
          'totalViews': 45000,
          'momentum': 1.8,
        };

        final result = HashtagSearchResult.fromJson(json);

        expect(result.tag, equals('funny'));
        expect(result.score, equals(95.2));
        expect(result.videoCount, equals(156));
        expect(result.totalViews, equals(45000));
        expect(result.momentum, equals(1.8));
      });

      test('parses all fields from search endpoint format', () {
        final json = {
          'hashtag': 'bitcoin',
          'video_count': 156,
        };

        final result = HashtagSearchResult.fromJson(json);

        expect(result.tag, equals('bitcoin'));
        expect(result.videoCount, equals(156));
        expect(result.score, isNull);
        expect(result.totalViews, isNull);
        expect(result.momentum, isNull);
      });
    });

    group('equality', () {
      test('two instances with same tag are equal', () {
        const result1 = HashtagSearchResult(
          tag: 'bitcoin',
          videoCount: 100,
        );

        const result2 = HashtagSearchResult(
          tag: 'bitcoin',
          videoCount: 200,
        );

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('two instances with different tags are not equal', () {
        const result1 = HashtagSearchResult(tag: 'bitcoin');
        const result2 = HashtagSearchResult(tag: 'nostr');

        expect(result1, isNot(equals(result2)));
      });
    });

    group('toString', () {
      test('returns formatted string with tag and videoCount', () {
        const result = HashtagSearchResult(
          tag: 'bitcoin',
          videoCount: 156,
        );

        expect(
          result.toString(),
          equals('HashtagSearchResult(tag: bitcoin, videoCount: 156)'),
        );
      });

      test('returns formatted string with null videoCount', () {
        const result = HashtagSearchResult(tag: 'nostr');

        expect(
          result.toString(),
          equals('HashtagSearchResult(tag: nostr, videoCount: null)'),
        );
      });
    });
  });
}
