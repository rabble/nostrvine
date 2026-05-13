import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

void main() {
  group(NativePopularVideosPage, () {
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
      final page = NativePopularVideosPage(
        videos: [video],
        consumedItemCount: 3,
        nextOffset: 28,
      );

      expect(page.videos, [video]);
      expect(page.consumedItemCount, 3);
      expect(page.nextOffset, 28);
    });

    test('defaults pagination metadata to null', () {
      final page = NativePopularVideosPage(videos: [createVideo('v1')]);

      expect(page.consumedItemCount, isNull);
      expect(page.nextOffset, isNull);
    });

    test('supports equality', () {
      final video = createVideo('v1');
      final page1 = NativePopularVideosPage(
        videos: [video],
        consumedItemCount: 1,
        nextOffset: 2,
      );
      final page2 = NativePopularVideosPage(
        videos: [video],
        consumedItemCount: 1,
        nextOffset: 2,
      );

      expect(page1, equals(page2));
      expect(page1.props, [
        [video],
        1,
        2,
      ]);
    });
  });
}
