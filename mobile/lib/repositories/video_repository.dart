// ABOUTME: Single source of truth for video storage with normalized IDs
// ABOUTME: Handles write-time deduplication and maintains indexes by subscription, hashtag, and author

import 'package:flutter/foundation.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Single source of truth for video storage with normalized IDs.
///
/// This repository implements write-time deduplication to prevent duplicate
/// videos from appearing in feeds. All video IDs are normalized to lowercase
/// on write, ensuring case-insensitive matching.
///
/// The repository maintains:
/// - A canonical map of video ID → VideoEvent (single copy per video)
/// - Subscription membership tracking (which feeds each video belongs to)
/// - Ordered lists per subscription type for feed rendering
/// - Hashtag and author indexes for efficient filtering
///
/// Pattern follows FollowRepository (same codebase).
class VideoRepository extends ChangeNotifier {
  VideoRepository();

  /// Canonical storage: normalized ID → VideoEvent
  /// Each video is stored exactly once, regardless of how many feeds it appears in.
  final Map<String, VideoEvent> _videos = {};

  /// Which subscription types each video belongs to.
  /// Key: normalized video ID, Value: set of subscription types.
  final Map<String, Set<SubscriptionType>> _subscriptionMembership = {};

  /// Ordered list of video IDs per subscription type.
  /// Maintains insertion order for feed rendering.
  final Map<SubscriptionType, List<String>> _subscriptionOrder = {
    for (final type in SubscriptionType.values) type: [],
  };

  /// Hashtag index: normalized hashtag → set of video IDs.
  /// Enables efficient hashtag-based video lookup.
  final Map<String, Set<String>> _hashtagIndex = {};

  /// Author index: normalized pubkey → set of video IDs.
  /// Enables efficient author-based video lookup.
  final Map<String, Set<String>> _authorIndex = {};

  /// Track locally deleted videos to prevent resurrection from pagination.
  final Set<String> _locallyDeletedVideoIds = {};

  // ============================================================================
  // PUBLIC API - Read Operations
  // ============================================================================

  /// Get video by ID (case-insensitive).
  VideoEvent? getVideoById(String id) => _videos[_normalizeId(id)];

  /// Check if video exists (case-insensitive).
  bool containsVideo(String id) => _videos.containsKey(_normalizeId(id));

  /// Check if a video is locally deleted.
  bool isVideoLocallyDeleted(String id) =>
      _locallyDeletedVideoIds.contains(_normalizeId(id));

  /// Get videos for subscription type (ordered).
  List<VideoEvent> getVideosForSubscription(SubscriptionType type) {
    return _subscriptionOrder[type]!
        .map((id) => _videos[id])
        .whereType<VideoEvent>()
        .toList();
  }

  /// Get videos by hashtag (case-insensitive).
  List<VideoEvent> getVideosByHashtag(String hashtag) {
    final normalizedTag = hashtag.toLowerCase();
    final ids = _hashtagIndex[normalizedTag] ?? {};
    return ids.map((id) => _videos[id]).whereType<VideoEvent>().toList();
  }

  /// Get videos by multiple hashtags (case-insensitive, deduplicated).
  List<VideoEvent> getVideosByHashtags(List<String> hashtags) {
    final result = <VideoEvent>[];
    final seenIds = <String>{};

    for (final tag in hashtags) {
      final normalizedTag = tag.toLowerCase();
      final ids = _hashtagIndex[normalizedTag] ?? {};

      for (final id in ids) {
        if (!seenIds.contains(id)) {
          seenIds.add(id);
          final video = _videos[id];
          if (video != null) {
            result.add(video);
          }
        }
      }
    }

    return result;
  }

  /// Get videos by author (case-insensitive).
  List<VideoEvent> getVideosByAuthor(String pubkey) {
    final normalizedPubkey = _normalizeId(pubkey);
    final ids = _authorIndex[normalizedPubkey] ?? {};
    return ids.map((id) => _videos[id]).whereType<VideoEvent>().toList();
  }

  /// Get count for subscription type.
  int getVideoCount(SubscriptionType type) =>
      _subscriptionOrder[type]?.length ?? 0;

  /// Get total video count across all subscriptions.
  int get totalVideoCount => _videos.length;

  /// Get all subscription types a video belongs to.
  Set<SubscriptionType> getSubscriptionMembership(String id) =>
      _subscriptionMembership[_normalizeId(id)] ?? {};

  // ============================================================================
  // PUBLIC API - Write Operations
  // ============================================================================

  /// Add video with write-time deduplication.
  ///
  /// Returns true if this is a new video, false if it already existed.
  ///
  /// [videoEvent] - The video to add
  /// [subscriptionType] - Which feed this video belongs to
  /// [isHistorical] - If true, add to bottom of list; if false, add to top
  bool addVideo(
    VideoEvent videoEvent, {
    required SubscriptionType subscriptionType,
    bool isHistorical = false,
  }) {
    final normalizedId = _normalizeId(videoEvent.id);

    // Don't add locally deleted videos
    if (_locallyDeletedVideoIds.contains(normalizedId)) {
      Log.debug(
        'VideoRepository: Skipping locally deleted video $normalizedId',
        name: 'VideoRepository',
        category: LogCategory.video,
      );
      return false;
    }

    final isNew = !_videos.containsKey(normalizedId);

    // Store/update video (single canonical copy)
    _videos[normalizedId] = videoEvent;

    // Track subscription membership
    _subscriptionMembership
        .putIfAbsent(normalizedId, () => <SubscriptionType>{})
        .add(subscriptionType);

    // Maintain ordering (only if not already present in this subscription)
    final order = _subscriptionOrder[subscriptionType]!;
    if (!order.contains(normalizedId)) {
      if (isHistorical) {
        order.add(normalizedId); // Bottom for historical
      } else {
        order.insert(0, normalizedId); // Top for real-time
      }
    }

    // Index by hashtags
    for (final tag in videoEvent.hashtags) {
      final normalizedTag = tag.toLowerCase();
      _hashtagIndex
          .putIfAbsent(normalizedTag, () => <String>{})
          .add(normalizedId);
    }

    // Index by author
    final normalizedPubkey = _normalizeId(videoEvent.pubkey);
    _authorIndex
        .putIfAbsent(normalizedPubkey, () => <String>{})
        .add(normalizedId);

    // Also index by reposter if this is a repost
    if (videoEvent.isRepost && videoEvent.reposterPubkey != null) {
      final normalizedReposterPubkey = _normalizeId(videoEvent.reposterPubkey!);
      _authorIndex
          .putIfAbsent(normalizedReposterPubkey, () => <String>{})
          .add(normalizedId);
    }

    if (isNew) {
      Log.debug(
        'VideoRepository: Added new video $normalizedId to $subscriptionType '
        '(total: ${_videos.length})',
        name: 'VideoRepository',
        category: LogCategory.video,
      );
    }

    return isNew;
  }

  /// Update an existing video's data.
  ///
  /// Returns true if the video was found and updated.
  bool updateVideo(VideoEvent videoEvent) {
    final normalizedId = _normalizeId(videoEvent.id);

    if (!_videos.containsKey(normalizedId)) {
      return false;
    }

    _videos[normalizedId] = videoEvent;

    // Re-index hashtags (remove old, add new)
    // First remove from all hashtag indexes
    for (final entry in _hashtagIndex.entries) {
      entry.value.remove(normalizedId);
    }
    // Then add to current hashtags
    for (final tag in videoEvent.hashtags) {
      final normalizedTag = tag.toLowerCase();
      _hashtagIndex
          .putIfAbsent(normalizedTag, () => <String>{})
          .add(normalizedId);
    }

    notifyListeners();
    return true;
  }

  /// Mark a video as locally deleted.
  ///
  /// This prevents the video from being resurrected via pagination.
  void markVideoAsDeleted(String id) {
    final normalizedId = _normalizeId(id);
    _locallyDeletedVideoIds.add(normalizedId);
    removeVideo(id);
  }

  /// Remove a video from all collections.
  void removeVideo(String id) {
    final normalizedId = _normalizeId(id);
    final video = _videos.remove(normalizedId);

    if (video == null) return;

    // Remove from subscription membership and ordering
    _subscriptionMembership.remove(normalizedId);
    for (final order in _subscriptionOrder.values) {
      order.remove(normalizedId);
    }

    // Remove from hashtag index
    for (final tag in video.hashtags) {
      final normalizedTag = tag.toLowerCase();
      _hashtagIndex[normalizedTag]?.remove(normalizedId);
    }

    // Remove from author index
    final normalizedPubkey = _normalizeId(video.pubkey);
    _authorIndex[normalizedPubkey]?.remove(normalizedId);

    if (video.isRepost && video.reposterPubkey != null) {
      final normalizedReposterPubkey = _normalizeId(video.reposterPubkey!);
      _authorIndex[normalizedReposterPubkey]?.remove(normalizedId);
    }

    notifyListeners();
  }

  /// Clear all videos for a specific subscription type.
  void clearSubscription(SubscriptionType type) {
    final idsToCheck = List<String>.from(_subscriptionOrder[type] ?? []);
    _subscriptionOrder[type]?.clear();

    // Remove subscription type from membership
    // If video no longer belongs to any subscription, remove it entirely
    for (final id in idsToCheck) {
      final membership = _subscriptionMembership[id];
      if (membership != null) {
        membership.remove(type);
        if (membership.isEmpty) {
          // Video no longer belongs to any subscription, clean up
          _cleanupOrphanedVideo(id);
        }
      }
    }

    notifyListeners();
  }

  /// Clear all data.
  void clearAll() {
    _videos.clear();
    _subscriptionMembership.clear();
    for (final order in _subscriptionOrder.values) {
      order.clear();
    }
    _hashtagIndex.clear();
    _authorIndex.clear();
    // Note: Don't clear _locallyDeletedVideoIds - those persist
    notifyListeners();
  }

  /// Sort videos in a subscription by the given comparator.
  void sortSubscription(
    SubscriptionType type,
    int Function(VideoEvent a, VideoEvent b) compare,
  ) {
    final order = _subscriptionOrder[type];
    if (order == null || order.isEmpty) return;

    order.sort((idA, idB) {
      final videoA = _videos[idA];
      final videoB = _videos[idB];
      if (videoA == null || videoB == null) return 0;
      return compare(videoA, videoB);
    });
  }

  // ============================================================================
  // Private Helpers
  // ============================================================================

  /// Normalize ID to lowercase (call once at write time).
  String _normalizeId(String id) => id.toLowerCase();

  /// Clean up a video that no longer belongs to any subscription.
  void _cleanupOrphanedVideo(String normalizedId) {
    final video = _videos.remove(normalizedId);
    if (video == null) return;

    _subscriptionMembership.remove(normalizedId);

    // Remove from hashtag index
    for (final tag in video.hashtags) {
      final normalizedTag = tag.toLowerCase();
      _hashtagIndex[normalizedTag]?.remove(normalizedId);
    }

    // Remove from author index
    final normalizedPubkey = _normalizeId(video.pubkey);
    _authorIndex[normalizedPubkey]?.remove(normalizedId);

    if (video.isRepost && video.reposterPubkey != null) {
      final normalizedReposterPubkey = _normalizeId(video.reposterPubkey!);
      _authorIndex[normalizedReposterPubkey]?.remove(normalizedId);
    }
  }

  @override
  void dispose() {
    // Clear all data
    _videos.clear();
    _subscriptionMembership.clear();
    for (final order in _subscriptionOrder.values) {
      order.clear();
    }
    _hashtagIndex.clear();
    _authorIndex.clear();
    _locallyDeletedVideoIds.clear();
    super.dispose();
  }
}
