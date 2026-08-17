import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(TrendingHashtag, () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final hashtag = TrendingHashtag(
          tag: 'flutter',
          videoCount: 42,
        );

        expect(hashtag.tag, equals('flutter'));
        expect(hashtag.videoCount, equals(42));
        expect(hashtag.uniqueCreators, equals(0));
        expect(hashtag.totalLoops, equals(0));
        expect(hashtag.lastUsed, isNull);
      });

      test('creates instance with all fields', () {
        final lastUsed = DateTime(2024);
        final hashtag = TrendingHashtag(
          tag: 'dart',
          videoCount: 100,
          uniqueCreators: 20,
          totalLoops: 5000,
          lastUsed: lastUsed,
        );

        expect(hashtag.tag, equals('dart'));
        expect(hashtag.videoCount, equals(100));
        expect(hashtag.uniqueCreators, equals(20));
        expect(hashtag.totalLoops, equals(5000));
        expect(hashtag.lastUsed, equals(lastUsed));
      });
    });

    group('fromJson', () {
      test('parses with hashtag key', () {
        final hashtag = TrendingHashtag.fromJson(const {
          'hashtag': 'flutter',
          'video_count': 42,
        });

        expect(hashtag.tag, equals('flutter'));
        expect(hashtag.videoCount, equals(42));
      });

      test('parses with tag key', () {
        final hashtag = TrendingHashtag.fromJson(const {
          'tag': 'dart',
          'video_count': 10,
        });

        expect(hashtag.tag, equals('dart'));
      });

      test('parses camelCase field names', () {
        final hashtag = TrendingHashtag.fromJson(const {
          'tag': 'nostr',
          'videoCount': 50,
          'uniqueCreators': 15,
          'totalLoops': 3000,
        });

        expect(hashtag.videoCount, equals(50));
        expect(hashtag.uniqueCreators, equals(15));
        expect(hashtag.totalLoops, equals(3000));
      });

      test('parses snake_case field names', () {
        final hashtag = TrendingHashtag.fromJson(const {
          'tag': 'nostr',
          'video_count': 50,
          'unique_creators': 15,
          'total_loops': 3000,
        });

        expect(hashtag.videoCount, equals(50));
        expect(hashtag.uniqueCreators, equals(15));
        expect(hashtag.totalLoops, equals(3000));
      });

      test('parses last_used as Unix timestamp', () {
        final hashtag = TrendingHashtag.fromJson(const {
          'tag': 'test',
          'video_count': 1,
          'last_used': 1700000000,
        });

        expect(hashtag.lastUsed, isNotNull);
        expect(
          hashtag.lastUsed,
          equals(
            DateTime.fromMillisecondsSinceEpoch(
              1700000000 * 1000,
            ),
          ),
        );
      });

      test('parses last_used as ISO string', () {
        final hashtag = TrendingHashtag.fromJson(const {
          'tag': 'test',
          'video_count': 1,
          'last_used': '2024-01-01T00:00:00Z',
        });

        expect(hashtag.lastUsed, isNotNull);
        expect(
          hashtag.lastUsed,
          equals(DateTime.parse('2024-01-01T00:00:00Z')),
        );
      });

      test('handles missing fields with defaults', () {
        final hashtag = TrendingHashtag.fromJson(
          const <String, dynamic>{},
        );

        expect(hashtag.tag, isEmpty);
        expect(hashtag.videoCount, equals(0));
        expect(hashtag.uniqueCreators, equals(0));
        expect(hashtag.totalLoops, equals(0));
        expect(hashtag.lastUsed, isNull);
      });
    });

    group('equality', () {
      test('two hashtags with same tag are equal', () {
        final a = TrendingHashtag(tag: 'flutter', videoCount: 1);
        final b = TrendingHashtag(tag: 'flutter', videoCount: 99);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('two hashtags with different tags are not equal', () {
        final a = TrendingHashtag(tag: 'flutter', videoCount: 1);
        final b = TrendingHashtag(tag: 'dart', videoCount: 1);

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        final hashtag = TrendingHashtag(
          tag: 'flutter',
          videoCount: 42,
        );

        expect(
          hashtag.toString(),
          equals(
            'TrendingHashtag(tag: flutter, videoCount: 42)',
          ),
        );
      });
    });

    group('UTF-16 well-formedness', () {
      // The headless flutter_tester does not throw on a lone surrogate — only
      // the real engine does — so this asserts the model value rather than the
      // rendered chip label.
      test('replaces a lone surrogate in tag', () {
        final hashtag = TrendingHashtag(
          tag: 'sun${String.fromCharCode(0xD83D)}set',
          videoCount: 42,
        );

        expect(hashtag.tag, equals('sun\uFFFDset'));
      });

      test('keeps a well-formed tag identical', () {
        const tag = 'sunset\u{1F600}';

        expect(TrendingHashtag(tag: tag, videoCount: 42).tag, same(tag));
      });

      test('sanitizes a tag parsed from JSON', () {
        final hashtag = TrendingHashtag.fromJson({
          'hashtag': 'sun${String.fromCharCode(0xD83D)}set',
          'video_count': 3,
        });

        expect(hashtag.tag, equals('sun\uFFFDset'));
      });
    });
  });
}
