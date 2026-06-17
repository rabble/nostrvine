// ABOUTME: Tests for ProfileVideoCursorSnapshot JSON serialization.
// ABOUTME: Pins the CacheSync payload round-trip for cursor-paginated tabs.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_shared/profile_snapshot_window.dart';
import 'package:openvine/blocs/profile_shared/profile_video_cursor_snapshot.dart';

VideoEvent _video(String id, {int createdAt = 1704067200}) {
  return VideoEvent(
    id: id,
    pubkey: '0' * 64,
    createdAt: createdAt,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      createdAt * 1000,
      isUtc: true,
    ),
    title: 'Video $id',
    thumbnailUrl: 'https://example.com/$id.jpg',
  );
}

void main() {
  group(ProfileVideoCursorSnapshot, () {
    test('round-trips through toJson/fromJson', () {
      final snapshot = ProfileVideoCursorSnapshot(
        videos: [_video('a'), _video('b')],
        paginationCursor: 1704067200,
        hasMoreContent: true,
      );

      final restored = ProfileVideoCursorSnapshot.fromJson(snapshot.toJson());

      expect(restored.videos.map((v) => v.id).toList(), ['a', 'b']);
      expect(restored.paginationCursor, 1704067200);
      expect(restored.hasMoreContent, isTrue);
    });

    test('round-trips a null cursor (end of feed)', () {
      const snapshot = ProfileVideoCursorSnapshot(
        videos: [],
        paginationCursor: null,
        hasMoreContent: false,
      );

      final restored = ProfileVideoCursorSnapshot.fromJson(snapshot.toJson());

      expect(restored.videos, isEmpty);
      expect(restored.paginationCursor, isNull);
      expect(restored.hasMoreContent, isFalse);
    });

    group('.capped', () {
      const max = ProfileSnapshotWindow.maxItems;

      test('returns the videos unchanged when within the window', () {
        final snapshot = ProfileVideoCursorSnapshot.capped(
          videos: [_video('a'), _video('b')],
          paginationCursor: 1704067200,
          hasMoreContent: false,
        );

        expect(snapshot.videos.length, 2);
        expect(snapshot.paginationCursor, 1704067200);
        expect(snapshot.hasMoreContent, isFalse);
      });

      test(
        'truncates to the head and re-anchors the cursor to the last kept '
        'video',
        () {
          // Feed order is most-recent-first → createdAt decreases with index.
          final videos = List.generate(
            max + 30,
            (i) => _video('v$i', createdAt: 2000000000 - i),
          );

          final snapshot = ProfileVideoCursorSnapshot.capped(
            videos: videos,
            paginationCursor: 1000, // stale cursor from the full set's tail
            hasMoreContent: false,
          );

          expect(snapshot.videos.length, max);
          expect(snapshot.videos.last.id, 'v${max - 1}');
          // Cursor follows the last KEPT video so load-more continues right
          // after the persisted window rather than skipping the dropped tail.
          expect(snapshot.paginationCursor, 2000000000 - (max - 1));
          expect(snapshot.hasMoreContent, isTrue);
        },
      );
    });
  });
}
