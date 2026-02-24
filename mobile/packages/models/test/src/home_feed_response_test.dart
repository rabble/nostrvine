import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(HomeFeedResponse, () {
    group('constructor', () {
      test('creates instance with required fields', () {
        const response = HomeFeedResponse(videos: []);

        expect(response.videos, isEmpty);
        expect(response.nextCursor, isNull);
        expect(response.hasMore, isFalse);
      });

      test('creates instance with all fields', () {
        final video = VideoStats(
          id: 'abc123',
          pubkey: 'pub123',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
          kind: 34236,
          dTag: 'test',
          title: 'Test',
          thumbnail: '',
          videoUrl: 'https://example.com/video.mp4',
          reactions: 0,
          comments: 0,
          reposts: 0,
          engagementScore: 0,
        );
        final response = HomeFeedResponse(
          videos: [video],
          nextCursor: 1699999000,
          hasMore: true,
        );

        expect(response.videos, hasLength(1));
        expect(response.videos.first.id, equals('abc123'));
        expect(response.nextCursor, equals(1699999000));
        expect(response.hasMore, isTrue);
      });
    });
  });
}
