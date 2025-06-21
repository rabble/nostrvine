# NostrVine Social Features - GitHub Issues Documentation

This document contains comprehensive technical specifications for implementing missing social features in NostrVine. Each section can be copied directly into GitHub issues.

---

## Issue 1: Implement Like System (NIP-25 Reactions)

**Title:** Implement Like System (NIP-25 Reactions)  
**Labels:** `type:feature`, `priority:high`, `social-features`, `nostr-protocol`

### Overview
Implement a comprehensive like system using NIP-25 reactions to replace the current placeholder SnackBar implementation.

### Technical Requirements

#### Nostr Protocol
- **NIP-25** using **Kind 7** events for reactions
- Like represented by content `+`
- Must include `e` tag referencing liked event ID
- Must include `p` tag for liked event author pubkey

#### Service Methods
Create new `SocialService` with:
```dart
/// Likes or unlikes a Nostr event
Future<void> toggleLike(String eventId, String authorPubkey);

/// Fetches like count and user like status
/// Returns {'count': int, 'user_liked': bool}
Future<Map<String, dynamic>> getLikeStatus(String eventId);

/// Fetches all events liked by a specific user
Future<List<Event>> fetchLikedEvents(String pubkey);
```

#### Database/Caching
- `SocialService` maintains in-memory `Set<String>` of liked eventIds for immediate UI feedback
- Like counts cached in `Map<String, int>` to avoid redundant network requests

### Implementation Approach

1. **Create `SocialService`**
   - Implement `toggleLike` method constructing Kind 7 events
   - Use `AuthService` keypair and `NostrService.broadcastEvent()`
   - Maintain in-memory `Set<String>` of liked eventIds for immediate UI feedback

2. **Update `VideoFeedItem`**
   - Replace `onLike` placeholder to call `SocialService.toggleLike`
   - Toggle between `Icons.favorite` (liked) and `Icons.favorite_border` (not liked)
   - Display like count next to button

3. **Implement Like Count**
   - Use `NostrService.subscribeToEvents` with filter: `Filter(kinds: [7], tags: {'e': [eventId]})`
   - Count received events for like total

4. **Implement Liked Videos Grid**
   - Update "Liked" tab in `ProfileScreen`
   - Subscribe to Kind 7 events: `Filter(authors: [pubkey], kinds: [7])`
   - Extract `e` tags and fetch original video events

### Files to Modify
- `lib/services/social_service.dart` (new)
- `lib/widgets/video_feed_item.dart`
- `lib/screens/profile_screen.dart`
- `lib/screens/feed_screen.dart`
- Add `SocialService` to provider chain in `main.dart`

### Acceptance Criteria
- [ ] Tapping like button sends valid NIP-25 Kind 7 event
- [ ] Button state updates immediately with visual feedback
- [ ] Like count displays accurately
- [ ] "Liked" tab on user profile shows liked videos
- [ ] Unit tests for `SocialService.toggleLike`
- [ ] Widget tests for `VideoFeedItem` like state changes

---

## Issue 2: Implement Follow System (NIP-02 Contact Lists)

**Title:** Implement Follow System (NIP-02 Contact Lists)  
**Labels:** `type:feature`, `priority:high`, `social-features`, `nostr-protocol`

### Overview
Implement a comprehensive follow system using NIP-02 contact lists to replace current placeholder SnackBar implementations and hardcoded follower counts.

### Technical Requirements

#### Nostr Protocol
- **NIP-02** using **Kind 3** events for contact lists
- User's follow list defined by `p` tags in most recent Kind 3 event

#### Service Methods
Add to `SocialService` or `AuthService`:
```dart
/// Fetches current user's follow list and caches it
Future<void> fetchCurrentUserFollowList();

/// Adds pubkey to user's follow list and broadcasts updated Kind 3 event
Future<void> followUser(String pubkeyToFollow);

/// Removes pubkey from user's follow list and broadcasts updated Kind 3 event
Future<void> unfollowUser(String pubkeyToUnfollow);

/// Fetches follower and following counts for given pubkey
Future<Map<String, int>> getFollowerStats(String pubkey);
```

#### Database/Caching
- Cache current user's followed pubkeys (`List<String>`) for quick UI updates
- Cache follower/following counts to prevent re-fetching on every profile view

### Implementation Approach

1. **Update `AuthService`/`SocialService`**
   - Implement `fetchCurrentUserFollowList` to get latest Kind 3 event
   - Implement `followUser`/`unfollowUser`:
     - Get current followed pubkeys list
     - Add/remove target pubkey
     - Create new Kind 3 event with updated `p` tags
     - Sign and broadcast via `NostrService`
     - Update local cache and notify listeners

2. **Follower Count Implementation**
   - **Following count:** Fetch user's Kind 3 and count `p` tags
   - **Followers count:** Query for Kind 3 events with `p` tag for user's pubkey: `Filter(kinds: [3], tags: {'p': [profilePubkey]})`
   - Note: This can be slow and incomplete - consider indexing services

3. **Update `ProfileScreen`**
   - Consume follow list to determine follow button state
   - Replace hardcoded stats in `_buildStatColumn` with `getFollowerStats` data
   - Button toggles between "Follow" and "Following"

### Files to Modify
- `lib/services/social_service.dart` (extend)
- `lib/services/auth_service.dart` (or extend SocialService)
- `lib/screens/profile_screen.dart`
- `lib/widgets/video_feed_item.dart` (follow button on user tap)

### Acceptance Criteria
- [ ] Clicking "Follow" adds user to Kind 3 contact list and broadcasts event
- [ ] Button text changes to "Following" immediately
- [ ] Follower/Following counts populate with real data
- [ ] Current user's follow list loaded on app start and cached
- [ ] Follow button state always accurate across app
- [ ] Unit tests for follow/unfollow functionality
- [ ] Performance acceptable for follower count queries

---

## Issue 3: Implement Comment System

**Title:** Implement Comment System with Threaded Replies  
**Labels:** `type:feature`, `priority:medium`, `social-features`, `nostr-protocol`

### Overview
Implement a complete comment system using Kind 1 text note events to replace the current placeholder comment functionality.

### Technical Requirements

#### Nostr Protocol
- Comments are **Kind 1** (text note) events
- Must include `e` tag pointing to video's event ID (root thread identifier)
- Must include `p` tag for video author's pubkey
- Replies to comments should tag both root event and parent comment

#### Service Methods
Add to `SocialService`:
```dart
/// Posts a comment in reply to a root event (video)
Future<void> postComment({
  required String content,
  required String rootEventId,
  required String rootEventAuthorPubkey,
  String? replyToEventId, // Optional: for threaded replies
  String? replyToAuthorPubkey // Optional: for threaded replies
});

/// Fetches all comments for a given root event ID
Stream<Event> fetchCommentsForEvent(String rootEventId);
```

#### UI Components
- New **Comment Sheet/Screen** triggered by `_openComments` in `feed_screen.dart`
- Display list of comments with input field for new comments
- Update `VideoFeedItem` comment icon to show comment count

### Implementation Approach

1. **Create Comment UI**
   - Design bottom sheet or full screen presented by `_openComments`
   - Takes `VideoEvent` as parameter
   - Shows existing comments and input for new ones

2. **Implement `CommentsProvider`**
   - Manages state for single comment thread
   - Uses `SocialService.fetchCommentsForEvent` with filter: `Filter(kinds: [1], tags: {'e': [rootEventId]})`
   - Manages `List<Event>` of comments and loading state

3. **Implement `SocialService.postComment`**
   - Creates Kind 1 event with content and correct `e`/`p` tags
   - Broadcasts via `NostrService`

4. **Update `VideoFeedItem`**
   - `onComment` callback shows new comment UI
   - Fetch and display comment count next to icon

### Files to Modify
- `lib/services/social_service.dart` (extend)
- `lib/screens/comments_screen.dart` (new)
- `lib/providers/comments_provider.dart` (new)
- `lib/widgets/video_feed_item.dart`
- `lib/screens/feed_screen.dart`

### Acceptance Criteria
- [ ] Users can open comment thread for any video
- [ ] Users can view existing comments
- [ ] Users can post new comments
- [ ] New comments appear in thread in near real-time
- [ ] Comment count displays next to comment icon
- [ ] Threading support for replies to comments
- [ ] Unit tests for `postComment` with correct tag creation
- [ ] Widget tests for comment screen

---

## Issue 4: Implement Repost System (NIP-18)

**Title:** Implement Repost System (NIP-18)  
**Labels:** `type:feature`, `priority:medium`, `social-features`, `nostr-protocol`

### Overview
Implement video reposting functionality using NIP-18 to allow users to share videos in their feeds.

### Technical Requirements

#### Nostr Protocol
- **NIP-18** using **Kind 6** events for reposts
- Must contain `e` tag referencing ID of reposted event
- Must contain `p` tag for original author
- Content typically empty

#### Service Methods
Add to `SocialService`:
```dart
/// Reposts a Nostr event
Future<void> repostEvent(Event eventToRepost);
```

#### UI Components
- Add "Repost" button to `VideoFeedItem`, possibly under Share menu
- `VideoFeedProvider` must handle Kind 6 events in feed
- Display "Reposted by..." header for reposted content

### Implementation Approach

1. **Add Repost Button**
   - Add repost button to `VideoFeedItem` UI
   - `onTap` calls `SocialService.repostEvent`

2. **Implement `SocialService.repostEvent`**
   - Creates Kind 6 event pointing to target event
   - Broadcasts via `NostrService`

3. **Update `VideoFeedProvider`**
   - Modify event handling for Kind 6 events:
     - Extract `e` tag to find original video event ID
     - Fetch original event
     - Create wrapper model with original `VideoEvent` + reposter pubkey
     - Add wrapper to feed list

4. **Update `VideoFeedItem`**
   - Accept optional "reposted by" information
   - Display repost indicator when present

### Files to Modify
- `lib/services/social_service.dart` (extend)
- `lib/providers/video_feed_provider.dart`
- `lib/widgets/video_feed_item.dart`
- `lib/models/video_event.dart` (possibly extend for repost wrapper)

### Acceptance Criteria
- [ ] Users can repost videos
- [ ] Reposted videos appear in followers' feeds
- [ ] Feed displays "Reposted by..." indicator
- [ ] `VideoFeedProvider` correctly identifies and wraps reposted events
- [ ] Repost action provides clear feedback
- [ ] Unit tests for repost event creation
- [ ] Integration tests for repost feed display

---

## Issue 5: Replace Hardcoded Social Statistics with Dynamic Data

**Title:** Replace Hardcoded Social Statistics with Dynamic Data  
**Labels:** `type:feature`, `priority:medium`, `data-aggregation`, `social-features`

### Overview
Replace all hardcoded numbers in profile screens (vine count, follower count, total views, total likes) with real data aggregated from Nostr events.

### Technical Requirements

#### Data Sources
- **Vines Count:** Query for user's video events (Kind 34550 or applicable video kind)
- **Followers/Following:** Use `SocialService.getFollowerStats`
- **Total Likes:** Aggregate Kind 7 events for all user's videos
- **Total Views:** Requires view tracking implementation (separate issue)

#### Service Methods
Add to `SocialService` or new `ProfileStatsService`:
```dart
/// Gets comprehensive stats for a user profile
Future<Map<String, dynamic>> getProfileStats(String pubkey);

/// Gets video count for a user
Future<int> getUserVideoCount(String pubkey);

/// Gets total likes across all user's videos
Future<int> getUserTotalLikes(String pubkey);
```

#### Performance Considerations
- Heavy caching required for like aggregation
- Asynchronous loading with loading indicators
- Consider indexing services for complex aggregations

### Implementation Approach

1. **Create `ProfileStatsProvider`**
   - Takes `pubkey` parameter
   - Fetches all stats for given profile
   - Notifies UI as data becomes available

2. **Update `ProfileScreen`**
   - Consume `ProfileStatsProvider`
   - Replace hardcoded numbers with provider data
   - Show loading states while fetching

3. **Refactor `_buildStatColumn`**
   - Change signature to accept `Future<int>` or nullable `int`
   - Handle asynchronous data loading
   - Display '...' or loading indicator until data arrives

4. **Implement Aggregation Logic**
   - Video count: Query user's video events
   - Total likes: For each user video, fetch its Kind 7 events and sum
   - Cache results to avoid repeated expensive queries

### Files to Modify
- `lib/providers/profile_stats_provider.dart` (new)
- `lib/services/social_service.dart` (extend)
- `lib/screens/profile_screen.dart`

### Acceptance Criteria
- [ ] All profile stats are dynamic and reflect real Nostr data
- [ ] Stats load asynchronously with loading indicators
- [ ] Previously fetched stats cached for session
- [ ] Performance acceptable for stats aggregation
- [ ] Graceful handling of users with many videos/interactions
- [ ] Unit tests for stats calculation methods

---

## Issue 6: Implement User Video Fetching for Profile Grids

**Title:** Implement User Video Fetching for Profile Grids  
**Labels:** `type:feature`, `priority:medium`, `profile-features`, `video-display`

### Overview
Replace placeholder video grids in user profiles with real video content fetched from Nostr events authored by the profile user.

### Technical Requirements

#### Nostr Protocol
- Fetch video events (Kind 34550 or applicable) authored by specific user
- Support pagination for users with many videos

#### Service Methods
Add to `VideoFeedProvider` or new `ProfileVideosProvider`:
```dart
/// Fetches list of video events for given user pubkey
Future<void> fetchVideosForUser(String pubkey);

/// Loads more videos for pagination
Future<void> loadMoreVideosForUser(String pubkey);
```

#### UI Components
- Rewrite `_buildVinesGrid` in `ProfileScreen` 
- Use `GridView.builder` fed by `List<VideoEvent>`
- Each grid item shows video thumbnail
- Support "load more" functionality

### Implementation Approach

1. **Create `ProfileVideosProvider`**
   - Takes `pubkey` parameter
   - Uses `NostrService.subscribeToEvents` with filter: `Filter(authors: [pubkey], kinds: [34550])`
   - Parses events into `VideoEvent` models
   - Manages list, loading state, and errors

2. **Update `ProfileScreen`**
   - Create `ChangeNotifierProvider` for `ProfileVideosProvider`
   - `_buildVinesGrid` becomes `Consumer` of provider
   - Use `GridView.builder` with video list
   - Each cell shows thumbnail using `CachedNetworkImage`
   - Tapping item navigates to video detail or plays video

3. **Implement Pagination**
   - Support "load more" when scrolling near end
   - Manage pagination state and prevent duplicate requests

### Files to Modify
- `lib/providers/profile_videos_provider.dart` (new)
- `lib/screens/profile_screen.dart`
- Update provider chain in `main.dart`

### Acceptance Criteria
- [ ] "Vines" tab displays grid of user's published videos
- [ ] Thumbnails load efficiently using `CachedNetworkImage`
- [ ] Pagination or "load more" for users with many videos
- [ ] Loading indicator while fetching videos
- [ ] Clear message for users with no videos
- [ ] Tapping grid item navigates appropriately
- [ ] Performance acceptable for users with many videos
- [ ] Unit tests for video fetching logic

---

## Implementation Priority and Dependencies

### Phase 1 (High Priority)
1. **Like System** - Core social engagement feature
2. **Follow System** - Essential for social network functionality

### Phase 2 (Medium Priority)  
3. **Dynamic Statistics** - Improves data accuracy
4. **User Video Fetching** - Completes profile functionality

### Phase 3 (Medium Priority)
5. **Comment System** - Enhances engagement
6. **Repost System** - Advanced sharing functionality

### Dependencies
- All features depend on creating `SocialService`
- Statistics depend on Like and Follow systems
- Repost system depends on updated `VideoFeedProvider` architecture

### Notes for Implementation
- Consider creating `SocialService` first as foundation for all features
- Implement comprehensive caching to handle Nostr query performance
- Add proper error handling for network failures
- Include loading states throughout UI
- Focus on making features work with existing `NostrService` infrastructure