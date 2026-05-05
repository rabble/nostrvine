# Notifications: video-anchored grouping, thumbnails, realtime flicker — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the count-based `SingleNotification`/`GroupedNotification` split with a context-based `VideoNotification`/`ActorNotification` split, render video thumbnails on every video-anchored row, and stop realtime push notifications from flickering in nameless before they enrich.

**Architecture:** Pure mobile-side change. New sealed `NotificationItem` types in `mobile/packages/models`. `NotificationRepository` enriches with profiles + per-video `getVideoStats` in parallel and groups by `(referencedEventId, kind)` with no count threshold. `NotificationFeedBloc._onRealtimeReceived` becomes async — it asks the repository to enrich the incoming raw event before emitting, and either merges the actor into a matching existing `VideoNotification` or inserts a new one. Widgets get a unified video-row layout with avatar stack on the left and 56×56 thumbnail on the right.

**Tech Stack:** Dart 3 sealed classes, `flutter_bloc`, `bloc_concurrency`, `mocktail`, `bloc_test`, `cached_network_image` (via `VineCachedImage`), `divine_ui` (`VineTheme`, `DivineIcon`).

**Spec:** `docs/superpowers/specs/2026-05-04-notifications-video-grouping-thumbnails-design.md`

**Worktree:** `.worktrees/fix-notifications-video-grouping` (branch `fix/notifications-video-grouping`)

---

## File Structure

### Created files

- `mobile/packages/models/lib/src/video_notification.dart` — new `VideoNotification` class.
- `mobile/packages/models/lib/src/actor_notification.dart` — new `ActorNotification` class.
- `mobile/packages/models/test/src/video_notification_test.dart` — equality, copyWith, message getter.
- `mobile/packages/models/test/src/actor_notification_test.dart` — equality, copyWith, message getter.
- `mobile/lib/notifications/widgets/video_notification_row.dart` — new row widget for `VideoNotification`.
- `mobile/lib/notifications/widgets/actor_notification_row.dart` — new row widget for `ActorNotification`.
- `mobile/test/notifications/widgets/video_notification_row_test.dart`
- `mobile/test/notifications/widgets/actor_notification_row_test.dart`

### Modified files

- `mobile/packages/models/lib/src/notification_item.dart` — keep the sealed base, **delete** `SingleNotification` and `GroupedNotification` classes; the file becomes the sealed parent only.
- `mobile/packages/models/lib/models.dart` — export new files.
- `mobile/packages/notification_repository/lib/src/notification_repository.dart` — replace `_groupLikesByVideo` with `_groupVideoAnchored` + `_mapActorAnchored`; add `_fetchVideoMetadata`; add `enrichOne` for realtime path.
- `mobile/packages/notification_repository/test/src/notification_repository_test.dart` — full rewrite for new model. Existing tests are deleted, not migrated.
- `mobile/lib/notifications/bloc/notification_feed_bloc.dart` — switch realtime handler to async enrichment + merge; switch tap/follow-back/mark-read pattern matches to new sealed types.
- `mobile/lib/notifications/bloc/notification_feed_event.dart` — `NotificationFeedRealtimeReceived` carries the raw `RelayNotification`, not a pre-built `NotificationItem`.
- `mobile/lib/notifications/widgets/notification_list_item.dart` — becomes a thin dispatcher that switches `VideoNotification | ActorNotification` and delegates to the two new row widgets. The internal `_SingleRow` and `_GroupedRow` classes are deleted.
- `mobile/lib/notifications/widgets/widgets.dart` — export the two new row widgets.
- `mobile/lib/notifications/view/notifications_view.dart` — `_navigateForSingle`/`_navigateForGrouped` collapse into `_navigateForVideo` (uses `videoEventId`) and `_navigateForActor`.
- `mobile/test/notifications/bloc/notification_feed_bloc_test.dart` — update fixtures + add realtime-enrichment tests.
- `mobile/test/notifications/widgets/notification_list_item_test.dart` — update fixtures.
- `mobile/test/notifications/view/notifications_view_test.dart` — update fixtures (if it exists; check first).

### Deleted files

None — only types and methods are removed inline.

---

## Decomposition decisions

- **One file per sealed leaf.** `video_notification.dart` and `actor_notification.dart` keep each subclass self-contained and let widget tests import only what they need. The base `NotificationItem` stays in `notification_item.dart`.
- **Repository's `enrichOne` is public.** The BLoC needs to enrich a single incoming raw event without re-fetching the whole page. Public method on the repository, mirrors `getNotifications` but for a single item.
- **Widget split.** `VideoNotificationRow` and `ActorNotificationRow` are separate files because they share almost no internal sub-widgets (thumbnail vs follow-back button, single avatar vs stack). The dispatcher (`NotificationListItem`) stays as the public entry point so callers don't change.
- **No backward-compatibility shim.** The sealed type change is breaking and contained; one PR replaces all callers.

---

## Conventions referenced

- @.claude/rules/architecture.md — UI → BLoC → Repository → Client, repository owns composition, constructor injection.
- @.claude/rules/state_management.md — BLoC error policy (status enum, `addError`, never store error strings in state).
- @.claude/rules/testing.md — `setUp` per group, private mocks (`_MockX`), descriptive test names with `$Type` interpolation, `bloc_test` for BLoC, golden tests tagged.
- @.claude/rules/ui_theming.md — `VineTheme.bodyMediumFont()` etc., page/view pattern unchanged.
- @.claude/rules/code_style.md — widgets-over-methods, `const` constructors, no hardcoded magic numbers (extract `_thumbnailSize`, `_maxStackActors`).
- @.claude/rules/performance.md — `VineCachedImage` for thumbnails with `memCacheWidth` constraint.
- @.claude/rules/accessibility.md — semantic labels on tappable thumbnail and avatar stack.

---

## Pre-flight

- [ ] **Step 0.1: Verify worktree and branch**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/fix-notifications-video-grouping
git status
git branch --show-current
```

Expected: clean tree, branch `fix/notifications-video-grouping`.

- [ ] **Step 0.2: Run baseline tests for the touched packages**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/fix-notifications-video-grouping/mobile
mise exec -- flutter test packages/models/test/src/notification_item_test.dart 2>/dev/null || echo "no model test file yet"
mise exec -- flutter test packages/notification_repository
mise exec -- flutter test test/notifications
```

Expected: all passing on the baseline. If any are failing on `main`, stop and report — do not proceed.

---

## Chunk 1: Model changes

### Task 1: Create `VideoNotification` model

**Files:**
- Create: `mobile/packages/models/lib/src/video_notification.dart`
- Create: `mobile/packages/models/test/src/video_notification_test.dart`

- [ ] **Step 1.1: Write failing test for `VideoNotification` equality, message, and copyWith**

```dart
// mobile/packages/models/test/src/video_notification_test.dart
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(VideoNotification, () {
    final actorAlice = const ActorInfo(
      pubkey: 'a' * 64,
      displayName: 'Alice',
      pictureUrl: null,
    );
    final actorBob = const ActorInfo(
      pubkey: 'b' * 64,
      displayName: 'Bob',
      pictureUrl: null,
    );
    final timestamp = DateTime.utc(2026, 5, 4, 12);

    group('message', () {
      test('reads "{actor} liked your video" when one actor and no title',
          () {
        final notification = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          videoThumbnailUrl: null,
          videoTitle: null,
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );

        expect(notification.message, equals('Alice liked your video'));
      });

      test('reads "{actor} and {N} others liked your video" when multiple',
          () {
        final notification = VideoNotification(
          id: 'n2',
          type: NotificationKind.like,
          videoEventId: 'v1',
          videoThumbnailUrl: null,
          videoTitle: null,
          actors: [actorAlice, actorBob],
          totalCount: 5,
          timestamp: timestamp,
        );

        expect(
          notification.message,
          equals('Alice and 4 others liked your video'),
        );
      });

      test('reads "{actor} commented on your video" for comment kind', () {
        final notification = VideoNotification(
          id: 'n3',
          type: NotificationKind.comment,
          videoEventId: 'v1',
          videoThumbnailUrl: null,
          videoTitle: null,
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );

        expect(notification.message, equals('Alice commented on your video'));
      });
    });

    group('equality', () {
      test('equal when all fields match', () {
        final a = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          videoThumbnailUrl: 'https://t/x.jpg',
          videoTitle: 'Hello',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );
        final b = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          videoThumbnailUrl: 'https://t/x.jpg',
          videoTitle: 'Hello',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );

        expect(a, equals(b));
      });
    });

    group('copyWith', () {
      test('overrides only specified fields', () {
        final original = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          videoThumbnailUrl: null,
          videoTitle: null,
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );

        final updated = original.copyWith(
          actors: [actorAlice, actorBob],
          totalCount: 2,
        );

        expect(updated.actors, hasLength(2));
        expect(updated.totalCount, equals(2));
        expect(updated.id, equals(original.id));
        expect(updated.timestamp, equals(original.timestamp));
      });
    });
  });
}
```

- [ ] **Step 1.2: Run test to verify it fails**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/fix-notifications-video-grouping/mobile
mise exec -- dart test packages/models/test/src/video_notification_test.dart
```

Expected: FAIL with `VideoNotification` not defined.

- [ ] **Step 1.3: Implement `VideoNotification`**

```dart
// mobile/packages/models/lib/src/video_notification.dart
import 'package:meta/meta.dart';
import 'package:models/src/actor_info.dart';
import 'package:models/src/notification_item.dart';

/// A notification anchored to a video — likes, comments, or reposts.
///
/// One row per (video × kind) regardless of how many actors interacted.
/// The list of [actors] is capped for stacked-avatar display; [totalCount]
/// holds the full count.
@immutable
class VideoNotification extends NotificationItem {
  /// Creates a [VideoNotification].
  const VideoNotification({
    required super.id,
    required super.type,
    required this.videoEventId,
    required this.actors,
    required this.totalCount,
    required super.timestamp,
    super.isRead,
    this.videoThumbnailUrl,
    this.videoTitle,
  })  : assert(
          type == NotificationKind.like ||
              type == NotificationKind.comment ||
              type == NotificationKind.repost,
          'VideoNotification only supports like, comment, repost',
        ),
        assert(actors.length > 0, 'must have at least one actor'),
        assert(totalCount >= actors.length, 'totalCount cannot be less'),
        super(targetEventId: videoEventId);

  /// The Nostr event id of the video that was acted on.
  final String videoEventId;

  /// Thumbnail URL of the referenced video, if available.
  final String? videoThumbnailUrl;

  /// Title of the referenced video, if available.
  final String? videoTitle;

  /// First N actors (newest-first) for stacked avatar display.
  final List<ActorInfo> actors;

  /// Total number of distinct actors who interacted (may exceed
  /// [actors.length]).
  final int totalCount;

  @override
  String get message {
    final firstName = actors.first.displayName;
    final othersCount = totalCount - 1;
    final verb = switch (type) {
      NotificationKind.like => 'liked',
      NotificationKind.repost => 'reposted',
      NotificationKind.comment => 'commented on',
      _ => 'acted on',
    };
    if (othersCount <= 0) {
      return '$firstName $verb your video';
    }
    final others = '$othersCount ${othersCount == 1 ? 'other' : 'others'}';
    return '$firstName and $others $verb your video';
  }

  /// Returns a copy with the given fields replaced.
  VideoNotification copyWith({
    String? id,
    NotificationKind? type,
    String? videoEventId,
    String? videoThumbnailUrl,
    String? videoTitle,
    List<ActorInfo>? actors,
    int? totalCount,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return VideoNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      videoEventId: videoEventId ?? this.videoEventId,
      videoThumbnailUrl: videoThumbnailUrl ?? this.videoThumbnailUrl,
      videoTitle: videoTitle ?? this.videoTitle,
      actors: actors ?? this.actors,
      totalCount: totalCount ?? this.totalCount,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        videoEventId,
        videoThumbnailUrl,
        videoTitle,
        actors,
        totalCount,
        timestamp,
        isRead,
      ];
}
```

- [ ] **Step 1.4: Wire export in `mobile/packages/models/lib/models.dart`**

Add: `export 'src/video_notification.dart';` immediately after the existing `notification_item.dart` export.

- [ ] **Step 1.5: Run test to verify it passes**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/fix-notifications-video-grouping/mobile
mise exec -- dart test packages/models/test/src/video_notification_test.dart
```

Expected: PASS, all assertions green.

- [ ] **Step 1.6: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/fix-notifications-video-grouping
git add mobile/packages/models/lib/src/video_notification.dart \
        mobile/packages/models/lib/models.dart \
        mobile/packages/models/test/src/video_notification_test.dart
git commit -m "feat(models): add VideoNotification for video-anchored notifications"
```

---

### Task 2: Create `ActorNotification` model

**Files:**
- Create: `mobile/packages/models/lib/src/actor_notification.dart`
- Create: `mobile/packages/models/test/src/actor_notification_test.dart`

- [ ] **Step 2.1: Write failing test**

```dart
// mobile/packages/models/test/src/actor_notification_test.dart
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(ActorNotification, () {
    const actor = ActorInfo(
      pubkey: 'a' * 64,
      displayName: 'Alice',
      pictureUrl: null,
    );
    final timestamp = DateTime.utc(2026, 5, 4, 12);

    group('message', () {
      test('reads "{actor} started following you" for follow', () {
        final notification = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
        );

        expect(
          notification.message,
          equals('Alice started following you'),
        );
      });

      test('reads "{actor} mentioned you" for mention', () {
        final notification = ActorNotification(
          id: 'n2',
          type: NotificationKind.mention,
          actor: actor,
          timestamp: timestamp,
        );

        expect(notification.message, equals('Alice mentioned you'));
      });

      test('reads "You have a new update" for system', () {
        final notification = ActorNotification(
          id: 'n3',
          type: NotificationKind.system,
          actor: actor,
          timestamp: timestamp,
        );

        expect(notification.message, equals('You have a new update'));
      });
    });

    group('copyWith', () {
      test('toggles isFollowingBack', () {
        final original = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
        );

        final updated = original.copyWith(isFollowingBack: true);

        expect(updated.isFollowingBack, isTrue);
        expect(original.isFollowingBack, isFalse);
      });
    });
  });
}
```

- [ ] **Step 2.2: Run test to verify it fails**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/fix-notifications-video-grouping/mobile
mise exec -- dart test packages/models/test/src/actor_notification_test.dart
```

Expected: FAIL with `ActorNotification` not defined.

- [ ] **Step 2.3: Implement `ActorNotification`**

```dart
// mobile/packages/models/lib/src/actor_notification.dart
import 'package:meta/meta.dart';
import 'package:models/src/actor_info.dart';
import 'package:models/src/notification_item.dart';

/// A notification anchored to an actor (follow, mention, system).
///
/// No video reference; one row per event.
@immutable
class ActorNotification extends NotificationItem {
  /// Creates an [ActorNotification].
  const ActorNotification({
    required super.id,
    required super.type,
    required this.actor,
    required super.timestamp,
    super.isRead,
    this.commentText,
    this.isFollowingBack = false,
  }) : assert(
          type == NotificationKind.follow ||
              type == NotificationKind.mention ||
              type == NotificationKind.system,
          'ActorNotification only supports follow, mention, system',
        );

  /// The actor who triggered this notification.
  final ActorInfo actor;

  /// Optional text body (e.g. mention's surrounding text).
  final String? commentText;

  /// Whether the current user already follows this actor back.
  final bool isFollowingBack;

  @override
  String get message {
    final name = actor.displayName;
    return switch (type) {
      NotificationKind.follow => '$name started following you',
      NotificationKind.mention => '$name mentioned you',
      NotificationKind.system => 'You have a new update',
      _ => name,
    };
  }

  /// Returns a copy with the given fields replaced.
  ActorNotification copyWith({
    String? id,
    NotificationKind? type,
    ActorInfo? actor,
    DateTime? timestamp,
    bool? isRead,
    String? commentText,
    bool? isFollowingBack,
  }) {
    return ActorNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      actor: actor ?? this.actor,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      commentText: commentText ?? this.commentText,
      isFollowingBack: isFollowingBack ?? this.isFollowingBack,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        actor,
        timestamp,
        isRead,
        commentText,
        isFollowingBack,
      ];
}
```

- [ ] **Step 2.4: Add export in `mobile/packages/models/lib/models.dart`**

Add: `export 'src/actor_notification.dart';`.

- [ ] **Step 2.5: Run test**

```bash
mise exec -- dart test packages/models/test/src/actor_notification_test.dart
```

Expected: PASS.

- [ ] **Step 2.6: Commit**

```bash
git add mobile/packages/models/lib/src/actor_notification.dart \
        mobile/packages/models/lib/models.dart \
        mobile/packages/models/test/src/actor_notification_test.dart
git commit -m "feat(models): add ActorNotification for actor-anchored notifications"
```

---

### Task 3: Reduce `NotificationItem` to sealed base only

**Files:**
- Modify: `mobile/packages/models/lib/src/notification_item.dart`

- [ ] **Step 3.1: Delete `SingleNotification` and `GroupedNotification` from the file**

Resulting file content:

```dart
// ABOUTME: Sealed notification domain model. Subtypes live in sibling
// ABOUTME: files video_notification.dart and actor_notification.dart.

import 'package:equatable/equatable.dart';

/// Notification kinds matching the Figma design spec.
enum NotificationKind {
  like,
  comment,
  reply,
  follow,
  repost,
  mention,
  system,
}

/// Base for all displayable notifications.
///
/// Sealed so the UI can exhaustively switch on subtypes:
/// [VideoNotification] (video-anchored: like/comment/repost) or
/// [ActorNotification] (actor-anchored: follow/mention/system).
sealed class NotificationItem extends Equatable {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.targetEventId,
  });

  final String id;
  final NotificationKind type;
  final DateTime timestamp;
  final bool isRead;
  final String? targetEventId;

  /// Human-readable message for the row.
  String get message;
}
```

- [ ] **Step 3.2: Run all model tests**

```bash
mise exec -- dart test packages/models/test
```

Expected: model tests pass; **other packages will not yet compile** because they import the deleted types — that's fine, we fix them in the next chunk.

- [ ] **Step 3.3: Commit**

```bash
git add mobile/packages/models/lib/src/notification_item.dart
git commit -m "refactor(models): reduce NotificationItem to sealed base; remove Single/Grouped"
```

> **Build is broken at this point until Chunk 2 ships.** That's intentional and expected — keep moving.

---

## Chunk 2: Repository changes

### Task 4: Add `_fetchVideoMetadata` helper

**Files:**
- Modify: `mobile/packages/notification_repository/lib/src/notification_repository.dart`
- Modify: `mobile/packages/notification_repository/test/src/notification_repository_test.dart` (rewrite, see Task 6)

- [ ] **Step 4.1: Add the helper method to `NotificationRepository`**

Insert immediately above the existing `_consolidateFollows` method:

```dart
/// Fetches [VideoStats] for each id in parallel.
///
/// Per-id failures are tolerated — a single failed lookup yields a
/// `null` entry that is dropped from the result map.
Future<Map<String, VideoStats>> _fetchVideoMetadata(
  List<String> eventIds,
) async {
  if (eventIds.isEmpty) return const <String, VideoStats>{};
  final futures = eventIds.map(
    (id) async {
      try {
        return await _funnelcakeApiClient.getVideoStats(id);
      } on Object {
        return null;
      }
    },
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

- [ ] **Step 4.2: Replace `_groupLikesByVideo` and the old singles map with new methods**

Replace the existing `_groupLikesByVideo` and the `singles` mapping inside `_enrichAndGroup` with:

```dart
/// Builds [VideoNotification]s by grouping like/comment/repost
/// notifications by (referencedEventId, kind).
///
/// Threshold is 1 — every video-anchored notification with a
/// non-null referencedEventId becomes a [VideoNotification], even if
/// only one actor interacted. Notifications missing referencedEventId
/// are dropped.
List<VideoNotification> _groupVideoAnchored(
  List<RelayNotification> raw,
  Map<String, UserProfile> profiles,
  Map<String, VideoStats> videosById,
) {
  bool isVideoAnchored(NotificationKind k) =>
      k == NotificationKind.like ||
      k == NotificationKind.comment ||
      k == NotificationKind.repost;

  final groups = <_VideoGroupKey, List<RelayNotification>>{};
  for (final n in raw) {
    final kind = _mapNotificationKind(n);
    if (!isVideoAnchored(kind)) continue;
    final eventId = n.referencedEventId;
    if (eventId == null || eventId.isEmpty) continue;
    final key = _VideoGroupKey(eventId, kind);
    (groups[key] ??= []).add(n);
  }

  final result = <VideoNotification>[];
  for (final entry in groups.entries) {
    final group = entry.value
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final actors = group
        .take(_maxGroupActors)
        .map((n) => _buildActor(n.sourcePubkey, profiles))
        .toList();
    final video = videosById[entry.key.eventId];
    result.add(
      VideoNotification(
        id: group.first.dedupeKey,
        type: entry.key.kind,
        videoEventId: entry.key.eventId,
        videoThumbnailUrl: _nonEmpty(video?.thumbnail),
        videoTitle: _nonEmpty(video?.title),
        actors: actors,
        totalCount: group.length,
        timestamp: group.first.createdAt,
        isRead: group.every((n) => n.read),
      ),
    );
  }
  return result;
}

/// Builds [ActorNotification]s for follow/mention/system kinds.
List<ActorNotification> _mapActorAnchored(
  List<RelayNotification> raw,
  Map<String, UserProfile> profiles,
) {
  bool isActorAnchored(NotificationKind k) =>
      k == NotificationKind.follow ||
      k == NotificationKind.mention ||
      k == NotificationKind.system ||
      k == NotificationKind.reply; // reply continues to render as actor row

  final result = <ActorNotification>[];
  for (final n in raw) {
    final kind = _mapNotificationKind(n);
    if (!isActorAnchored(kind)) continue;
    result.add(
      ActorNotification(
        id: n.dedupeKey,
        type: kind,
        actor: _buildActor(n.sourcePubkey, profiles),
        timestamp: n.createdAt,
        isRead: n.read,
        commentText: _truncateComment(n.content, kind),
      ),
    );
  }
  return result;
}

/// Returns null if [s] is null or empty, otherwise [s].
static String? _nonEmpty(String? s) =>
    (s == null || s.isEmpty) ? null : s;
```

Add the private group key class at the bottom of the file:

```dart
class _VideoGroupKey {
  const _VideoGroupKey(this.eventId, this.kind);
  final String eventId;
  final NotificationKind kind;

  @override
  bool operator ==(Object other) =>
      other is _VideoGroupKey &&
      other.eventId == eventId &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(eventId, kind);
}
```

- [ ] **Step 4.3: Update `_enrichAndGroup` to call both helpers**

```dart
Future<List<NotificationItem>> _enrichAndGroup(
  List<RelayNotification> raw,
) async {
  if (raw.isEmpty) return [];

  final pubkeys = raw.map((n) => n.sourcePubkey).toSet().toList();
  final eventIds = raw
      .map((n) => n.referencedEventId)
      .whereType<String>()
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  final profilesFuture = _profileRepository.fetchBatchProfiles(
    pubkeys: pubkeys,
  );
  final videosFuture = _fetchVideoMetadata(eventIds);
  final (profiles, videosById) = await (
    profilesFuture,
    videosFuture,
  ).wait;

  final consolidated = _consolidateFollows(raw);
  final videos = _groupVideoAnchored(consolidated, profiles, videosById);
  final actors = _mapActorAnchored(consolidated, profiles);

  final items = <NotificationItem>[...videos, ...actors]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return items;
}
```

Drop the old `singles` block and the old `_groupLikesByVideo` method entirely.

- [ ] **Step 4.4: Verify it compiles**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/fix-notifications-video-grouping/mobile
mise exec -- dart analyze packages/notification_repository
```

Expected: zero errors. Tests will fail until Task 6, which is fine.

- [ ] **Step 4.5: Commit**

```bash
git add mobile/packages/notification_repository/lib/src/notification_repository.dart
git commit -m "refactor(notifications): group video-anchored events by (videoId, kind), threshold 1"
```

---

### Task 5: Add `enrichOne` for realtime path

**Files:**
- Modify: `mobile/packages/notification_repository/lib/src/notification_repository.dart`

- [ ] **Step 5.1: Add public `enrichOne` method**

```dart
/// Enriches a single raw [RelayNotification] for realtime insertion.
///
/// Fetches the actor's profile and (if applicable) the referenced
/// video's stats in parallel. Returns null if the notification cannot
/// be turned into a [NotificationItem] (e.g. video-anchored type
/// missing a referenced event id).
Future<NotificationItem?> enrichOne(RelayNotification raw) async {
  final kind = _mapNotificationKind(raw);
  final profilesFuture = _profileRepository.fetchBatchProfiles(
    pubkeys: [raw.sourcePubkey],
  );
  final referenced = raw.referencedEventId;
  final videoFuture = (referenced != null && referenced.isNotEmpty)
      ? _fetchVideoMetadata([referenced])
      : Future.value(const <String, VideoStats>{});

  final (profiles, videosById) = await (
    profilesFuture,
    videoFuture,
  ).wait;

  final actor = _buildActor(raw.sourcePubkey, profiles);
  final isVideoAnchored = kind == NotificationKind.like ||
      kind == NotificationKind.comment ||
      kind == NotificationKind.repost;

  if (isVideoAnchored) {
    if (referenced == null || referenced.isEmpty) return null;
    final video = videosById[referenced];
    return VideoNotification(
      id: raw.dedupeKey,
      type: kind,
      videoEventId: referenced,
      videoThumbnailUrl: _nonEmpty(video?.thumbnail),
      videoTitle: _nonEmpty(video?.title),
      actors: [actor],
      totalCount: 1,
      timestamp: raw.createdAt,
      isRead: raw.read,
    );
  }

  return ActorNotification(
    id: raw.dedupeKey,
    type: kind,
    actor: actor,
    timestamp: raw.createdAt,
    isRead: raw.read,
    commentText: _truncateComment(raw.content, kind),
  );
}
```

- [ ] **Step 5.2: Verify analyze**

```bash
mise exec -- dart analyze packages/notification_repository
```

Expected: zero errors.

- [ ] **Step 5.3: Commit**

```bash
git add mobile/packages/notification_repository/lib/src/notification_repository.dart
git commit -m "feat(notifications): enrichOne for realtime push path"
```

---

### Task 6: Rewrite `notification_repository_test.dart`

**Files:**
- Modify: `mobile/packages/notification_repository/test/src/notification_repository_test.dart`

- [ ] **Step 6.1: Read the existing file to capture its mock setup pattern**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/fix-notifications-video-grouping
sed -n '1,80p' mobile/packages/notification_repository/test/src/notification_repository_test.dart
```

Note the mock classes (`_MockFunnelcakeApiClient`, `_MockProfileRepository`, etc.) and `setUp` block — keep the same mocks, only change the assertions.

- [ ] **Step 6.2: Replace existing tests for `getNotifications` with these scenarios**

Delete the old grouping tests and add (in the same file, same `group(NotificationRepository, () {...})` block):

```dart
group('getNotifications', () {
  test(
    'one like → VideoNotification with one actor and totalCount 1',
    () async {
      // Arrange: stub funnelcakeApiClient to return one reaction
      // notification + a getVideoStats hit.
      when(
        () => funnelcakeApiClient.getNotifications(...),
      ).thenAnswer((_) async => NotificationResponse(
            notifications: [_likeNotification(referencedEventId: 'v1')],
            unreadCount: 1,
            hasMore: false,
          ));
      when(
        () => funnelcakeApiClient.getVideoStats('v1'),
      ).thenAnswer((_) async => _videoStats(id: 'v1', thumbnail: 'thumb'));
      when(
        () => profileRepository.fetchBatchProfiles(pubkeys: any(named: 'pubkeys')),
      ).thenAnswer((_) async => {});

      final page = await repository.getNotifications();

      expect(page.items, hasLength(1));
      final item = page.items.single as VideoNotification;
      expect(item.actors, hasLength(1));
      expect(item.totalCount, equals(1));
      expect(item.videoThumbnailUrl, equals('thumb'));
    },
  );

  test(
    '5 likes on same video → one VideoNotification with totalCount 5',
    () async {
      // 5 distinct actors, same referencedEventId.
      // Assert: items.length == 1, totalCount == 5, actors capped at 3.
    },
  );

  test('5 likes on 5 different videos → 5 separate VideoNotifications',
      () async {});

  test(
    'likes + comments on same video → 2 VideoNotifications differing by kind',
    () async {},
  );

  test(
    'notification with null referencedEventId is dropped',
    () async {
      // Setup: one reaction notification with referencedEventId = null.
      // Assert: page.items is empty.
    },
  );

  test(
    'getVideoStats throws → row still rendered with null thumbnail',
    () async {
      when(
        () => funnelcakeApiClient.getVideoStats('v1'),
      ).thenThrow(const FunnelcakeException('boom'));

      // Assert: VideoNotification is still produced with
      // videoThumbnailUrl == null.
    },
  );

  test('follows are consolidated to one ActorNotification per actor',
      () async {});
});

group('enrichOne', () {
  test(
    'returns VideoNotification for like with non-null referencedEventId',
    () async {},
  );

  test(
    'returns null for like with null referencedEventId',
    () async {
      // Assert: result is null, no insertion.
    },
  );

  test(
    'returns ActorNotification for follow',
    () async {},
  );
});
```

(Fill in the bodies to match the pattern of the first test — mocks return what's needed, assertions cover the listed expectations.)

- [ ] **Step 6.3: Run repository tests**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/fix-notifications-video-grouping/mobile
mise exec -- flutter test packages/notification_repository
```

Expected: PASS, all green.

- [ ] **Step 6.4: Commit**

```bash
git add mobile/packages/notification_repository/test/src/notification_repository_test.dart
git commit -m "test(notifications): cover video-anchored grouping and enrichOne"
```

---

## Chunk 3: BLoC changes

### Task 7: Update event signature for realtime

**Files:**
- Modify: `mobile/lib/notifications/bloc/notification_feed_event.dart`

- [ ] **Step 7.1: Change `NotificationFeedRealtimeReceived` to carry the raw event**

```dart
class NotificationFeedRealtimeReceived extends NotificationFeedEvent {
  const NotificationFeedRealtimeReceived(this.raw);
  final RelayNotification raw;

  @override
  List<Object?> get props => [raw];
}
```

Add the import for `RelayNotification` at the top of the file if not already present.

- [ ] **Step 7.2: Verify analyze**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/fix-notifications-video-grouping/mobile
mise exec -- dart analyze lib/notifications
```

Expected: errors limited to BLoC handler call sites (we fix those next).

- [ ] **Step 7.3: Commit (alongside Task 8 — these are inseparable)**

Skip commit here; we'll commit after Task 8.

---

### Task 8: Update BLoC handlers

**Files:**
- Modify: `mobile/lib/notifications/bloc/notification_feed_bloc.dart`

- [ ] **Step 8.1: Replace `_onItemTapped` pattern match**

```dart
Future<void> _onItemTapped(
  NotificationFeedItemTapped event,
  Emitter<NotificationFeedState> emit,
) async {
  final updated = state.notifications.map((n) {
    if (n.id != event.notificationId || n.isRead) return n;
    return switch (n) {
      VideoNotification() => n.copyWith(isRead: true),
      ActorNotification() => n.copyWith(isRead: true),
    };
  }).toList();

  // ... unchanged
}
```

- [ ] **Step 8.2: Replace `_onFollowBack` actor match**

```dart
Future<void> _onFollowBack(
  NotificationFeedFollowBack event,
  Emitter<NotificationFeedState> emit,
) async {
  try {
    await _followRepository.follow(event.pubkey);
    final updated = state.notifications.map((n) {
      if (n is ActorNotification &&
          n.type == NotificationKind.follow &&
          n.actor.pubkey == event.pubkey) {
        return n.copyWith(isFollowingBack: true);
      }
      return n;
    }).toList();
    emit(state.copyWith(notifications: updated));
  } catch (e, s) {
    addError(e, s);
  }
}
```

- [ ] **Step 8.3: Rewrite `_onRealtimeReceived` to enrich + merge**

```dart
Future<void> _onRealtimeReceived(
  NotificationFeedRealtimeReceived event,
  Emitter<NotificationFeedState> emit,
) async {
  final enriched = await _notificationRepository.enrichOne(event.raw);
  if (enriched == null) return;

  // Already shown? skip.
  final exists = state.notifications.any((n) => n.id == enriched.id);
  if (exists) return;

  // Try to merge into an existing matching VideoNotification group.
  if (enriched is VideoNotification) {
    final mergedList = <NotificationItem>[];
    var merged = false;
    for (final existing in state.notifications) {
      if (!merged &&
          existing is VideoNotification &&
          existing.videoEventId == enriched.videoEventId &&
          existing.type == enriched.type) {
        // Merge: prepend the new actor (newest-first) and bump count.
        final mergedActors = [
          enriched.actors.first,
          ...existing.actors,
        ].take(3).toList();
        mergedList.add(
          existing.copyWith(
            actors: mergedActors,
            totalCount: existing.totalCount + 1,
            isRead: false,
            timestamp: enriched.timestamp,
          ),
        );
        merged = true;
      } else {
        mergedList.add(existing);
      }
    }
    if (merged) {
      emit(
        state.copyWith(
          notifications: mergedList,
          unreadCount: state.unreadCount + 1,
        ),
      );
      return;
    }
  }

  emit(
    state.copyWith(
      notifications: [enriched, ...state.notifications],
      unreadCount: state.unreadCount + 1,
    ),
  );
}
```

Make sure the registration uses `sequential()` so concurrent realtime events don't race:

```dart
on<NotificationFeedRealtimeReceived>(
  _onRealtimeReceived,
  transformer: sequential(),
);
```

- [ ] **Step 8.4: Verify analyze**

```bash
mise exec -- dart analyze lib/notifications
```

Expected: only widget-side errors remain.

- [ ] **Step 8.5: Commit**

```bash
git add mobile/lib/notifications/bloc/notification_feed_event.dart \
        mobile/lib/notifications/bloc/notification_feed_bloc.dart
git commit -m "refactor(notifications): BLoC realtime path enriches before emit; merges into video groups"
```

---

### Task 9: Update BLoC tests

**Files:**
- Modify: `mobile/test/notifications/bloc/notification_feed_bloc_test.dart`

- [ ] **Step 9.1: Update existing tests to use the new model types**

Replace `SingleNotification(...)` and `GroupedNotification(...)` fixtures with `ActorNotification(...)` and `VideoNotification(...)`.

- [ ] **Step 9.2: Add new tests for realtime enrichment**

```dart
group('NotificationFeedRealtimeReceived', () {
  blocTest<NotificationFeedBloc, NotificationFeedState>(
    'inserts enriched VideoNotification at top when no matching group',
    build: () {
      when(
        () => notificationRepository.enrichOne(any()),
      ).thenAnswer((_) async => _videoNotification(id: 'new'));
      return NotificationFeedBloc(
        notificationRepository: notificationRepository,
        followRepository: followRepository,
      );
    },
    seed: () => const NotificationFeedState(
      status: NotificationFeedStatus.loaded,
      notifications: [],
      unreadCount: 0,
    ),
    act: (bloc) =>
        bloc.add(NotificationFeedRealtimeReceived(_rawNotification())),
    expect: () => [
      isA<NotificationFeedState>().having(
        (s) => s.notifications.first.id,
        'first.id',
        'new',
      ),
    ],
  );

  blocTest<NotificationFeedBloc, NotificationFeedState>(
    'merges actor into existing matching VideoNotification group',
    // ... arrange seed with one VideoNotification, raw event with same
    // referencedEventId → expect merged actors length 2, totalCount 2.
  );

  blocTest<NotificationFeedBloc, NotificationFeedState>(
    'does NOT emit when enrichOne returns null',
    build: () {
      when(
        () => notificationRepository.enrichOne(any()),
      ).thenAnswer((_) async => null);
      return /* bloc */;
    },
    act: (bloc) =>
        bloc.add(NotificationFeedRealtimeReceived(_rawNotification())),
    expect: () => <NotificationFeedState>[],
  );
});
```

- [ ] **Step 9.3: Run BLoC tests**

```bash
mise exec -- flutter test test/notifications/bloc
```

Expected: PASS.

- [ ] **Step 9.4: Commit**

```bash
git add mobile/test/notifications/bloc/notification_feed_bloc_test.dart
git commit -m "test(notifications): cover realtime enrichment + group merge"
```

---

## Chunk 4: Widget changes

### Task 10: Build `VideoNotificationRow` widget

**Files:**
- Create: `mobile/lib/notifications/widgets/video_notification_row.dart`
- Create: `mobile/test/notifications/widgets/video_notification_row_test.dart`

- [ ] **Step 10.1: Write failing test**

```dart
// mobile/test/notifications/widgets/video_notification_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/notifications/widgets/video_notification_row.dart';

void main() {
  group(VideoNotificationRow, () {
    final timestamp = DateTime.now();

    testWidgets(
      'renders actor name, message, and thumbnail when single actor',
      (tester) async {
        final notification = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          videoThumbnailUrl: 'https://t/x.jpg',
          videoTitle: 'Title',
          actors: const [
            ActorInfo(
              pubkey: 'a' * 64,
              displayName: 'Alice',
              pictureUrl: null,
            ),
          ],
          totalCount: 1,
          timestamp: timestamp,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VideoNotificationRow(
                notification: notification,
                onTap: () {},
                onProfileTap: () {},
                onThumbnailTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('Alice liked your video'), findsOneWidget);
        expect(find.byKey(const Key('video_notification_thumbnail')),
            findsOneWidget);
      },
    );

    testWidgets(
      'renders "{first} and N others" when multi-actor',
      (tester) async {
        final notification = VideoNotification(
          id: 'n2',
          type: NotificationKind.like,
          videoEventId: 'v1',
          actors: const [
            ActorInfo(pubkey: 'a' * 64, displayName: 'Alice'),
            ActorInfo(pubkey: 'b' * 64, displayName: 'Bob'),
            ActorInfo(pubkey: 'c' * 64, displayName: 'Carol'),
          ],
          totalCount: 50,
          timestamp: timestamp,
        );

        await tester.pumpWidget(/* ... */);

        expect(
          find.text('Alice and 49 others liked your video'),
          findsOneWidget,
        );
      },
    );

    testWidgets('tap on row fires onTap', (tester) async {
      var tapped = false;
      // Pump widget with onTap = () => tapped = true.
      await tester.tap(find.byType(VideoNotificationRow));
      expect(tapped, isTrue);
    });

    testWidgets('tap on thumbnail fires onThumbnailTap', (tester) async {
      // ...
    });

    testWidgets('tap on avatar stack fires onProfileTap', (tester) async {
      // ...
    });
  });
}
```

- [ ] **Step 10.2: Run test (fails — widget doesn't exist)**

```bash
mise exec -- flutter test test/notifications/widgets/video_notification_row_test.dart
```

Expected: FAIL.

- [ ] **Step 10.3: Implement widget**

```dart
// mobile/lib/notifications/widgets/video_notification_row.dart
// ABOUTME: One-row layout for VideoNotification — avatar stack on the
// ABOUTME: left, message + timestamp in the middle, thumbnail on right.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/notifications/widgets/notification_avatar_stack.dart';
import 'package:time_formatter/time_formatter.dart';

const double _thumbnailSize = 56;
const double _avatarSize = 48;

/// Displays a single video-anchored notification row.
class VideoNotificationRow extends StatelessWidget {
  /// Creates a [VideoNotificationRow].
  const VideoNotificationRow({
    required this.notification,
    required this.onTap,
    required this.onProfileTap,
    required this.onThumbnailTap,
    super.key,
  });

  final VideoNotification notification;
  final VoidCallback onTap;
  final VoidCallback onProfileTap;
  final VoidCallback onThumbnailTap;

  @override
  Widget build(BuildContext context) {
    final overflowCount =
        notification.totalCount - notification.actors.length;
    return Material(
      color: notification.isRead
          ? VineTheme.backgroundColor
          : VineTheme.cardBackground,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onProfileTap,
                child: NotificationAvatarStack(
                  actors: notification.actors,
                  overflowCount: overflowCount > 0 ? overflowCount : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.message,
                      style: VineTheme.bodyMediumFont(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      TimeFormatter.formatRelativeVerbose(
                        notification.timestamp.millisecondsSinceEpoch ~/
                            1000,
                      ),
                      style: VineTheme.bodySmallFont(
                        color: VineTheme.lightText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Thumbnail(
                key: const Key('video_notification_thumbnail'),
                imageUrl: notification.videoThumbnailUrl,
                title: notification.videoTitle,
                onTap: onThumbnailTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.imageUrl,
    required this.title,
    required this.onTap,
    super.key,
  });

  final String? imageUrl;
  final String? title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title != null
          ? 'Video thumbnail for $title'
          : 'Video thumbnail',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: _thumbnailSize,
            height: _thumbnailSize,
            child: imageUrl != null
                ? VineCachedImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                  )
                : const ColoredBox(color: VineTheme.cardBackground),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 10.4: Run test, fix until passing**

```bash
mise exec -- flutter test test/notifications/widgets/video_notification_row_test.dart
```

Expected: PASS.

- [ ] **Step 10.5: Commit**

```bash
git add mobile/lib/notifications/widgets/video_notification_row.dart \
        mobile/test/notifications/widgets/video_notification_row_test.dart
git commit -m "feat(notifications): video notification row with thumbnail"
```

---

### Task 11: Build `ActorNotificationRow` widget

**Files:**
- Create: `mobile/lib/notifications/widgets/actor_notification_row.dart`
- Create: `mobile/test/notifications/widgets/actor_notification_row_test.dart`

- [ ] **Step 11.1: Write failing test**

Same pattern as Task 10 — render a follow `ActorNotification`, assert avatar + name + "started following you" + Follow back button when `!isFollowingBack`.

- [ ] **Step 11.2: Run, see fail**

- [ ] **Step 11.3: Implement widget**

Take the existing `_SingleRow` from `notification_list_item.dart` (the version that draws avatar + type icon + Follow back) as the starting layout, but make it accept `ActorNotification` instead of `SingleNotification`.

- [ ] **Step 11.4: Run test, pass**

- [ ] **Step 11.5: Commit**

```bash
git commit -m "feat(notifications): actor notification row (follow/mention/system)"
```

---

### Task 12: Replace `NotificationListItem` dispatcher

**Files:**
- Modify: `mobile/lib/notifications/widgets/notification_list_item.dart`
- Modify: `mobile/lib/notifications/widgets/widgets.dart`
- Modify: `mobile/test/notifications/widgets/notification_list_item_test.dart`

- [ ] **Step 12.1: Replace file content with thin dispatcher**

```dart
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/notifications/widgets/actor_notification_row.dart';
import 'package:openvine/notifications/widgets/video_notification_row.dart';

class NotificationListItem extends StatelessWidget {
  const NotificationListItem({
    required this.notification,
    required this.onTap,
    this.onProfileTap,
    this.onFollowBack,
    this.onThumbnailTap,
    super.key,
  });

  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onFollowBack;
  final VoidCallback? onThumbnailTap;

  @override
  Widget build(BuildContext context) {
    return switch (notification) {
      VideoNotification() => VideoNotificationRow(
          notification: notification as VideoNotification,
          onTap: onTap,
          onProfileTap: onProfileTap ?? () {},
          onThumbnailTap: onThumbnailTap ?? onTap,
        ),
      ActorNotification() => ActorNotificationRow(
          notification: notification as ActorNotification,
          onTap: onTap,
          onProfileTap: onProfileTap ?? () {},
          onFollowBack: onFollowBack,
        ),
    };
  }
}
```

Delete the old `_SingleRow`, `_GroupedRow`, and helper sub-widgets — they live in the row files now.

- [ ] **Step 12.2: Add exports in `widgets.dart`**

```dart
export 'actor_notification_row.dart';
export 'notification_avatar_stack.dart';
export 'notification_empty_state.dart';
export 'notification_list_item.dart';
export 'video_notification_row.dart';
```

- [ ] **Step 12.3: Update `notification_list_item_test.dart` fixtures**

Replace `SingleNotification(...)` and `GroupedNotification(...)` with the new types; assert `find.byType(VideoNotificationRow)` / `find.byType(ActorNotificationRow)`.

- [ ] **Step 12.4: Run all notification widget tests**

```bash
mise exec -- flutter test test/notifications/widgets
```

Expected: PASS.

- [ ] **Step 12.5: Commit**

```bash
git add mobile/lib/notifications/widgets/notification_list_item.dart \
        mobile/lib/notifications/widgets/widgets.dart \
        mobile/test/notifications/widgets/notification_list_item_test.dart
git commit -m "refactor(notifications): dispatcher delegates to video/actor row widgets"
```

---

### Task 13: Update `notifications_view.dart`

**Files:**
- Modify: `mobile/lib/notifications/view/notifications_view.dart`

- [ ] **Step 13.1: Collapse `_navigateForSingle`/`_navigateForGrouped` into two new methods**

```dart
Future<void> _onItemTap(
  BuildContext context,
  NotificationItem notification,
) async {
  context.read<NotificationFeedBloc>().add(
        NotificationFeedItemTapped(notification.id),
      );

  switch (notification) {
    case VideoNotification(:final videoEventId, :final type):
      await _navigateToVideo(context, videoEventId, notificationKind: type);
    case ActorNotification(:final actor, :final type):
      switch (type) {
        case NotificationKind.follow:
          _navigateToProfile(context, actor.pubkey);
        case NotificationKind.mention:
          // Mentions reuse the existing target-resolver path if there's
          // a target event id; otherwise fall back to actor profile.
          _navigateToProfile(context, actor.pubkey);
        case NotificationKind.system:
          break;
        // Other kinds aren't represented in ActorNotification.
        case _:
          break;
      }
  }
}
```

Drop `_navigateForSingle` and `_navigateForGrouped`.

- [ ] **Step 13.2: Update `_NotificationList._profilePubkey` for the new types**

```dart
String? _profilePubkey(NotificationItem notification) {
  return switch (notification) {
    VideoNotification(:final actors) =>
      actors.isNotEmpty ? actors.first.pubkey : null,
    ActorNotification(:final actor) => actor.pubkey,
  };
}
```

- [ ] **Step 13.3: Run analyze + view tests**

```bash
mise exec -- dart analyze lib/notifications
mise exec -- flutter test test/notifications/view 2>/dev/null || echo "no view test"
```

Expected: zero analyzer errors.

- [ ] **Step 13.4: Commit**

```bash
git add mobile/lib/notifications/view/notifications_view.dart
git commit -m "refactor(notifications): view tap handler dispatches on new sealed types"
```

---

## Chunk 5: Verification

### Task 14: Full test sweep

- [ ] **Step 14.1: Models package**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/fix-notifications-video-grouping/mobile
mise exec -- flutter test packages/models
```

- [ ] **Step 14.2: Notification repository package**

```bash
mise exec -- flutter test packages/notification_repository
```

- [ ] **Step 14.3: Notifications app tests**

```bash
mise exec -- flutter test test/notifications
```

- [ ] **Step 14.4: Whole-app analyze**

```bash
mise exec -- flutter analyze lib test integration_test
```

Expected: zero issues.

- [ ] **Step 14.5: Format check**

```bash
mise exec -- dart format --output=none --set-exit-if-changed lib packages
```

Expected: zero diff.

### Task 15: Manual smoke

- [ ] **Step 15.1: Run app against staging or local**

```bash
cd /Users/rabble/code/divine/divine-mobile/.worktrees/fix-notifications-video-grouping/mobile
mise exec -- flutter run
```

Navigate to the notifications tab. Verify:
- Each like/comment/repost row shows a thumbnail on the right (or empty placeholder for missing video metadata).
- Multiple actors on the same video collapse into one row with a stacked avatar.
- A single actor still shows a thumbnail.
- Tapping a row navigates to the video.
- Tapping the avatar stack navigates to the first actor's profile.

If push notifications are reachable in your build, send a test push to the logged-in user and verify the row arrives with the actor name populated (no nameless flicker).

### Task 16: Open PR

- [ ] **Step 16.1: Push branch**

```bash
git push -u origin fix/notifications-video-grouping
```

- [ ] **Step 16.2: Open PR**

```bash
gh pr create --title "fix(notifications): group by video, show thumbnails, fix realtime flicker" \
  --body "$(cat <<'EOF'
## Summary

- Replaces the count-based `Single`/`Grouped` notification split with a context-based `VideoNotification`/`ActorNotification` split. One row per (video × kind) regardless of actor count.
- Adds video thumbnails to every video-anchored row. Repository fetches `getVideoStats` for each distinct `referenced_event_id` in parallel with the profile batch.
- Fixes realtime push flicker: `NotificationFeedBloc._onRealtimeReceived` enriches the incoming raw event before emitting, and merges into existing matching video groups instead of inserting orphan rows.

Closes #3151 (count/sync user complaint). Spec: `docs/superpowers/specs/2026-05-04-notifications-video-grouping-thumbnails-design.md`.

## Test plan
- [ ] `flutter test packages/models packages/notification_repository test/notifications`
- [ ] `flutter analyze lib test integration_test`
- [ ] Manual: notifications tab on staging shows thumbnails on like/comment/repost rows
- [ ] Manual: multiple likes on the same video appear as a single row with a stacked avatar
- [ ] Manual: realtime push from another account lands with the actor name populated (no flicker)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Done.
