// ABOUTME: Tests for ProfileVideoCursorSnapshot JSON serialization.
// ABOUTME: Pins the CacheSync payload round-trip for cursor-paginated tabs.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_shared/profile_video_cursor_snapshot.dart';

VideoEvent _video(String id) {
  final now = DateTime.fromMillisecondsSinceEpoch(
    1704067200 * 1000,
    isUtc: true,
  );
  return VideoEvent(
    id: id,
    pubkey: '0' * 64,
    createdAt: 1704067200,
    content: '',
    timestamp: now,
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
  });
}
