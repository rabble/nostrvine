import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

void main() {
  group(PopularVideosPage, () {
    VideoEvent createVideo(String id) {
      return VideoEvent(
        id: id,
        pubkey: 'pubkey-$id',
        createdAt: 1000,
        content: '',
        timestamp: DateTime(2025),
      );
    }

    test('stores all fields', () {
      final video = createVideo('v1');
      final page = PopularVideosPage(
        videos: [video],
        hasMore: true,
        nextCursor: 'o:28',
      );

      expect(page.videos, [video]);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'o:28');
    });

    test('defaults pagination metadata to null', () {
      final page = PopularVideosPage(
        videos: [createVideo('v1')],
        hasMore: false,
      );

      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });

    test('supports equality', () {
      final video = createVideo('v1');
      final page1 = PopularVideosPage(
        videos: [video],
        hasMore: true,
        nextCursor: 'o:2',
      );
      final page2 = PopularVideosPage(
        videos: [video],
        hasMore: true,
        nextCursor: 'o:2',
      );

      expect(page1, equals(page2));
      expect(page1.props, [
        [video],
        true,
        'o:2',
      ]);
    });
  });
}
