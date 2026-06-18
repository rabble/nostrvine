// ABOUTME: Tests for ProfileVideoOffsetSnapshot JSON serialization.
// ABOUTME: Pins the CacheSync payload round-trip for the offset-paginated
// ABOUTME: Videos tab, plus the head-cap / offset-clamp policy.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_shared/profile_snapshot_window.dart';
import 'package:openvine/blocs/profile_shared/profile_video_offset_snapshot.dart';

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
  group(ProfileVideoOffsetSnapshot, () {
    test('round-trips through toJson/fromJson', () {
      final snapshot = ProfileVideoOffsetSnapshot(
        videos: [_video('a'), _video('b')],
        nextOffset: 50,
        totalVideoCount: 120,
        hasMoreContent: true,
      );

      final restored = ProfileVideoOffsetSnapshot.fromJson(snapshot.toJson());

      expect(restored.videos.map((v) => v.id).toList(), ['a', 'b']);
      expect(restored.nextOffset, 50);
      expect(restored.totalVideoCount, 120);
      expect(restored.hasMoreContent, isTrue);
    });

    test('round-trips a null offset (Nostr-fallback) and null total', () {
      const snapshot = ProfileVideoOffsetSnapshot(
        videos: [],
        nextOffset: null,
        totalVideoCount: null,
        hasMoreContent: false,
      );

      final restored = ProfileVideoOffsetSnapshot.fromJson(snapshot.toJson());

      expect(restored.videos, isEmpty);
      expect(restored.nextOffset, isNull);
      expect(restored.totalVideoCount, isNull);
      expect(restored.hasMoreContent, isFalse);
    });

    group('.capped', () {
      const max = ProfileSnapshotWindow.maxItems;

      test('returns the videos unchanged when within the window', () {
        final snapshot = ProfileVideoOffsetSnapshot.capped(
          videos: [_video('a'), _video('b')],
          nextOffset: 2,
          totalVideoCount: 2,
          hasMoreContent: false,
        );

        expect(snapshot.videos.length, 2);
        expect(snapshot.nextOffset, 2);
        expect(snapshot.totalVideoCount, 2);
        expect(snapshot.hasMoreContent, isFalse);
      });

      test('truncates to the head and clamps the offset into the kept range', () {
        final videos = List.generate(max + 30, (i) => _video('v$i'));

        final snapshot = ProfileVideoOffsetSnapshot.capped(
          videos: videos,
          nextOffset: max + 30, // offset of the full (uncapped) tail
          totalVideoCount: 500,
          hasMoreContent: false,
        );

        expect(snapshot.videos.length, max);
        expect(snapshot.videos.last.id, 'v${max - 1}');
        // Resumes REST pagination at the boundary of the persisted window so a
        // load-more after reopen re-fetches the boundary page (deduped) rather
        // than skipping the dropped tail.
        expect(snapshot.nextOffset, max);
        expect(snapshot.totalVideoCount, 500);
        expect(snapshot.hasMoreContent, isTrue);
      });

      test('preserves a null offset when truncating (Nostr-fallback)', () {
        final videos = List.generate(max + 5, (i) => _video('v$i'));

        final snapshot = ProfileVideoOffsetSnapshot.capped(
          videos: videos,
          nextOffset: null,
          totalVideoCount: null,
          hasMoreContent: false,
        );

        expect(snapshot.videos.length, max);
        expect(snapshot.nextOffset, isNull);
        expect(snapshot.hasMoreContent, isTrue);
      });
    });
  });
}
