# Fix for Video Publishing in OpenVine

## Problem Identified

The app is publishing videos using **NIP-94 (Kind 1063)** events but the video feed is looking for **NIP-71 (Kind 22)** events. This mismatch is why videos aren't appearing in the feed.

### Current Flow:
1. Video uploaded to Cloudflare Stream ✅
2. Published as Kind 1063 (NIP-94 file metadata) ❌
3. Feed looking for Kind 22 (NIP-71 short videos) ❌
4. No videos appear in feed

### Required Fix:

Update the publishing flow to create Kind 22 events instead of (or in addition to) Kind 1063 events.

## Implementation Plan

### Step 1: Add publishVideoEvent to NostrService

Add this method to `/lib/services/nostr_service.dart`:

```dart
/// Publish a NIP-71 short video event (kind 22)
Future<NostrBroadcastResult> publishVideoEvent({
  required String videoUrl,
  required String content,
  String? title,
  String? thumbnailUrl,
  int? duration,
  String? dimensions,
  String? mimeType,
  String? sha256,
  int? fileSize,
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
    if (mimeType != null) tags.add(['m', mimeType]);
    if (sha256 != null) tags.add(['x', sha256]);
    if (fileSize != null) tags.add(['size', fileSize.toString()]);
    
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
    
    debugPrint('🎬 Created Kind 22 video event: ${event.id}');
    debugPrint('📹 Video URL: $videoUrl');
    
    // Broadcast to relays
    return await broadcastEvent(event);
    
  } catch (e) {
    debugPrint('❌ Failed to publish video event: $e');
    rethrow;
  }
}
```

### Step 2: Update VinePublishingService

In `/lib/services/vine_publishing_service.dart`, update the Stream publishing method (around line 440):

```dart
// Replace this section:
_updateState(PublishingState.broadcastingToNostr, 0.8, 'Creating Nostr event...');

// Step 3: Create NIP-94 metadata for video
final metadata = NIP94Metadata.fromStreamVideo(
  videoId: uploadResult.videoId!,
  hlsUrl: videoStatus.hlsUrl!,
  dashUrl: videoStatus.dashUrl,
  thumbnailUrl: videoStatus.thumbnailUrl,
  summary: caption,
  altText: altText,
);

_updateState(PublishingState.broadcastingToNostr, 0.9, 'Broadcasting to Nostr...');

// Step 4: Broadcast to Nostr network
final broadcastResult = await _nostrService.publishFileMetadata(
  metadata: metadata,
  content: caption,
  hashtags: hashtags,
);

// WITH THIS:
_updateState(PublishingState.broadcastingToNostr, 0.8, 'Creating video event...');

// Step 3: Publish as Kind 22 (NIP-71) video event
final broadcastResult = await _nostrService.publishVideoEvent(
  videoUrl: videoStatus.hlsUrl!,
  content: caption,
  title: caption,
  thumbnailUrl: videoStatus.thumbnailUrl,
  duration: videoStatus.duration, // Get from metadata if available
  dimensions: videoStatus.dimensions, // Get from metadata if available
  mimeType: 'video/mp4', // Stream always provides MP4
  hashtags: hashtags,
);

_updateState(PublishingState.broadcastingToNostr, 0.9, 'Video event published!');
```

### Step 3: Update VideoEventPublisher

In `/lib/services/video_event_publisher.dart`, change the event creation (around line 200):

```dart
// Replace:
final event = await _authService!.createAndSignEvent(
  kind: 1063, // NIP-94 file metadata
  content: eventData.contentSuggestion,
  tags: eventData.nip94Tags,
);

// With:
// Extract video metadata from eventData
String? videoUrl;
String? thumbnailUrl;
String? title;
int? duration;
String? dimensions;

// Parse the NIP-94 tags to extract video info
for (final tag in eventData.nip94Tags) {
  if (tag.isEmpty) continue;
  switch (tag[0]) {
    case 'url':
      videoUrl = tag.length > 1 ? tag[1] : null;
      break;
    case 'thumb':
      thumbnailUrl = tag.length > 1 ? tag[1] : null;
      break;
    case 'title':
      title = tag.length > 1 ? tag[1] : null;
      break;
    case 'duration':
      duration = tag.length > 1 ? int.tryParse(tag[1]) : null;
      break;
    case 'dim':
      dimensions = tag.length > 1 ? tag[1] : null;
      break;
  }
}

// Create Kind 22 tags
final videoTags = <List<String>>[];
if (videoUrl != null) videoTags.add(['url', videoUrl]);
if (title != null) videoTags.add(['title', title]);
if (thumbnailUrl != null) videoTags.add(['thumb', thumbnailUrl]);
if (duration != null) videoTags.add(['duration', duration.toString()]);
if (dimensions != null) videoTags.add(['dim', dimensions]);

// Add hashtags from original tags
for (final tag in eventData.nip94Tags) {
  if (tag.isNotEmpty && tag[0] == 't') {
    videoTags.add(tag);
  }
}

final event = await _authService!.createAndSignEvent(
  kind: 22, // NIP-71 short video
  content: eventData.contentSuggestion,
  tags: videoTags,
);

debugPrint('📹 Created Kind 22 video event for publishing');
```

### Step 4: Optional - Dual Publishing

For maximum compatibility, publish both Kind 22 and Kind 1063:

```dart
// In VinePublishingService, after successful Stream upload:

// Publish as Kind 22 for video feeds
final videoResult = await _nostrService.publishVideoEvent(
  videoUrl: videoStatus.hlsUrl!,
  content: caption,
  title: caption,
  thumbnailUrl: videoStatus.thumbnailUrl,
  hashtags: hashtags,
);

// Also create and publish NIP-94 metadata for compatibility
if (videoResult.isSuccessful) {
  final metadata = NIP94Metadata.fromStreamVideo(
    videoId: uploadResult.videoId!,
    hlsUrl: videoStatus.hlsUrl!,
    dashUrl: videoStatus.dashUrl,
    thumbnailUrl: videoStatus.thumbnailUrl,
    summary: caption,
    altText: altText,
  );
  
  await _nostrService.publishFileMetadata(
    metadata: metadata,
    content: caption,
    hashtags: hashtags,
  );
}
```

## Testing Steps

1. **Run the app**:
   ```bash
   flutter run -d macos
   ```

2. **Record and publish a video**:
   - Open camera screen
   - Record a short video
   - Add caption and publish

3. **Check logs for Kind 22**:
   - Look for: "Created Kind 22 video event"
   - Verify: "Broadcasting event to relays"

4. **Verify in feed**:
   - Go to feed screen
   - Pull to refresh
   - Video should appear immediately

5. **Check relay data**:
   ```bash
   # Use a Nostr client to query for Kind 22 events
   # Or check relay logs for stored events
   ```

## Debugging Tips

1. **If videos still don't appear**:
   - Check if relays accept Kind 22 events
   - Verify event is being broadcast successfully
   - Check VideoEventService subscription filter

2. **Enable verbose logging**:
   ```dart
   // In video_event_service.dart
   debugPrint('🔍 Filter details: ${filter.toJson()}');
   ```

3. **Test with a known working relay**:
   - Try relay.damus.io first
   - Some relays may not support Kind 22

## Future Improvements

1. **Add configuration option**:
   ```dart
   // In app_config.dart
   static const bool publishKind22 = true;
   static const bool publishKind1063 = true;
   ```

2. **Migrate existing content**:
   - Create a migration tool to republish Kind 1063 as Kind 22

3. **Add fallback support**:
   - If Kind 22 fails, try Kind 1063
   - Support reading both event types in feed