# Notifications BLoC Refactor Design

## Problem

All notifications currently show "Someone liked your video" with generic purple avatars. The notification system uses Riverpod with a fire-and-forget profile enrichment pattern that has a race condition — `fetchBatchProfiles()` is called as `unawaited()`, then the cache is read immediately before the write completes, producing null profiles.

Beyond the race condition, the notification UX is missing: real usernames, avatars, video titles, comment text previews, grouped likes, and proper navigation behavior.

## Scope

### In Scope
1. Full BLoC migration (replace all Riverpod notification providers)
2. Real usernames, avatars, video titles, comment text in every notification
3. Client-side like grouping ("alice and 93 others liked your video")
4. Reply vs comment distinction
5. Follow-back button on follow notifications
6. Remove type-filter tabs (All/Likes/Comments/Follows/Reposts) per d1 design
7. Push notification as relay re-fetch trigger
8. Empty state per Figma design

### Out of Scope (deferred)
- Follow list notification type (needs backend)
- Announcement notification type (needs backend)
- Flagged notification type (speculative per design notes)
- Server-side grouping (future funnelcake enhancement)
- Grouped notification bottom sheet (tap grouped → see all users)

## Design Reference

Figma designs define these notification types:

| Type | Layout | Content |
|------|--------|---------|
| Like | Avatar + heart icon | "{name} liked your video **{title}**" |
| Like (grouped) | Stacked avatars (up to 3) | "{name} and **N others** liked your video **{title}**" |
| Comment | Avatar + comment icon | "{name} commented on your video **{title}**" + comment text preview |
| Reply | Avatar | "{name} replied to your comment" |
| Repost | Avatar + repost icon | "{name} reposted your video **{title}**" |
| Follow | Avatar(s) | "{name} started following you" + optional "Follow back" button |

Interaction rules from design spec:
- Tap name/avatar → opens profile
- Tap like notification → opens liked post
- Tap comment → opens comment overlay on the video
- Tap reply → opens comment overlay on the relevant post
- Tap repost → opens reposted post in feed
- Tap follow → opens follower's profile
- Unread indicator: badge on notification item

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  UI Layer (lib/notifications/)                       │
│  NotificationsPage → NotificationsView               │
│  NotificationListItem (redesigned per Figma)         │
│  NotificationAvatarStack (grouped avatar display)    │
├─────────────────────────────────────────────────────┤
│  BLoC Layer (lib/notifications/bloc/)                │
│  NotificationFeedBloc                                │
│  Events: Started, LoadMore, Refresh, PushReceived,   │
│          RealtimeReceived, ItemTapped, MarkAllRead,   │
│          FollowBack                                  │
│  State: enum status + notifications + pagination     │
├─────────────────────────────────────────────────────┤
│  Repository Layer (packages/notification_repository/) │
│  NotificationRepository                              │
│  - REST fetch (FunnelcakeApiClient)                  │
│  - WebSocket real-time stream (NostrClient)          │
│  - Profile enrichment (ProfileRepository)            │
│  - Client-side like grouping                         │
│  - Follow consolidation                              │
├─────────────────────────────────────────────────────┤
│  Data Layer                                          │
│  FunnelcakeApiClient (notification endpoints added)  │
│  NostrClient (WebSocket subscriptions)               │
│  NotificationsDao (Drift local cache)                │
└─────────────────────────────────────────────────────┘
```

### Data Flow

**Initial load:**
1. BLoC dispatches `NotificationFeedStarted`
2. Repository fetches from REST API (funnelcake) with NIP-98 auth
3. Repository awaits `ProfileRepository.fetchBatchProfiles()` — uses return value directly (no fire-and-forget)
4. Repository resolves video titles from video events
5. Repository groups likes by `referencedEventId`, consolidates follows by pubkey
6. Repository returns enriched, grouped `NotificationPage` to BLoC
7. BLoC emits loaded state with `List<NotificationItem>`

**Real-time (WebSocket):**
1. Repository subscribes to Nostr events (reactions, comments, follows, reposts)
2. Parses raw Nostr events, enriches with profile data
3. Emits on `realtimeNotifications` stream
4. BLoC receives via `RealtimeReceived` event, inserts at top of list
5. Re-groups if the new event affects an existing group

**Push notification:**
1. FCM push arrives (background or foreground)
2. App dispatches `NotificationFeedPushReceived` to BLoC
3. BLoC calls `repository.refresh()` — fresh REST fetch from relay
4. Push payload is ignored as data — purely a signal to re-fetch
5. Relay is always the source of truth

**Non-funnelcake relays:**
- WebSocket path works with any standard Nostr relay
- REST API path is funnelcake-specific
- Repository handles both: REST when available, WebSocket-only as fallback
- All Nostr event parsing works with raw NIP events (no funnelcake-specific formats)

## Data Model

```dart
/// Lightweight profile snapshot for display
class ActorInfo extends Equatable {
  final String pubkey;
  final String displayName;
  final String? pictureUrl;
}

/// Base for all displayable notifications
sealed class NotificationItem extends Equatable {
  String get id;
  NotificationType get type;
  DateTime get timestamp;
  bool get isRead;
  String? get targetEventId;
  String? get videoTitle;
}

/// Single-actor: comment, reply, follow, repost, single like
class SingleNotification extends NotificationItem {
  final ActorInfo actor;
  final String? commentText;    // for comments/replies
  final bool isFollowingBack;   // for follows: show "Follow back" button
}

/// Grouped: "alice and 93 others liked your video"
class GroupedNotification extends NotificationItem {
  final List<ActorInfo> actors; // first 3 for stacked avatars
  final int totalCount;
}

/// Paginated response from repository
class NotificationPage {
  final List<NotificationItem> items;
  final int unreadCount;
  final String? nextCursor;
  final bool hasMore;
}
```

## BLoC Design

### Events

```dart
sealed class NotificationFeedEvent {}
class NotificationFeedStarted extends NotificationFeedEvent {}
class NotificationFeedLoadMore extends NotificationFeedEvent {}
class NotificationFeedRefreshed extends NotificationFeedEvent {}
class NotificationFeedPushReceived extends NotificationFeedEvent {}
class NotificationFeedRealtimeReceived extends NotificationFeedEvent {
  final NotificationItem notification;
}
class NotificationFeedItemTapped extends NotificationFeedEvent {
  final String notificationId;
}
class NotificationFeedMarkAllRead extends NotificationFeedEvent {}
class NotificationFeedFollowBack extends NotificationFeedEvent {
  final String pubkey;
}
```

### State

```dart
enum NotificationFeedStatus { initial, loading, loaded, failure }

class NotificationFeedState extends Equatable {
  final NotificationFeedStatus status;
  final List<NotificationItem> notifications;
  final int unreadCount;
  final bool hasMore;
  final bool isLoadingMore;

  bool get hasUnread => unreadCount > 0;
}
```

### Event Transformers
- `Started`, `Refreshed`, `PushReceived` → `droppable()` (prevent duplicate fetches)
- `LoadMore` → `droppable()` (ignore scroll events while already loading)
- `RealtimeReceived` → `concurrent()` (fast inserts, no conflict)
- `FollowBack` → `sequential()` (one follow action at a time)

## Repository Design

```dart
class NotificationRepository {
  NotificationRepository({
    required FunnelcakeApiClient funnelcakeApiClient,
    required NostrClient nostrClient,
    required ProfileRepository profileRepository,
    required NotificationsDao notificationsDao,
  });

  /// Fetch notifications — REST primary, enriched, grouped
  Future<NotificationPage> getNotifications({String? cursor});

  /// Fresh fetch — ignores cursor, re-fetches from start
  Future<NotificationPage> refresh();

  /// Real-time WebSocket events — parsed, enriched, emitted
  Stream<NotificationItem> get realtimeNotifications;

  /// Mark specific notifications as read
  Future<void> markAsRead(List<String> ids);

  /// Mark all notifications as read
  Future<void> markAllAsRead();

  /// Follow a user (for "Follow back" button)
  Future<void> followUser(String pubkey);
}
```

### Repository Responsibilities

1. **Fetch** raw notifications from REST API (funnelcake `GET /api/users/{pubkey}/notifications`)
2. **Enrich** — await `ProfileRepository.fetchBatchProfiles()`, use return value directly
3. **Resolve** video titles from `VideoEventService` or video event cache
4. **Group** likes by `referencedEventId` (same video) — keep up to 3 actor profiles, count total
5. **Consolidate** follow duplicates — keep earliest per pubkey (Nostr Kind 3 republishing issue)
6. **Distinguish** reply vs comment — check if referenced event is a comment (Kind 1111) vs video (Kind 34236)
7. **Cache** to Drift via `NotificationsDao`
8. **Subscribe** to WebSocket for real-time Nostr events, parse, enrich, emit on stream

## UI Structure

```
lib/notifications/
├── bloc/
│   ├── notification_feed_bloc.dart
│   ├── notification_feed_event.dart
│   └── notification_feed_state.dart
├── view/
│   ├── notifications_page.dart      # provides BLoC with deps from Riverpod
│   ├── notifications_view.dart      # renders list, handles lifecycle
│   └── view.dart                    # barrel
├── widgets/
│   ├── notification_list_item.dart  # single notification row
│   ├── notification_avatar_stack.dart # stacked avatars for grouped
│   ├── notification_empty_state.dart  # "No activity yet"
│   └── widgets.dart                 # barrel
└── notifications.dart               # feature barrel
```

### NotificationsPage
- `ConsumerWidget` — reads dependencies from Riverpod, creates BLoC
- Provides `NotificationFeedBloc` to subtree
- Dispatches `NotificationFeedStarted` on creation

### NotificationsView
- `@visibleForTesting` — testable in isolation
- `BlocBuilder` for list rendering
- `BlocListener` for navigation side effects (tap → open video/profile/comments)
- `ListView.builder` with date headers
- Pull-to-refresh via `RefreshIndicator`
- Scroll-based pagination via `ScrollController`

### NotificationListItem
- Renders per Figma design: avatar (or stacked avatars), message with bold name + bold video title, comment preview, timestamp
- `InkWell` for tap → dispatches `ItemTapped`
- `GestureDetector` on avatar → navigates to profile
- Unread indicator via background color
- "Follow back" button for follow notifications (dispatches `FollowBack`)
- Type icon overlay (heart, comment bubble, repost arrows, follow person icon)

## FunnelcakeApiClient Additions

Add to existing `packages/funnelcake_api_client/`:

```dart
// New methods on FunnelcakeApiClient
Future<NotificationResponse> getNotifications({
  required String pubkey,
  String? cursor,
  int limit = 50,
});

Future<void> markNotificationsRead({
  required String pubkey,
  List<String>? notificationIds, // null = mark all
});
```

Moves the NIP-98 authenticated REST calls from the standalone `RelayNotificationApiService` into the shared API client.

## Files to Delete

After migration, remove all legacy notification code:

- `lib/providers/relay_notifications_provider.dart`
- `lib/providers/notification_realtime_bridge_provider.dart`
- `lib/services/relay_notification_api_service.dart`
- `lib/services/notification_model_converter.dart`
- `lib/services/notification_helpers.dart`
- `lib/services/notification_event_parser.dart`
- `lib/services/notification_persistence.dart` (Hive replaced by Drift DAO)
- `lib/services/notification_service_enhanced.dart`
- `lib/screens/notifications_screen.dart` (replaced by Page/View)
- `lib/widgets/notification_list_item.dart` (replaced by new widget)
- `packages/models/lib/src/notification_model.dart` (replaced by sealed class)

## Testing Strategy

- **BLoC tests**: `blocTest` for each event — verify state transitions, pagination, grouping
- **Repository tests**: Mock `FunnelcakeApiClient`, `ProfileRepository`, `NostrClient` — verify enrichment, grouping logic, follow consolidation, reply vs comment distinction
- **Widget tests**: Pump `NotificationListItem` with mock data — verify avatar rendering, message content, tap behavior, follow-back button
- **Integration**: Verify BlocListener navigation (tap like → open video, tap comment → open comment overlay)

## Funnelcake API Enhancement Request (Future)

For the backend team — future improvements to reduce client-side work:

**1. Server-side like grouping**
Add `?group=true` query param returning pre-grouped notifications:
```json
{
  "type": "reaction_group",
  "referenced_event_id": "abc123",
  "video_title": "My awesome video",
  "actors": [{"pubkey": "...", "name": "alice", "picture": "..."}],
  "total_count": 94,
  "latest_at": 1712345678
}
```

**2. Pre-enriched responses**
Include `actor_name`, `actor_picture`, and `video_title` in notification responses so the client doesn't need a second round-trip for profile/video enrichment.

**3. Reply vs comment distinction**
Add `"reply"` as a distinct `notification_type` when the event is a reply to the user's comment (not a top-level comment on their video).

**4. Backward compatibility**
All enhancements additive — existing behavior unchanged. Mobile opts in via query params.

The mobile client always supports standard Nostr relays via WebSocket as a fallback. These API enhancements only affect the funnelcake REST path.

## Related Issues

- #2688 — All notifications show "Someone" (race condition — fixed by this refactor)
- #2667 — Wrong API host fallback (PR #2742 open)
- #2478 — Duplicate follow notifications (PR #2774 open)
- #2444 — Epic: notifications refactor to layered architecture
- #2433 — Notification tab freezes
- #2340 — Notifications briefly show new items then revert
- #2218 — Comment notification navigates to non-video
- #272 — Notifications displayed twice
