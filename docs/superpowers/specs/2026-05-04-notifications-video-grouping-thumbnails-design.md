# Notifications: video-anchored grouping, thumbnails, and realtime flicker fix

**Date:** 2026-05-04
**Owner:** rabble (mobile)
**Status:** Proposal — spec for implementation
**Branch:** `fix/notifications-video-grouping`
**Related:**
- `docs/superpowers/specs/2026-04-20-funnelcake-notifications-api-changes.md` (backend additive fields)
- Issue #3151 (user complaint: out-of-sync counts, lingering rows)
- PR #3548 (initial Figma redesign — already merged)

---

## Problem

Three concrete defects in the current notifications screen:

### 1. No video thumbnail on any row

The notifications endpoint returns `referenced_event_id` but no video metadata. `NotificationRepository._enrichAndGroup` only fetches actor profiles — it never resolves the referenced event into a video. The `NotificationItem` model has no `thumbnailUrl` field. The widget renders only an actor avatar and "liked your video" text. **Users cannot tell which of their videos was liked.**

### 2. Grouping is keyed correctly but threshold and fallback are wrong

`NotificationRepository._groupLikesByVideo` groups by `referencedEventId` — that part is correct. Two bugs make grouping fail in practice:

- **Threshold is `>= 2`.** A single like becomes a `SingleNotification` (no video context), only 2+ likes on the same video become a `GroupedNotification`. The presentation model is split *based on actor count*, so the row layout is inconsistent.
- **Null `referencedEventId` falls back to `dedupeKey`** (per-row unique). Notifications missing the referenced event id become orphan singletons that can never group with anything.

The user's mental model — and the right model — is **one row per video, regardless of how many people interacted with it**. 1 like = thumbnail + 1 avatar. 50 likes = thumbnail + stacked avatars + "and 47 others".

### 3. Realtime flicker — notification renders without username, then replaces

`NotificationFeedBloc._onRealtimeReceived` inserts incoming notifications **without** profile enrichment:

```dart
void _onRealtimeReceived(...) {
  final exists = state.notifications.any((n) => n.id == incoming.id);
  if (exists) return;
  emit(state.copyWith(notifications: [incoming, ...state.notifications], ...));
}
```

If the incoming notification arrives without a hydrated profile (or the profile fetcher is racing), the actor displays as "Unknown user" until the next refresh replaces it. Visually: row pops in nameless, then snaps to the real name a moment later.

---

## Goals

1. **One row per video × kind.** Likes, comments, and reposts on the same video collapse into one row regardless of count.
2. **Video thumbnail on every video-anchored row.** No mystery as to which video was liked/commented on.
3. **No nameless flicker on realtime inserts.** Either the row arrives fully enriched, or it doesn't render until enrichment lands.

## Non-goals

- Backend changes. The funnelcake spec at `2026-04-20-funnelcake-notifications-api-changes.md` covers `referenced_event_title`, `reply_context`, and `target_comment_id`. Those are tracked separately. This work is **client-only** and uses the existing `getBulkVideoStats` endpoint.
- Extending grouping to follows or system notifications. Follows stay one-row-per-actor. System stays one-row-per-event.
- Push notification payload changes.
- Mention handling redesign. (Mentions remain `SingleNotification`.)

---

## Design

### Model: collapse single/grouped for video-anchored notifications

Replace the current `SingleNotification` / `GroupedNotification` split with a clearer split based on **what the notification is anchored to**, not actor count.

```dart
sealed class NotificationItem {
  // common fields: id, type, timestamp, isRead
}

/// One row per (video × kind). 1 actor or N actors — same row shape.
class VideoNotification extends NotificationItem {
  final String videoEventId;
  final String? videoThumbnailUrl;
  final String? videoTitle;
  final List<ActorInfo> actors;     // 1..maxStackSize
  final int totalCount;             // total people, may exceed actors.length
  // type ∈ {like, comment, repost}
}

/// Actor-anchored — follows, mentions, system. No video.
class ActorNotification extends NotificationItem {
  final ActorInfo actor;
  final String? commentText;        // for mentions, if any
  final bool isFollowingBack;       // for follows
  // type ∈ {follow, mention, system}
}
```

**Why this shape:** the existing sealed split mixes presentation-count concerns (single vs grouped) with information-architecture concerns (video vs actor anchored). A single like and 50 likes on the same video are the same *thing* — they should render with the same widget.

The `Single`/`Grouped` distinction goes away. UI exhaustively switches on `VideoNotification | ActorNotification`.

### Repository: enrich both profiles AND videos in parallel

`NotificationRepository._enrichAndGroup` becomes:

```dart
Future<List<NotificationItem>> _enrichAndGroup(List<RelayNotification> raw) async {
  if (raw.isEmpty) return [];

  final pubkeys = raw.map((n) => n.sourcePubkey).toSet().toList();
  final eventIds = raw
      .map((n) => n.referencedEventId)
      .whereType<String>()
      .toSet()
      .toList();

  // Parallel: profiles (one batched call) + video stats (N parallel
  // per-event calls). The bulk stats endpoint returns engagement counts
  // only — no thumbnail or title — so we use the per-event
  // getVideoStats which returns full VideoStats. With ~50 notifications
  // referencing ~20 distinct videos, that's 20 concurrent HTTPS calls
  // wrapped in one Future.wait. Acceptable until backend adds
  // referenced_event_title (see 2026-04-20-funnelcake-notifications-
  // api-changes.md).
  final profilesFuture = _profileRepository.fetchBatchProfiles(
    pubkeys: pubkeys,
  );
  final videosFuture = _fetchVideoMetadata(eventIds);
  final (profiles, videosById) = await (profilesFuture, videosFuture).wait;

  final consolidated = _consolidateFollows(raw);
  final videoNotifications =
      _groupVideoAnchored(consolidated, profiles, videosById);
  final actorNotifications = _mapActorAnchored(consolidated, profiles);

  return [...videoNotifications, ...actorNotifications]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
}

/// Fetches VideoStats for each id in parallel; tolerates per-id failures.
Future<Map<String, VideoStats>> _fetchVideoMetadata(
  List<String> eventIds,
) async {
  if (eventIds.isEmpty) return const {};
  final futures = eventIds.map(
    (id) => _funnelcakeApiClient.getVideoStats(id).catchError(
      (_) => null,
    ),
  );
  final results = await Future.wait(futures);
  final map = <String, VideoStats>{};
  for (var i = 0; i < eventIds.length; i++) {
    final stats = results[i];
    if (stats != null) map[eventIds[i]] = stats;
  }
  return map;
}
```

**Grouping rule (replaces `_groupLikesByVideo`):**

For each `RelayNotification` whose `notificationType` is video-anchored (like/comment/repost) AND has a non-null `referencedEventId`:

- Group by `(referencedEventId, kind)`. So likes on video X and comments on video X are separate rows.
- Every group becomes a `VideoNotification`, regardless of size. **No `>= 2` threshold.**
- `actors` is the first N (max 3) sorted newest-first.
- `totalCount` is the full group size.
- `videoThumbnailUrl`, `videoTitle` come from the matching `VideoStats`.
- Notifications with `referencedEventId == null` and a video-anchored type are dropped (or downgraded to `ActorNotification` system entry — TBD; default: **drop**, since they're not actionable).

### Realtime: enrich before emitting

`_onRealtimeReceived` becomes async and enriches before inserting:

```dart
Future<void> _onRealtimeReceived(...) async {
  final exists = state.notifications.any(...);
  if (exists) return;

  // Enrich the incoming raw notification into a NotificationItem
  // (calls profile + video stat fetch for just this one).
  final enriched = await _notificationRepository.enrichOne(event.raw);
  if (enriched == null) return; // couldn't enrich → skip rather than show nameless

  // Merge with existing items — collapse into existing video group if applicable.
  final merged = _mergeIncoming(state.notifications, enriched);
  emit(state.copyWith(notifications: merged, unreadCount: state.unreadCount + 1));
}
```

`_mergeIncoming` either:
- Adds the actor to an existing matching `VideoNotification`'s actor list (and bumps `totalCount`), or
- Inserts as a new top-of-list item.

This kills the "Unknown user → real name" flicker — the row never renders without a name.

### Widget: one shared row layout for `VideoNotification`

```
┌────────────────────────────────────────────────────┐
│ [stacked avatars]  Kay and 4 others liked      [▶ thumb] │
│                    your video               5m         │
└────────────────────────────────────────────────────┘
```

- Avatar stack on the left (1 to 3 avatars + "+N" overflow if `totalCount > actors.length`).
- Type badge (heart/comment/repost icon) on the avatar stack.
- Message text middle: "{first actor} liked your video" or "{first} and {N} others liked your video".
- **Thumbnail on the right** — 56×56, rounded corners, taps through to the video.
- Timestamp under the message.

`ActorNotification` keeps the existing single-avatar layout (with the type badge), no thumbnail (no video to show).

### Tap behavior

- `VideoNotification` tap → navigate to that video. Same `_navigateToVideo` flow as today.
- `ActorNotification` (follow) tap → navigate to actor profile.
- `ActorNotification` (mention) tap → navigate to the mentioning content.
- Avatar tap on either → actor profile (if multi-actor video row, taps the first actor's profile, OR opens an "X people liked this" sheet — see open question 1).

---

## Migration

The old `SingleNotification` and `GroupedNotification` types are used by:
- `NotificationRepository` (constructs them)
- `NotificationFeedBloc` (pattern-matches in `_onItemTapped`, `_onFollowBack`)
- `NotificationListItem` widget (exhaustive switch)
- `NotificationsView._navigateForSingle` / `_navigateForGrouped`
- Tests in `notification_repository_test.dart` and any widget tests

All of these must update in one PR. The sealed type change is breaking but contained — no public API outside `mobile/`. Replace exhaustively, no compatibility shim.

---

## Testing strategy

**Repository (`notification_repository_test.dart`):**
- Single like → `VideoNotification` with `actors.length == 1`, `totalCount == 1`, thumbnail populated.
- 5 likes on same video → `VideoNotification` with `actors.length == 3` (max stack), `totalCount == 5`.
- 5 likes on 5 different videos → 5 separate `VideoNotification`s.
- Likes + comments on same video → 2 `VideoNotification`s (different `kind`).
- Notification with null `referencedEventId` → dropped from list.
- `getBulkVideoStats` returns empty → rows still render with null thumbnail (no crash).
- `getBulkVideoStats` and `fetchBatchProfiles` errors → notifications still return with degraded enrichment (existing failure-tolerance behavior preserved).

**BLoC (`notification_feed_bloc_test.dart`):**
- Realtime received with successful enrichment → row inserted with actor name and thumbnail.
- Realtime received that matches an existing `VideoNotification` → actor merged into that group, `totalCount` increments.
- Realtime received with failed enrichment → state unchanged (no nameless flicker).

**Widget (`notification_list_item_test.dart`):**
- `VideoNotification` with 1 actor renders thumbnail + 1 avatar.
- `VideoNotification` with 5 actors renders thumbnail + 3 avatars + "+2".
- `ActorNotification` follow renders single avatar + Follow back button.
- Tapping thumbnail vs row vs avatar fires the correct callback.
- Golden: `VideoNotification` with 1, 3, and 50 actors.

---

## Open questions

1. **Multi-actor avatar tap.** When a `VideoNotification` has 5+ actors, what does tapping the avatar stack do?
   - **Option A** (recommended): tap whole row → video. Tap avatar stack → bottom sheet listing all actors with profile links.
   - **Option B**: tap avatar stack → first actor's profile. Lose the "see who else" affordance.
   - Default to A; punt the sheet to a follow-up if it's too much for this PR.

2. **What if `getBulkVideoStats` returns a video the user has blocked / is unavailable?**
   - Render with placeholder thumbnail or hide the notification entirely?
   - Recommended: render with placeholder + treat tap as no-op + brief snackbar. Matches existing "Video not found" handling in `_navigateToVideo`.

3. **Threshold for showing actor names in message text.** With 50 likes the message becomes unwieldy if we name 3. Recommend "Kay and 49 others liked your video" — only the first actor is named. With ≥ 2 total: "{first} and {N-1} others". With 1 total: "{first}".

---

## Rollout plan

Single PR. No feature flag. Behavior change is strictly an improvement — degraded path (network failures) is no worse than today.

1. Land repository changes + new model + tests.
2. Land BLoC realtime enrichment + tests.
3. Land widget changes + golden updates.
4. Manual QA: scroll a populated notifications screen, verify thumbnails, verify grouping with multi-like videos, verify realtime push lands cleanly.

---

## Out of scope (file separately if desired)

- Push notification payload — relies on backend to embed thumbnail URL or video event id for in-banner preview.
- Notification settings per-kind (mute likes, mute comments). Existing #588 covers this.
- Funnelcake-side `referenced_event_title` rollout — covered by `2026-04-20-funnelcake-notifications-api-changes.md`. Once that lands, we can drop the client-side `getBulkVideoStats` call in favor of the inline title (still need bulk stats for thumbnails until that's added too — TODO followup spec).
