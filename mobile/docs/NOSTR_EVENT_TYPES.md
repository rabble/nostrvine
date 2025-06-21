# NostrVine Event Types Documentation

This document outlines the required Nostr event types (kinds) that NostrVine uses for proper functionality.

## Core Event Types

### Kind 0 - User Profiles (NIP-01)
**Required for:** User profile display, authentication, social features

**Purpose:** User metadata including display names, avatars, and bio information

**Implementation:**
- `UserProfileService` subscribes to Kind 0 events
- Cached locally for UI display
- Used throughout the app for showing user information

**Example Structure:**
```json
{
  "kind": 0,
  "content": "{\"name\":\"Alice\",\"about\":\"Video creator\",\"picture\":\"https://example.com/avatar.jpg\"}",
  "tags": [],
  "pubkey": "user_public_key",
  "created_at": 1672531200
}
```

**Required Fields in Content JSON:**
- `name` - Display name (shown in video feed)
- `about` - User bio/description
- `picture` - Avatar image URL

### Kind 6 - Reposts (NIP-18) 
**Required for:** Video repost functionality

**Purpose:** Share/repost existing video content while preserving original attribution

**Implementation:**
- `SocialService.repostEvent()` creates Kind 6 events
- `VideoEventService` processes Kind 6 events and fetches original content
- `VideoFeedProvider` displays reposts with "Reposted by" indicator

**Example Structure:**
```json
{
  "kind": 6,
  "content": "",
  "tags": [
    ["e", "original_video_event_id"],
    ["p", "original_author_pubkey"]
  ],
  "pubkey": "reposter_pubkey",
  "created_at": 1672531200
}
```

**Required Tags:**
- `e` tag - References the original video event ID
- `p` tag - References the original video author's pubkey

### Kind 22 - Short Videos (NIP-71)
**Required for:** Primary video content

**Purpose:** Short-form video content similar to Vine/TikTok

**Implementation:**
- `VideoEventService` subscribes to Kind 22 events
- `VideoEvent.fromNostrEvent()` parses video metadata
- Core content type for the feed

**Example Structure:**
```json
{
  "kind": 22,
  "content": "Check out this amazing sunset!",
  "tags": [
    ["url", "https://example.com/video.mp4"],
    ["title", "Amazing Sunset"],
    ["duration", "15"],
    ["thumb", "https://example.com/thumbnail.jpg"],
    ["t", "sunset"],
    ["t", "nature"]
  ],
  "pubkey": "creator_pubkey",
  "created_at": 1672531200
}
```

## Secondary Event Types

### Kind 1 - Text Notes (NIP-01)
**Used for:** Comments on videos

**Implementation:**
- `SocialService.postComment()` creates Kind 1 events with video references
- Comments reference parent video with `e` tags

### Kind 3 - Contact Lists (NIP-02)  
**Used for:** Follow/following relationships

**Implementation:**
- `SocialService.followUser()` and `unfollowUser()` manage Kind 3 events
- Used for social graph and feed filtering

### Kind 5 - Deletion Events (NIP-09)
**Used for:** Unlike functionality, content removal

**Implementation:**
- `SocialService._publishUnlike()` creates Kind 5 events to delete reactions

### Kind 7 - Reactions (NIP-25)
**Used for:** Like/heart reactions on videos

**Implementation:**
- `SocialService.toggleLike()` creates Kind 7 events with "+" content
- Used for engagement metrics

## Event Subscription Requirements

### VideoEventService Subscriptions
```dart
// Required filter for complete video feed functionality
final filter = Filter(
  kinds: [22, 6], // Videos AND reposts
  // ... other filter parameters
);
```

### UserProfileService Subscriptions
```dart
// Required for user profile display
final filter = Filter(
  kinds: [0], // User profiles
  authors: [pubkey],
);
```

### SocialService Subscriptions
```dart
// Multiple subscriptions needed for full social functionality:

// 1. User reactions
Filter(kinds: [7], authors: [currentUserPubkey])

// 2. User follow list  
Filter(kinds: [3], authors: [currentUserPubkey])

// 3. Comments on videos
Filter(kinds: [1], e: [videoEventId])

// 4. Follower counts
Filter(kinds: [3], p: [targetPubkey])
```

## Critical Implementation Notes

### Repost System Requirements
1. **Kind 6 Event Processing:** VideoEventService MUST subscribe to Kind 6 events
2. **Original Event Fetching:** When receiving Kind 6, fetch the referenced Kind 22 event
3. **Metadata Preservation:** Repost VideoEvents preserve original content but add repost metadata
4. **UI Indication:** Display "Reposted by [user]" with green vine theme

### Profile System Requirements  
1. **Kind 0 Caching:** UserProfileService MUST cache Kind 0 events locally
2. **Display Names:** Extract `name` field from Kind 0 content JSON
3. **Fallback Handling:** Show "Anonymous" when profile not available
4. **Profile Updates:** Re-fetch profiles when displaying new users

### Feed Integration
The video feed requires both event types working together:

```dart
// VideoFeedProvider workflow:
1. VideoEventService receives Kind 22 (videos) and Kind 6 (reposts)
2. For Kind 6: fetch original Kind 22 and create repost VideoEvent
3. UserProfileService provides Kind 0 data for user display
4. UI shows: "Reposted by [Kind 0 name]" above "[Kind 0 name]" for original creator
```

## Error Handling

### Missing Profile Data (Kind 0)
- Default to "Anonymous" display name
- Use placeholder avatar
- Retry profile fetch in background

### Failed Repost Processing (Kind 6)
- Log error but don't crash feed
- Skip displaying repost if original can't be fetched
- Provide user feedback for failed repost actions

### Network Failures
- Cache last known profiles and repost data
- Graceful degradation when events unavailable
- Retry mechanisms for critical event types

## Testing Requirements

### Event Processing Tests
- Verify Kind 6 processing creates correct repost VideoEvents
- Test Kind 0 parsing extracts correct profile fields
- Validate fallback behavior for missing events

### Integration Tests  
- Test complete repost workflow (create → process → display)
- Verify profile updates reflect in UI
- Test feed with mixed Kind 22 and Kind 6 events

## Migration Notes

If updating existing NostrVine installations:
1. Ensure VideoEventService filter includes Kind 6 events
2. Update UI components to handle repost indicators
3. Verify UserProfileService properly caches Kind 0 events
4. Test repost button functionality with authentication

## Related NIPs

- **NIP-01:** Basic protocol flow (Kind 0, 1)
- **NIP-02:** Contact Lists and petnames (Kind 3)  
- **NIP-09:** Event Deletion (Kind 5)
- **NIP-18:** Reposts (Kind 6)
- **NIP-25:** Reactions (Kind 7)
- **NIP-71:** Video Events (Kind 22)

## Performance Considerations

### Event Fetching Strategy
- Batch profile requests where possible
- Cache frequently accessed profiles longer
- Prioritize visible content profiles
- Background fetch for off-screen content

### Repost Processing
- Avoid duplicate processing of same repost events
- Cache original events after first fetch
- Limit concurrent original event fetches
- Timeout stale repost processing requests