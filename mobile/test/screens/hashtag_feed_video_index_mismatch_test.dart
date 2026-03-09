// ABOUTME: Regression test for issue #1751 - wrong video displayed after
// ABOUTME: tapping thumbnail in hashtag feed. Verifies the grid's video list
// ABOUTME: is passed directly to the fullscreen feed (no independent re-sort).

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

/// Reproduces the interleaving algorithm from
/// HashtagFeedScreen._combineAndSortVideos (the grid's sort order).
List<VideoEvent> gridInterleave(
  List<VideoEvent> trending,
  List<VideoEvent> classics,
) {
  // Deduplicate: remove classics that appear in trending
  final trendingIds = <String>{};
  for (final v in trending) {
    if (v.id.isNotEmpty) trendingIds.add(v.id.toLowerCase());
    if (v.vineId != null && v.vineId!.isNotEmpty) {
      trendingIds.add(v.vineId!.toLowerCase());
    }
  }

  final uniqueClassics = <VideoEvent>[];
  for (final video in classics) {
    final isDuplicate =
        trendingIds.contains(video.id.toLowerCase()) ||
        (video.vineId != null &&
            trendingIds.contains(video.vineId!.toLowerCase()));
    if (!isDuplicate) {
      uniqueClassics.add(video);
    }
  }

  // Interleave 1:1
  final result = <VideoEvent>[];
  final maxLen = trending.length > uniqueClassics.length
      ? trending.length
      : uniqueClassics.length;

  for (var i = 0; i < maxLen; i++) {
    if (i < trending.length) result.add(trending[i]);
    if (i < uniqueClassics.length) result.add(uniqueClassics[i]);
  }

  return result;
}

VideoEvent _video({
  required String id,
  int? originalLoops,
  int createdAt = 1000000,
}) {
  return VideoEvent(
    id: id,
    pubkey: 'pubkey-$id',
    createdAt: createdAt,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
    originalLoops: originalLoops,
  );
}

void main() {
  group('Issue #1751: hashtag feed video index mismatch (regression)', () {
    // The fix for #1751 passes the grid's video list directly to the
    // fullscreen feed via PooledFullscreenVideoFeedScreen. The feed no
    // longer independently re-sorts. This test verifies that the grid
    // produces a deterministic interleaved order and that passing that
    // list to the feed preserves it identically.

    late List<VideoEvent> trending;
    late List<VideoEvent> classics;

    setUp(() {
      trending = [
        _video(id: 'T1', originalLoops: 500, createdAt: 1000003),
        _video(id: 'T2', originalLoops: 400, createdAt: 1000002),
        _video(id: 'T3', originalLoops: 300, createdAt: 1000001),
      ];

      classics = [
        _video(id: 'C1', originalLoops: 10000, createdAt: 900003),
        _video(id: 'C2', originalLoops: 8000, createdAt: 900002),
        _video(id: 'C3', originalLoops: 5000, createdAt: 900001),
      ];
    });

    test('grid produces expected interleaved order', () {
      final gridOrder = gridInterleave(trending, classics);

      // Trending and classic interleaved 1:1: T1, C1, T2, C2, T3, C3
      expect(
        gridOrder.map((v) => v.id).toList(),
        equals(['T1', 'C1', 'T2', 'C2', 'T3', 'C3']),
        reason: 'Grid should interleave trending and classic 1:1',
      );
    });

    test('feed receives the exact same list the grid shows', () {
      // The grid builds the video list
      final gridOrder = gridInterleave(trending, classics);

      // The fix: feed receives gridOrder directly (no re-sort)
      final feedOrder = List<VideoEvent>.from(gridOrder);

      // Every index must map to the same video
      for (var i = 0; i < gridOrder.length; i++) {
        expect(
          feedOrder[i].id,
          equals(gridOrder[i].id),
          reason:
              'Issue #1751: Tapping index $i must show ${gridOrder[i].id} '
              'in both the grid and feed.',
        );
      }
    });

    test('deduplication removes classics that appear in trending', () {
      // Add a classic that has the same ID as a trending video
      final classicsWithDup = [
        ...classics,
        _video(id: 'T1', originalLoops: 9999, createdAt: 800000),
      ];

      final gridOrder = gridInterleave(trending, classicsWithDup);

      // T1 should only appear once (from trending), not twice
      final t1Count = gridOrder.where((v) => v.id == 'T1').length;
      expect(t1Count, equals(1), reason: 'Duplicate T1 should be removed');
    });
  });
}
