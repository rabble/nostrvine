// ABOUTME: Model for video feed items that can represent both direct videos and reposts
// ABOUTME: Wraps VideoEvent with optional repost metadata for NIP-18 support

import 'video_event.dart';
import 'package:nostr_sdk/event.dart';

/// Represents an item in the video feed which can be a direct video or a repost
class VideoFeedItem {
  /// The actual video event (either posted directly or reposted)
  final VideoEvent videoEvent;
  
  /// If this is a repost, the pubkey of the person who reposted it
  final String? repostedByPubkey;
  
  /// If this is a repost, the timestamp when it was reposted
  final DateTime? repostedAt;
  
  /// If this is a repost, the ID of the Kind 6 repost event
  final String? repostEventId;
  
  /// Whether this item is a repost
  bool get isRepost => repostedByPubkey != null;
  
  /// The timestamp to use for feed ordering (repost time if reposted, original time otherwise)
  DateTime get feedTimestamp => repostedAt ?? videoEvent.timestamp;
  
  const VideoFeedItem({
    required this.videoEvent,
    this.repostedByPubkey,
    this.repostedAt,
    this.repostEventId,
  });
  
  /// Create a direct video feed item (not a repost)
  factory VideoFeedItem.direct(VideoEvent videoEvent) {
    return VideoFeedItem(videoEvent: videoEvent);
  }
  
  /// Create a reposted video feed item
  factory VideoFeedItem.repost({
    required VideoEvent originalVideo,
    required String repostedByPubkey,
    required DateTime repostedAt,
    required String repostEventId,
  }) {
    return VideoFeedItem(
      videoEvent: originalVideo,
      repostedByPubkey: repostedByPubkey,
      repostedAt: repostedAt,
      repostEventId: repostEventId,
    );
  }
  
  /// Create from a Nostr event (handles both Kind 22 and Kind 6)
  static Future<VideoFeedItem?> fromNostrEvent(
    Event event,
    Future<Event?> Function(String eventId) fetchEvent,
  ) async {
    if (event.kind == 22) {
      // Direct video event
      try {
        final videoEvent = VideoEvent.fromNostrEvent(event);
        return VideoFeedItem.direct(videoEvent);
      } catch (e) {
        // Invalid video event
        return null;
      }
    } else if (event.kind == 6) {
      // Repost event - need to fetch the original video
      String? originalEventId;
      
      // Extract the original event ID from 'e' tags
      for (final tag in event.tags) {
        if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
          originalEventId = tag[1];
          break;
        }
      }
      
      if (originalEventId == null) {
        return null; // Invalid repost without event reference
      }
      
      // Fetch the original event
      final originalEvent = await fetchEvent(originalEventId);
      if (originalEvent == null || originalEvent.kind != 22) {
        return null; // Original event not found or not a video
      }
      
      try {
        final videoEvent = VideoEvent.fromNostrEvent(originalEvent);
        return VideoFeedItem.repost(
          originalVideo: videoEvent,
          repostedByPubkey: event.pubkey,
          repostedAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
          repostEventId: event.id,
        );
      } catch (e) {
        // Invalid video event
        return null;
      }
    }
    
    return null; // Unsupported event kind
  }
  
  @override
  String toString() {
    if (isRepost) {
      return 'VideoFeedItem(repost of ${videoEvent.id.substring(0, 8)}... by ${repostedByPubkey!.substring(0, 8)}...)';
    }
    return 'VideoFeedItem(direct ${videoEvent.id.substring(0, 8)}...)';
  }
}