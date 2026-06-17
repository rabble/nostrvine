// ABOUTME: Tests for ProfileVideoListSnapshot JSON serialization.
// ABOUTME: Pins the CacheSync payload round-trip shared by the profile video
// ABOUTME: tabs (Liked, Reposts, Saved, …).

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_shared/profile_video_list_snapshot.dart';

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
  group(ProfileVideoListSnapshot, () {
    test('round-trips through toJson/fromJson', () {
      final snapshot = ProfileVideoListSnapshot(
        videos: [_video('a'), _video('b')],
        itemIds: const ['a', 'b', 'c'],
        nextPageOffset: 2,
        hasMoreContent: true,
      );

      final restored = ProfileVideoListSnapshot.fromJson(snapshot.toJson());

      expect(restored.videos.map((v) => v.id).toList(), ['a', 'b']);
      expect(restored.itemIds, ['a', 'b', 'c']);
      expect(restored.nextPageOffset, 2);
      expect(restored.hasMoreContent, isTrue);
    });

    test('preserves video order', () {
      final snapshot = ProfileVideoListSnapshot(
        videos: [_video('c'), _video('a'), _video('b')],
        itemIds: const ['c', 'a', 'b'],
        nextPageOffset: 3,
        hasMoreContent: false,
      );

      final restored = ProfileVideoListSnapshot.fromJson(snapshot.toJson());

      expect(restored.videos.map((v) => v.id).toList(), ['c', 'a', 'b']);
    });

    test('round-trips an empty snapshot', () {
      const snapshot = ProfileVideoListSnapshot(
        videos: [],
        itemIds: [],
        nextPageOffset: 0,
        hasMoreContent: false,
      );

      final restored = ProfileVideoListSnapshot.fromJson(snapshot.toJson());

      expect(restored.videos, isEmpty);
      expect(restored.itemIds, isEmpty);
      expect(restored.nextPageOffset, 0);
      expect(restored.hasMoreContent, isFalse);
    });
  });
}
