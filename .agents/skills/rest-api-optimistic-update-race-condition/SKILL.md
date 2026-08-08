---
name: rest-api-optimistic-update-race-condition
description: |
  Fix "content disappears after publishing" bugs caused by REST API indexing lag.
  Use when: (1) User publishes content but it doesn't appear in their feed/profile,
  (2) REST API returns stale data immediately after write operations, (3) Async
  indexing backends (ClickHouse, Elasticsearch, etc.) haven't processed new events,
  (4) Content shows briefly then vanishes on refresh. Applies to any system with
  separate write path (WebSocket/direct DB) and read path (REST API with async indexing).
author: Claude Code
version: 1.0.0
date: 2026-02-01
---

# REST API Optimistic Update Race Condition

## Problem

When an application uses a dual architecture with:
- **Write path**: Direct database writes or WebSocket/event publishing
- **Read path**: REST API backed by async indexing (ClickHouse, Elasticsearch, etc.)

Content can "disappear" after publishing because the read path hasn't indexed
the new content yet, but the UI re-fetches from the REST API expecting fresh data.

## Context / Trigger Conditions

- User publishes content (video, post, comment, etc.)
- Content briefly appears, then disappears on refresh or navigation
- REST API returns N items when N+1 expected
- Logs show successful write but stale read
- Backend uses async indexing (ClickHouse, Elasticsearch, Algolia, etc.)
- Symptoms worsen under load or with slow indexing pipelines

**Log pattern example:**
```
✅ Event successfully published to relays
📊 Fetching from REST API: found 59 videos  // Expected 60!
```

## Solution

### Option 1: Optimistic State Update (Recommended)

Instead of re-fetching from REST API after publishing, optimistically add the
new content directly to the local state:

```dart
// BEFORE (broken): Re-fetch from potentially stale API
void onNewContentPublished(Content newContent) {
  refreshFromRestApi(); // API hasn't indexed yet = stale data
}

// AFTER (fixed): Optimistic local update
void onNewContentPublished(Content newContent) {
  final currentItems = state.items;

  // Skip if duplicate
  if (currentItems.any((item) => item.id == newContent.id)) return;

  // Add to front of list (most recent first)
  final updatedItems = [newContent, ...currentItems];

  state = state.copyWith(
    items: updatedItems,
    lastUpdated: DateTime.now(),
  );
}
```

### Option 2: Hybrid Approach

For long-lived sessions, periodically reconcile local state with REST API:

```dart
void onNewContentPublished(Content newContent) {
  // Immediate: optimistic update
  _addToLocalState(newContent);

  // Delayed: reconcile with API after indexing lag
  Future.delayed(Duration(seconds: 30), () {
    _reconcileWithRestApi();
  });
}
```

### Option 3: Write-Through Cache

If your REST API supports it, use write-through caching:

```dart
// POST to API returns the created item, cache it immediately
final response = await api.createContent(content);
_cache.put(response.id, response);
```

## Verification

After implementing the fix:

1. Publish new content
2. Immediately navigate to the listing (profile, feed, etc.)
3. Verify new content appears at the top
4. Refresh page after 30+ seconds - content should still be there
5. Check that duplicate prevention works (publish same content twice)

## Example

**Real-world case**: OpenVine video upload

```dart
// ProfileFeedProvider - fixed version
final unregisterNew = videoEventService.addNewVideoListener((
  newVideo,
  authorPubkey,
) {
  if (authorPubkey == userId && ref.mounted) {
    // CRITICAL FIX: Optimistically add the new video to state immediately
    // instead of re-fetching from REST API which may have stale data.
    _addNewVideoToState(newVideo);
  }
});

void _addNewVideoToState(VideoEvent newVideo) {
  final currentState = state.asData?.value;
  if (currentState == null) return;

  // Check for duplicates
  if (currentState.videos.any((v) => v.id == newVideo.id)) return;

  // Add new video to the front of the list
  final updatedVideos = <VideoEvent>[newVideo, ...currentState.videos];

  state = AsyncData(VideoFeedState(
    videos: updatedVideos,
    hasMoreContent: currentState.hasMoreContent,
    isLoadingMore: false,
    lastUpdated: DateTime.now(),
  ));
}
```

## Notes

- This pattern applies to any system with async indexing, not just Nostr/ClickHouse
- Consider adding a "pending" or "uploading" visual state for published content
- The optimistic update should include all metadata the UI needs to render
- For content that requires server-side processing (thumbnails, transcoding),
  consider showing a placeholder until processing completes
- If the write actually failed, the next REST API fetch will correct the state

## Related Patterns

- **Optimistic UI**: Show changes before server confirmation
- **CQRS**: Command Query Responsibility Segregation (separate read/write models)
- **Event Sourcing**: Events as source of truth with materialized views for reads
- **Cache Invalidation**: The "two hard problems" - this is one of them

## References

- [Optimistic UI Patterns](https://www.apollographql.com/docs/react/performance/optimistic-ui/)
- [CQRS Pattern](https://martinfowler.com/bliki/CQRS.html)
