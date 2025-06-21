# Fix for Video Publishing in NostrVine

## Problem Identified

The app is publishing videos using **NIP-94 (Kind 1063)** events but the video feed is looking for **NIP-71 (Kind 22)** events. This mismatch is why videos aren't appearing in the feed.

### Current Flow:
1. Video uploaded to Cloudflare Stream ✅
2. Published as Kind 1063 (NIP-94 file metadata) ❌
3. Feed looking for Kind 22 (NIP-71 short videos) ❌
4. No videos appear in feed

### Required Fix:

Update the publishing flow to create Kind 22 events instead of (or in addition to) Kind 1063 events.

## Quick Fix

Add this method to `NostrService`:

```dart
/// Publish a NIP-71 short video event (kind 22)
Future<NostrBroadcastResult> publishVideoEvent({
  required String videoUrl,
  required String content,
  String? title,
  String? thumbnailUrl,
  int? duration,
  String? dimensions,
  List<String> hashtags = const [],
}) async {
  if (!isInitialized || !hasKeys) {
    throw NostrServiceException('NostrService not initialized or no keys available');
  }

  try {
    // Build tags for NIP-71 video event
    final tags = <List<String>>[];
    
    // Required: video URL
    tags.add(['url', videoUrl]);
    
    // Optional metadata
    if (title != null) tags.add(['title', title]);
    if (thumbnailUrl != null) tags.add(['thumb', thumbnailUrl]);
    if (duration != null) tags.add(['duration', duration.toString()]);
    if (dimensions != null) tags.add(['dim', dimensions]);
    
    // Add hashtags
    for (final tag in hashtags) {
      tags.add(['t', tag.toLowerCase()]);
    }
    
    // Add client tag
    tags.add(['client', 'nostrvine']);
    
    // Create and sign the event
    final event = await createAndSignEvent(
      kind: 22, // NIP-71 short video
      content: content,
      tags: tags,
    );
    
    if (event == null) {
      throw NostrServiceException('Failed to create video event');
    }
    
    // Broadcast to relays
    return await broadcastEvent(event);
    
  } catch (e) {
    debugPrint('❌ Failed to publish video event: $e');
    rethrow;
  }
}
```

## Update VinePublishingService

Replace the NIP-94 publishing with NIP-71:

```dart
// OLD CODE (around line 443):
final broadcastResult = await _nostrService.publishFileMetadata(
  metadata: metadata,
  content: caption,
  hashtags: hashtags,
);

// NEW CODE:
final broadcastResult = await _nostrService.publishVideoEvent(
  videoUrl: videoStatus.hlsUrl!,
  content: caption,
  title: caption,
  thumbnailUrl: videoStatus.thumbnailUrl,
  duration: null, // TODO: Get from video metadata
  dimensions: null, // TODO: Get from video metadata
  hashtags: hashtags,
);
```

## Alternative: Support Both Events

For maximum compatibility, publish both Kind 22 and Kind 1063:

```dart
// Publish as NIP-71 (Kind 22) for video feeds
final videoResult = await _nostrService.publishVideoEvent(
  videoUrl: videoStatus.hlsUrl!,
  content: caption,
  title: caption,
  thumbnailUrl: videoStatus.thumbnailUrl,
  hashtags: hashtags,
);

// Also publish as NIP-94 (Kind 1063) for file storage
final fileResult = await _nostrService.publishFileMetadata(
  metadata: metadata,
  content: caption,
  hashtags: hashtags,
);
```

## Testing

After implementing the fix:

1. Record and publish a new video
2. Check logs for "kind: 22" events being published
3. Video should appear in feed immediately
4. Verify in relay that Kind 22 events are being stored

## Long-term Considerations

1. **Event Type Configuration**: Add a setting to choose between NIP-71, NIP-94, or both
2. **Migration**: Consider migrating existing Kind 1063 events to Kind 22
3. **Relay Support**: Ensure all relays support Kind 22 events
4. **Client Compatibility**: Some Nostr clients may expect one format or the other