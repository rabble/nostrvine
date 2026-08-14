// ABOUTME: Owns per-author video buckets and memoized sorted profile views.
// ABOUTME: Keeps profile feed reads identity-stable until an author's bucket changes.

import 'package:models/models.dart';

typedef VideoMerge =
    VideoEvent Function(VideoEvent existing, VideoEvent updated);
typedef BucketRemoved = void Function(String authorPubkey, int removedCount);

class AuthorVideoBuckets {
  final Map<String, List<VideoEvent>> _buckets = {};
  final Map<String, List<VideoEvent>> _sortedViews = {};

  bool contains(String authorPubkey) => _buckets.containsKey(authorPubkey);

  void seed(String authorPubkey, List<VideoEvent> videos) {
    _buckets[authorPubkey] = List.of(videos);
    _invalidate(authorPubkey);
  }

  Iterable<VideoEvent> videosForAuthorUnsorted(String authorPubkey) sync* {
    final videos = _buckets[authorPubkey];
    if (videos != null) yield* videos;
  }

  Iterable<VideoEvent> get allVideos sync* {
    for (final videos in _buckets.values) {
      yield* videos;
    }
  }

  List<VideoEvent> videosFor(String authorPubkey) {
    final bucket = _buckets[authorPubkey];
    if (bucket == null || bucket.isEmpty) return const [];

    return _sortedViews.putIfAbsent(authorPubkey, () {
      final sorted = List<VideoEvent>.from(bucket)..sort(_newestFirstThenId);
      return List<VideoEvent>.unmodifiable(sorted);
    });
  }

  int backfillUniqueById(String authorPubkey, Iterable<VideoEvent> candidates) {
    final bucket = _buckets.putIfAbsent(authorPubkey, () => []);
    final seenBucketIds = {for (final video in bucket) video.id.toLowerCase()};
    var added = 0;

    for (final video in candidates) {
      if (seenBucketIds.add(video.id.toLowerCase())) {
        bucket.add(video);
        added++;
      }
    }

    if (added > 0) _invalidate(authorPubkey);
    return added;
  }

  bool replaceById(String authorPubkey, String videoId, VideoEvent updated) {
    final bucket = _buckets[authorPubkey];
    if (bucket == null) return false;

    final index = bucket.indexWhere((video) => video.id == videoId);
    if (index == -1) return false;

    bucket[index] = updated;
    _invalidate(authorPubkey);
    return true;
  }

  bool addOrUpdateByVine(
    VideoEvent video, {
    required String authorPubkey,
    required bool isHistorical,
  }) {
    final bucket = _buckets.putIfAbsent(authorPubkey, () => []);
    final existingIndex = bucket.indexWhere(
      (existing) =>
          existing.vineId == video.vineId && existing.pubkey == video.pubkey,
    );

    if (existingIndex != -1) {
      if (video.createdAt > bucket[existingIndex].createdAt) {
        bucket[existingIndex] = video;
        _invalidate(authorPubkey);
      }
      return false;
    }

    if (isHistorical) {
      bucket.add(video);
    } else {
      bucket.insert(0, video);
    }
    _invalidate(authorPubkey);
    return true;
  }

  bool replaceByStableId(
    String authorPubkey,
    VideoEvent updated, {
    required VideoMerge merge,
  }) {
    final bucket = _buckets[authorPubkey];
    if (bucket == null) return false;

    final index = bucket.indexWhere(
      (existing) =>
          existing.stableId == updated.stableId &&
          existing.pubkey == updated.pubkey,
    );
    if (index == -1) return false;

    bucket[index] = merge(bucket[index], updated);
    _invalidate(authorPubkey);
    return true;
  }

  int removeWhere(
    bool Function(VideoEvent video) shouldRemove, {
    BucketRemoved? onBucketRemoved,
  }) {
    var removedTotal = 0;
    for (final entry in _buckets.entries) {
      final initialLength = entry.value.length;
      entry.value.removeWhere(shouldRemove);
      final removed = initialLength - entry.value.length;
      if (removed > 0) {
        removedTotal += removed;
        _invalidate(entry.key);
        onBucketRemoved?.call(entry.key, removed);
      }
    }
    return removedTotal;
  }

  void _invalidate(String authorPubkey) {
    _sortedViews.remove(authorPubkey);
  }
}

int _newestFirstThenId(VideoEvent a, VideoEvent b) {
  final createdAt = b.createdAt.compareTo(a.createdAt);
  if (createdAt != 0) return createdAt;
  return b.id.compareTo(a.id);
}
