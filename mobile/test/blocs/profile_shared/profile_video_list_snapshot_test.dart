// ABOUTME: Tests for ProfileVideoListSnapshot JSON serialization.
// ABOUTME: Pins the CacheSync payload round-trip shared by the profile video
// ABOUTME: tabs (Liked, Reposts, Saved, …).

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_shared/profile_snapshot_window.dart';
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

    group('.capped', () {
      const max = ProfileSnapshotWindow.maxItems;

      test('returns the lists unchanged when within the window', () {
        final snapshot = ProfileVideoListSnapshot.capped(
          videos: [_video('a'), _video('b')],
          itemIds: const ['a', 'b', 'c'],
          nextPageOffset: 2,
          hasMoreContent: false,
        );

        expect(snapshot.videos.map((v) => v.id).toList(), ['a', 'b']);
        expect(snapshot.itemIds, ['a', 'b', 'c']);
        expect(snapshot.nextPageOffset, 2);
        expect(snapshot.hasMoreContent, isFalse);
      });

      test(
        'truncates both lists to the head, clamps the offset, and forces '
        'hasMoreContent',
        () {
          final videos = List.generate(max + 50, (i) => _video('v$i'));
          final ids = List.generate(max + 500, (i) => 'v$i');

          final snapshot = ProfileVideoListSnapshot.capped(
            videos: videos,
            itemIds: ids,
            nextPageOffset: max + 400,
            // even with hasMoreContent already false, truncation must flip it
            hasMoreContent: false,
          );

          expect(snapshot.videos.length, max);
          expect(snapshot.videos.first.id, 'v0');
          expect(snapshot.videos.last.id, 'v${max - 1}');
          expect(snapshot.itemIds.length, max);
          expect(snapshot.itemIds.last, 'v${max - 1}');
          expect(snapshot.nextPageOffset, max);
          expect(snapshot.hasMoreContent, isTrue);
        },
      );

      test('caps a long id list even when the videos fit', () {
        final snapshot = ProfileVideoListSnapshot.capped(
          videos: [_video('a'), _video('b')],
          itemIds: List.generate(max + 1000, (i) => 'id$i'),
          nextPageOffset: 2,
          hasMoreContent: false,
        );

        expect(snapshot.videos.length, 2);
        expect(snapshot.itemIds.length, max);
        expect(snapshot.nextPageOffset, 2);
        expect(snapshot.hasMoreContent, isTrue);
      });
    });
  });
}
