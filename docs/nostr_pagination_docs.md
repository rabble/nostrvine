Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Nostr Video Feed Pagination Documentation

## Overview
This document describes how pagination works in OpenVine's video feed, specifically for loading kind 32222 events (NIP-32222 addressable video events) from Nostr relays.

## The Problem
When users scroll to the bottom of the video feed, the app needs to load older videos from the relay. However, there was an issue where the app would request the same videos repeatedly instead of getting progressively older content.

## Root Cause
The pagination system uses an `until` parameter to request events older than a specific timestamp. When the pagination state was reset (after `hasMore` became false), the `oldestTimestamp` was cleared to null, but existing videos remained in memory. This caused subsequent requests to not include the `until` parameter, making the relay return the newest videos again.

## The Solution

### Key Components

#### 1. PaginationState Class
Located in `/lib/services/video_event_service.dart`

```dart
class PaginationState {
  int? oldestTimestamp;
  bool isLoading = false;
  bool hasMore = true;
  Set<String> seenEventIds = {};
  int eventsReceivedInCurrentQuery = 0;

  void updateOldestTimestamp(int timestamp) {
    if (oldestTimestamp == null || timestamp < oldestTimestamp!) {
      oldestTimestamp = timestamp;
    }
  }

  void reset() {
    oldestTimestamp = null;
    isLoading = false;
    hasMore = true;
    seenEventIds.clear();
    eventsReceivedInCurrentQuery = 0;
  }
}
```

#### 2. Loading More Events
The `loadMoreEvents` method in `VideoEventService` handles pagination:

```dart
Future<void> loadMoreEvents(SubscriptionType subscriptionType, {int limit = 50}) async {
  // ... initialization code ...

  int? until;
  final existingEvents = _eventLists[subscriptionType] ?? [];
  
  // CRITICAL FIX: Recalculate oldest timestamp from existing events
  // when pagination state has been reset but videos still exist
  if (existingEvents.isNotEmpty && paginationState.oldestTimestamp == null) {
    int? oldestFromEvents;
    for (final event in existingEvents) {
      if (oldestFromEvents == null || event.createdAt < oldestFromEvents) {
        oldestFromEvents = event.createdAt;
      }
    }
    if (oldestFromEvents != null) {
      paginationState.updateOldestTimestamp(oldestFromEvents);
    }
  }
  
  // Use the oldest timestamp for the 'until' parameter
  if (existingEvents.isNotEmpty && paginationState.oldestTimestamp != null) {
    until = paginationState.oldestTimestamp;
  }

  // Query historical events with the until parameter
  _queryHistoricalEvents(
    subscriptionType: subscriptionType,
    until: until,  // This ensures we get older videos
    limit: limit
  );
}
```

## How Pagination Works

### Initial Load
1. User opens the app or navigates to a video feed
2. `subscribeToVideoFeed` is called with initial limit (e.g., 10-50 videos)
3. First query has no `until` parameter - gets the most recent videos
4. As videos arrive, `updateOldestTimestamp` tracks the oldest one

### Scrolling for More
1. User scrolls to bottom of feed
2. `ExploreScreen` detects scroll position and calls `loadMoreEvents`
3. `loadMoreEvents` checks current `oldestTimestamp`
4. Creates a Filter with `until: oldestTimestamp` parameter
5. Relay returns videos older than or equal to that timestamp
6. New videos are added to the feed, oldest timestamp is updated

### After Pagination Reset
1. When `hasMore` becomes false (fewer events received than requested)
2. `resetPaginationState` may be called to retry
3. This clears `oldestTimestamp` to null
4. **Critical Fix**: On next `loadMoreEvents`, recalculate `oldestTimestamp` from existing videos
5. This ensures the `until` parameter is still set correctly

## Nostr Protocol Details

### Filter Structure
The app creates filters for the relay using the Nostr protocol:

```json
{
  "kinds": [32222],
  "until": 1754262575,  // Unix timestamp - get events before this time
  "limit": 50
}
```

### Relay Behavior
- Without `until`: Returns the most recent events
- With `until`: Returns events with `created_at <= until`, ordered newest to oldest
- The relay may include the event exactly at the `until` timestamp (boundary inclusive)

## Testing

### Unit Tests
Located in `/test/services/video_event_service_pagination_test.dart`

Key test: "should use oldest timestamp from existing events after pagination reset"
- Verifies that after reset, the `until` parameter uses the oldest timestamp from existing events
- Ensures no duplicate loading of the same videos

### Integration Testing with nak
Script: `/test_relay_with_nak.sh`

Tests against real relay `wss://relay3.openvine.co`:
1. Gets initial batch of videos
2. Uses `--until` parameter to get older videos
3. Verifies no duplicates (except boundary event)
4. Confirms pagination works across multiple batches

### Test Results
```bash
# First batch - recent videos
nak req -k 32222 -l 5 wss://relay3.openvine.co
# Returns: timestamps 1754266348, 1754266249, 1754266246, 1754262590, 1754262575

# Second batch - older videos using --until
nak req -k 32222 -l 5 --until 1754262575 wss://relay3.openvine.co
# Returns: timestamps 1754262575, 1754262459, 1754262016, 1754262013...
# Successfully returns older content!
```

## Common Issues and Solutions

### Issue: Same videos loading repeatedly
**Cause**: `until` parameter is null after pagination reset
**Solution**: Recalculate `oldestTimestamp` from existing events

### Issue: No more videos loading
**Cause**: `hasMore` is false and pagination stops
**Solution**: Reset pagination state but preserve oldest timestamp calculation

### Issue: Duplicate videos at boundaries
**Cause**: Relay includes event exactly at `until` timestamp
**Solution**: Use `seenEventIds` Set to filter duplicates

## Architecture Notes

### Embedded Relay Architecture
OpenVine uses an embedded relay that runs locally and proxies to external relays:
- App connects to `ws://localhost:7447` (embedded relay)
- Embedded relay connects to external relays like `wss://relay3.openvine.co`
- This provides caching, offline support, and P2P capabilities

### Event Flow
1. **User scrolls** → UI detects bottom
2. **UI calls** → `videoEventsNotifier.loadMoreEvents()`
3. **Service creates** → Filter with `until` parameter
4. **Embedded relay** → Forwards request to external relay
5. **External relay** → Returns older events
6. **Service processes** → Adds to feed, updates pagination state
7. **UI updates** → Shows new videos via Riverpod reactivity

## Debugging

### Useful Log Filters
```bash
# Watch pagination activity
flutter logs | grep -E "Loading more|until|Pagination|hasMore"

# Monitor relay responses
flutter logs | grep -E "EVENT|Received Kind 32222|Historical query"

# Check for duplicates
flutter logs | grep "already exists in database"
```

### Key Metrics
- `hasMore`: Whether more content is available
- `oldestTimestamp`: Oldest event timestamp in current feed
- `eventsReceivedInCurrentQuery`: How many events the last query returned
- `seenEventIds`: Set of all event IDs to prevent duplicates

## References
- [NIP-32222](https://github.com/nostr-protocol/nips/blob/master/32222.md) - Addressable video events
- [Nostr Protocol](https://github.com/nostr-protocol/nostr) - Event and filter specifications
- [nak tool](https://github.com/fiatjaf/nak) - Nostr Army Knife for testing