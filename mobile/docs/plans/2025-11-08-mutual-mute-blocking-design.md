Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Mutual Mute Blocking Design

**Date**: 2025-11-08
**Author**: Claude (via brainstorming session with Rabble)
**Status**: Approved

## Overview

Implement mutual content filtering based on Nostr mute lists (NIP-51 kind 10000). When another user mutes our user by adding our pubkey to their kind 10000 mute list, we reciprocally hide that user's content from our feeds.

**Rationale**: Don't waste our user's time showing content from people who explicitly don't want to interact with them.

## Goals

1. **Background sync** of kind 10000 events that tag our user's pubkey
2. **Automatic filtering** of mutual muters across all feeds (home, discovery, hashtag, search, comments)
3. **Blocked user UI** when directly navigating to profile/video of someone who muted us
4. **Persistent storage** via embedded relay's SQLite between sessions
5. **Non-blocking startup** - low priority background process

## Architecture Decision

**Chosen Approach**: Extend `ContentBlocklistService` with background sync capability.

**Why**:
- Reuses existing filtering infrastructure (VideoEventService already calls `shouldFilterFromFeeds()`)
- Single source of truth for "who to block"
- Minimal new code - follows existing pattern from BookmarkService
- Acceptable mixed responsibility since blocking is inherently tied to Nostr events

**Rejected Alternatives**:
- Separate `MuteListSyncService` - adds unnecessary service layer complexity
- BackgroundActivityManager handles sync inline - puts domain logic in wrong place

## Data Model

### Kind 10000 Event Structure (NIP-51)

```json
{
  "kind": 10000,
  "tags": [
    ["p", "<pubkey-being-muted>", "<optional-relay-hint>"],
    ["p", "<another-pubkey>"]
  ],
  "content": ""
}
```

**What we're looking for**: Kind 10000 events WHERE our user's pubkey appears in a "p" tag.
**What we extract**: The event's `.pubkey` field (the person who created the mute list = who muted us).

### ContentBlocklistService State Changes

```dart
class ContentBlocklistService {
  // EXISTING
  static const Set<String> _internalBlocklist = {...};
  final Set<String> _runtimeBlocklist = <String>{};

  // NEW: Third blocklist for mutual mutes
  final Set<String> _mutualMuteBlocklist = <String>{};

  // NEW: Subscription tracking
  String? _mutualMuteSubscriptionId;
  bool _mutualMuteSyncStarted = false;

  // NEW: Cached our pubkey for event validation
  String? _ourPubkey;
}
```

## Component Responsibilities

### ContentBlocklistService (Extended)

**New Responsibilities**:
1. Subscribe to kind 10000 events via NostrService
2. Parse incoming events to extract muter pubkeys
3. Maintain `_mutualMuteBlocklist` set
4. Handle replaceable event updates (unmuting)

**New Methods**:

```dart
/// Start background sync of mutual mute lists
Future<void> syncMuteListsInBackground(INostrService nostrService, String ourPubkey) async

/// Handle incoming kind 10000 events
void _handleMuteListEvent(Event event)

/// Dispose subscription on service disposal
void dispose()
```

**Modified Methods**:

```dart
/// MODIFIED: Check all three blocklists
@override
bool shouldFilterFromFeeds(String pubkey) {
  return _internalBlocklist.contains(pubkey) ||
         _runtimeBlocklist.contains(pubkey) ||
         _mutualMuteBlocklist.contains(pubkey);
}
```

### BackgroundActivityManager (Integration Point)

**Change**: Call `contentBlocklistService.syncMuteListsInBackground()` during app startup, after AuthService is ready but before feeds load.

### Profile/Video Screens (UI Integration)

**Change**: Before rendering content, check `contentBlocklistService.shouldFilterFromFeeds(authorPubkey)`. If true, display blocked user message instead of content.

## Flow Diagrams

### Background Sync Flow

```
App Startup
  ↓
BackgroundActivityManager.initialize()
  ↓
contentBlocklistService.syncMuteListsInBackground(nostrService, ourPubkey)
  ↓
Subscribe: kind=10000, #p=<our-pubkey>
  ↓
Embedded relay searches SQLite + subscribes to external relays
  ↓
For each kind 10000 event received:
  - Check if our pubkey is in 'p' tags
  - If YES: add event.pubkey to _mutualMuteBlocklist
  - If NO: remove event.pubkey from _mutualMuteBlocklist (unmuted)
  ↓
shouldFilterFromFeeds() checks all 3 blocklists
  ↓
Existing VideoEventService filtering automatically applies
```

### Content Filtering Flow

```
VideoEventService receives event
  ↓
Check: blocklistService.shouldFilterFromFeeds(event.pubkey)
  ↓
  YES → Drop event (don't add to feed)
  NO → Process normally
```

### Direct Navigation Flow

```
User taps profile/video link
  ↓
ProfileScreen/VideoDetailScreen builds
  ↓
Check: blocklistService.shouldFilterFromFeeds(profilePubkey)
  ↓
  YES → Show "This account is not available"
  NO → Show normal content
```

## Error Handling & Edge Cases

### Subscription Failure
- **Scenario**: NostrService unavailable during sync
- **Handling**: Log warning, continue app startup
- **Rationale**: Non-critical feature, don't block user experience

### Duplicate Events
- **Scenario**: Same kind 10000 event arrives multiple times
- **Handling**: `Set<String>` naturally deduplicates
- **No action needed**: Add operation is idempotent

### User Unmutes Us
- **Scenario**: Someone removes our pubkey from their kind 10000 list
- **Handling**: Replaceable events mean we receive FULL updated list
- **Logic**: Parse entire 'p' tag list, if our pubkey missing → remove muter from blocklist

### Memory Bounds
- **Data Structure**: Unbounded `Set<String>`
- **Realistic Scale**: 10,000 muters = ~640KB (64 bytes/pubkey)
- **Decision**: No artificial limits - acceptable for mobile

### Startup Performance
- **Constraint**: Must not block critical app initialization
- **Solution**: Called AFTER AuthService ready, BEFORE feed loads
- **Subscription**: Fire-and-forget - doesn't wait for EOSE

## Testing Strategy

### Unit Tests (TDD)

1. **syncMuteListsInBackground()**
   - Test: Subscribes with correct filter (kind=10000, #p=ourPubkey)
   - Test: Only calls subscribe once (guards with _mutualMuteSyncStarted)
   - Test: Handles NostrService errors gracefully

2. **_handleMuteListEvent()**
   - Test: Adds muter pubkey when our pubkey in 'p' tags
   - Test: Removes muter pubkey when our pubkey NOT in 'p' tags (unmute)
   - Test: Handles malformed events (missing tags, invalid structure)
   - Test: Idempotent - adding same muter multiple times = one entry

3. **shouldFilterFromFeeds()**
   - Test: Returns true for mutual mute blocklist entries
   - Test: Still checks internal + runtime blocklists
   - Test: Returns false for non-blocked pubkeys

### Integration Tests

1. **End-to-end mute flow**
   - Publish kind 10000 with our pubkey
   - Verify ContentBlocklistService receives event
   - Verify muter added to blocklist
   - Verify VideoEventService filters content

2. **Unmute flow**
   - Publish kind 10000 WITHOUT our pubkey
   - Verify muter removed from blocklist
   - Verify content appears in feeds again

3. **UI integration**
   - Navigate to muter's profile
   - Verify "This account is not available" message
   - Navigate to muter's video
   - Verify blocked message

## Implementation Checklist

**Phase 1: Core Service Extension**
- [ ] Add `_mutualMuteBlocklist`, `_mutualMuteSubscriptionId`, `_mutualMuteSyncStarted` fields
- [ ] Implement `syncMuteListsInBackground()` method
- [ ] Implement `_handleMuteListEvent()` method
- [ ] Modify `shouldFilterFromFeeds()` to check mutual mute list
- [ ] Add `dispose()` method to clean up subscription

**Phase 2: Startup Integration**
- [ ] Integrate sync call into BackgroundActivityManager or app startup
- [ ] Ensure called after AuthService ready
- [ ] Add error handling for missing services

**Phase 3: UI Blocked Message**
- [ ] Add blocked user check to ProfileScreen
- [ ] Add blocked user check to VideoDetailScreen
- [ ] Create `_buildBlockedUserMessage()` widget
- [ ] Match Instagram/TikTok copy: "This account is not available"

**Phase 4: Testing**
- [ ] Write unit tests (TDD - before implementation)
- [ ] Write integration tests
- [ ] Manual testing: publish kind 10000, verify filtering
- [ ] Manual testing: remove from kind 10000, verify unfiltering

**Phase 5: Documentation & Cleanup**
- [ ] Update ContentBlocklistService docstrings
- [ ] Add code comments explaining NIP-51 kind 10000 structure
- [ ] Run `flutter analyze` - fix any issues
- [ ] Run tests - verify all pass

## UI Copy

**Blocked User Message** (when navigating to profile/video of mutual muter):

```
This account is not available
```

**Style**: Grey text on dark background (VineTheme.backgroundColor), centered.

## Success Metrics

1. **Zero startup delay** - background sync doesn't block app launch
2. **Automatic filtering** - mutual muters filtered without user intervention
3. **Clean blocked UI** - professional message when accessing blocked content
4. **Persistent across sessions** - blocklist survives app restart
5. **Test coverage ≥80%** - all core paths tested

## Future Enhancements (Out of Scope)

- User-visible mute list stats ("X people have muted you")
- Expose mutual mute list in settings
- Manual override to view muted content
- NIP-51 list syncing (kinds 30000-30004) for bookmarks/pins
