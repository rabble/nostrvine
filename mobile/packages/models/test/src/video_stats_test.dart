// ABOUTME: Tests for VideoStats model.
// ABOUTME: Tests JSON parsing, field handling, and VideoEvent conversion.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('VideoStats', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test Video',
          thumbnail: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/video.mp4',
          reactions: 10,
          comments: 5,
          reposts: 2,
          engagementScore: 17,
        );

        expect(stats.id, equals('test-id'));
        expect(stats.pubkey, equals('test-pubkey'));
        expect(stats.kind, equals(34236));
        expect(stats.title, equals('Test Video'));
        expect(stats.reactions, equals(10));
      });

      test('creates instance with optional fields', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test Video',
          description: 'A description',
          thumbnail: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/video.mp4',
          sha256: 'abc123',
          authorName: 'Test Author',
          authorAvatar: 'https://example.com/avatar.jpg',
          blurhash: 'LEHV6nWB2yk8',
          reactions: 10,
          comments: 5,
          reposts: 2,
          engagementScore: 17,
          trendingScore: 0.85,
          loops: 1000,
        );

        expect(stats.description, equals('A description'));
        expect(stats.sha256, equals('abc123'));
        expect(stats.authorName, equals('Test Author'));
        expect(stats.blurhash, equals('LEHV6nWB2yk8'));
        expect(stats.trendingScore, equals(0.85));
        expect(stats.loops, equals(1000));
      });
    });

    group('fromJson', () {
      test('parses basic flat JSON', () {
        final json = {
          'id': 'abc123',
          'pubkey': 'pub456',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'My Video',
          'content': 'Video description',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 100,
          'comments': 20,
          'reposts': 5,
          'engagement_score': 125,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.id, equals('abc123'));
        expect(stats.pubkey, equals('pub456'));
        expect(stats.kind, equals(34236));
        expect(stats.dTag, equals('video-1'));
        expect(stats.title, equals('My Video'));
        expect(stats.description, equals('Video description'));
        expect(stats.reactions, equals(100));
        expect(stats.engagementScore, equals(125));
      });

      test('parses nested event/stats format', () {
        final json = {
          'event': {
            'id': 'event-id',
            'pubkey': 'event-pubkey',
            'created_at': 1700000000,
            'kind': 34236,
            'd_tag': 'nested-video',
            'title': 'Nested Title',
            'content': 'Nested description',
            'thumbnail': 'https://example.com/thumb.jpg',
            'video_url': 'https://example.com/video.mp4',
          },
          'stats': {
            'reactions': 50,
            'comments': 10,
            'reposts': 3,
            'engagement_score': 63,
            'trending_score': 0.75,
          },
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.id, equals('event-id'));
        expect(stats.pubkey, equals('event-pubkey'));
        expect(stats.title, equals('Nested Title'));
        expect(stats.reactions, equals(50));
        expect(stats.trendingScore, equals(0.75));
      });

      test('parses id as byte array (ASCII codes)', () {
        final json = {
          'id': [97, 98, 99, 49, 50, 51], // 'abc123' as ASCII codes
          'pubkey': 'pub456',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.id, equals('abc123'));
      });

      test('parses pubkey as byte array (ASCII codes)', () {
        final json = {
          'id': 'test-id',
          'pubkey': [112, 117, 98, 52, 53, 54], // 'pub456' as ASCII codes
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.pubkey, equals('pub456'));
      });

      test('normalizes uppercase id to lowercase', () {
        final json = {
          'id': 'ABCDEF1234567890',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.id, equals('abcdef1234567890'));
      });

      test('normalizes uppercase pubkey to lowercase', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'ABCDEF1234567890',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.pubkey, equals('abcdef1234567890'));
      });

      test('normalizes uppercase byte array id to lowercase', () {
        // 'ABCD' as ASCII codes: A=65, B=66, C=67, D=68
        final json = {
          'id': [65, 66, 67, 68, 69, 70],
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.id, equals('abcdef'));
      });

      test('parses created_at as Unix timestamp', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(
          stats.createdAt,
          equals(DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000)),
        );
      });

      test('parses created_at as ISO string', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': '2024-01-15T12:00:00.000Z',
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.createdAt.year, equals(2024));
        expect(stats.createdAt.month, equals(1));
        expect(stats.createdAt.day, equals(15));
      });

      test('extracts fields from tags array', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'tags': [
            ['title', 'Title from tag'],
            ['thumb', 'https://example.com/thumb-from-tag.jpg'],
            ['url', 'https://example.com/video-from-tag.mp4'],
            ['d', 'dtag-from-tag'],
            ['x', 'sha256-from-tag'],
            ['blurhash', 'LEHV6nWB'],
            ['summary', 'Summary from tag'],
            ['loops', '5000'],
          ],
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.title, equals('Title from tag'));
        expect(
          stats.thumbnail,
          equals('https://example.com/thumb-from-tag.jpg'),
        );
        expect(
          stats.videoUrl,
          equals('https://example.com/video-from-tag.mp4'),
        );
        expect(stats.dTag, equals('dtag-from-tag'));
        expect(stats.sha256, equals('sha256-from-tag'));
        expect(stats.blurhash, equals('LEHV6nWB'));
        expect(stats.description, equals('Summary from tag'));
        expect(stats.loops, equals(5000));
      });

      test('prefers content over summary tag for description', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'content': 'Content description',
          'tags': [
            ['summary', 'Summary description'],
          ],
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.description, equals('Content description'));
      });

      test('handles alternative field names for reactions', () {
        final jsonWithEmbeddedLikes = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'embedded_likes': 42,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(jsonWithEmbeddedLikes);

        expect(stats.reactions, equals(42));
      });

      test('handles loops in different formats', () {
        // As int
        final jsonWithIntLoops = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'loops': 1000,
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        expect(VideoStats.fromJson(jsonWithIntLoops).loops, equals(1000));

        // As string
        final jsonWithStringLoops = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'loops': '2000',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        expect(VideoStats.fromJson(jsonWithStringLoops).loops, equals(2000));
      });

      test('handles trending_score as int and double', () {
        final jsonWithIntScore = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
          'trending_score': 1,
        };

        expect(
          VideoStats.fromJson(jsonWithIntScore).trendingScore,
          equals(1.0),
        );

        final jsonWithDoubleScore = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
          'trending_score': 0.85,
        };

        expect(
          VideoStats.fromJson(jsonWithDoubleScore).trendingScore,
          equals(0.85),
        );
      });

      test('normalizes empty values to null', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'content': '',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'sha256': '',
          'author_name': '',
          'author_avatar': '',
          'blurhash': '',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.description, isNull);
        expect(stats.sha256, isNull);
        expect(stats.authorName, isNull);
        expect(stats.authorAvatar, isNull);
        expect(stats.blurhash, isNull);
      });

      test('defaults kind to 34236 when missing', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.kind, equals(34236));
      });
    });

    group('toVideoEvent', () {
      test('converts to VideoEvent with all fields', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test Video',
          description: 'A description',
          thumbnail: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/video.mp4',
          sha256: 'abc123',
          authorName: 'Test Author',
          authorAvatar: 'https://example.com/avatar.jpg',
          blurhash: 'LEHV6nWB2yk8',
          reactions: 100,
          comments: 20,
          reposts: 5,
          engagementScore: 125,
          loops: 1000,
        );

        final videoEvent = stats.toVideoEvent();

        expect(videoEvent.id, equals('test-id'));
        expect(videoEvent.pubkey, equals('test-pubkey'));
        expect(videoEvent.createdAt, equals(1700000000));
        expect(videoEvent.content, equals('A description'));
        expect(videoEvent.title, equals('Test Video'));
        expect(videoEvent.videoUrl, equals('https://example.com/video.mp4'));
        expect(
          videoEvent.thumbnailUrl,
          equals('https://example.com/thumb.jpg'),
        );
        expect(videoEvent.vineId, equals('test-dtag'));
        expect(videoEvent.sha256, equals('abc123'));
        expect(videoEvent.authorName, equals('Test Author'));
        expect(
          videoEvent.authorAvatar,
          equals('https://example.com/avatar.jpg'),
        );
        expect(videoEvent.blurhash, equals('LEHV6nWB2yk8'));
        expect(videoEvent.originalLikes, equals(100));
        expect(videoEvent.originalComments, equals(20));
        expect(videoEvent.originalReposts, equals(5));
        expect(videoEvent.originalLoops, equals(1000));
      });

      test('handles empty strings by converting to null', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: '',
          title: '',
          thumbnail: '',
          videoUrl: '',
          reactions: 0,
          comments: 0,
          reposts: 0,
          engagementScore: 0,
        );

        final videoEvent = stats.toVideoEvent();

        expect(videoEvent.title, isNull);
        expect(videoEvent.videoUrl, isNull);
        expect(videoEvent.thumbnailUrl, isNull);
        // When dTag is empty, vineId falls back to the event id.
        expect(videoEvent.vineId, equals('test-id'));
      });

      test('handles null description', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test',
          thumbnail: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/video.mp4',
          reactions: 0,
          comments: 0,
          reposts: 0,
          engagementScore: 0,
        );

        final videoEvent = stats.toVideoEvent();

        expect(videoEvent.content, equals(''));
      });
    });

    group('equality', () {
      test('two instances with same id are equal', () {
        final stats1 = VideoStats(
          id: 'same-id',
          pubkey: 'pubkey1',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'dtag1',
          title: 'Title 1',
          thumbnail: 'thumb1',
          videoUrl: 'video1',
          reactions: 10,
          comments: 5,
          reposts: 2,
          engagementScore: 17,
        );

        final stats2 = VideoStats(
          id: 'same-id',
          pubkey: 'pubkey2',
          createdAt: DateTime(2025),
          kind: 34236,
          dTag: 'dtag2',
          title: 'Title 2',
          thumbnail: 'thumb2',
          videoUrl: 'video2',
          reactions: 20,
          comments: 10,
          reposts: 4,
          engagementScore: 34,
        );

        expect(stats1, equals(stats2));
        expect(stats1.hashCode, equals(stats2.hashCode));
      });

      test('two instances with different ids are not equal', () {
        final stats1 = VideoStats(
          id: 'id-1',
          pubkey: 'pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'dtag',
          title: 'Title',
          thumbnail: 'thumb',
          videoUrl: 'video',
          reactions: 10,
          comments: 5,
          reposts: 2,
          engagementScore: 17,
        );

        final stats2 = VideoStats(
          id: 'id-2',
          pubkey: 'pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'dtag',
          title: 'Title',
          thumbnail: 'thumb',
          videoUrl: 'video',
          reactions: 10,
          comments: 5,
          reposts: 2,
          engagementScore: 17,
        );

        expect(stats1, isNot(equals(stats2)));
      });
    });

    group('toString', () {
      test('returns formatted string with id and title', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'My Video Title',
          thumbnail: 'thumb',
          videoUrl: 'video',
          reactions: 10,
          comments: 5,
          reposts: 2,
          engagementScore: 17,
        );

        expect(
          stats.toString(),
          equals('VideoStats(id: test-id, title: My Video Title)'),
        );
      });
    });
  });
}
