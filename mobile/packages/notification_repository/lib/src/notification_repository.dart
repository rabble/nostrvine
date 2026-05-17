// ABOUTME: Repository that fetches raw notifications from FunnelCake,
// ABOUTME: enriches them with profile + video metadata, groups video-anchored
// ABOUTME: notifications by (referencedEventId, kind), and maps actor-anchored
// ABOUTME: notifications.

import 'dart:developer' as developer;

import 'package:db_client/db_client.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:notification_repository/src/blocked_notification_filter.dart';
import 'package:notification_repository/src/notification_page.dart';
import 'package:profile_repository/profile_repository.dart';
// Hide rxdart's `NotificationKind` (a stream-event enum) to avoid clashing
// with the domain `NotificationKind` from `models`.
import 'package:rxdart/rxdart.dart' hide NotificationKind;
import 'package:text_sanitizer/text_sanitizer.dart';

/// Maximum length for comment preview text before truncation.
const _maxCommentLength = 50;

/// Maximum number of actor avatars shown in a grouped notification.
const _maxGroupActors = 3;

final RegExp _hexIdentifierPattern = RegExp(r'^[0-9a-fA-F]{32,}$');
final RegExp _npubIdentifierPattern = RegExp(
  r'^npub1[023456789acdefghjklmnpqrstuvwxyz]+$',
  caseSensitive: false,
);

/// Repository for fetching, enriching, grouping, and managing
/// notifications.
///
/// Responsibilities:
/// 1. Fetch raw notifications via [FunnelcakeApiClient.getNotifications]
/// 2. Batch-fetch profiles via [ProfileRepository.fetchBatchProfiles]
/// 3. Fetch per-video metadata via [FunnelcakeApiClient.getVideoStats]
/// 4. Group like/comment/repost by `(referencedEventId, kind)` into
///    [VideoNotification]s — threshold 1
/// 5. Map follow/mention/system into [ActorNotification]s
/// 6. Consolidate follow duplicates (keep earliest per source pubkey)
/// 7. Truncate long comment text
class NotificationRepository {
  /// Creates a [NotificationRepository].
  NotificationRepository({
    required FunnelcakeApiClient funnelcakeApiClient,
    required ProfileRepository profileRepository,
    required NotificationsDao notificationsDao,
    required String userPubkey,
    BlockedNotificationFilter? blockFilter,
    Future<Map<String, String>> Function(String url, String method)?
    authHeadersProvider,
  }) : _funnelcakeApiClient = funnelcakeApiClient,
       _profileRepository = profileRepository,
       _notificationsDao = notificationsDao,
       _userPubkey = userPubkey,
       _blockFilter = blockFilter,
       _authHeadersProvider = authHeadersProvider;

  final FunnelcakeApiClient _funnelcakeApiClient;
  final ProfileRepository _profileRepository;
  final NotificationsDao _notificationsDao;
  final String _userPubkey;
  final BlockedNotificationFilter? _blockFilter;
  final Future<Map<String, String>> Function(String url, String method)?
  _authHeadersProvider;

  /// Last cursor returned by the API, used for pagination.
  String? _lastCursor;
  String? _lastCursorId;

  /// Reactive snapshot of the enriched, grouped notification feed.
  ///
  /// Single source of truth for the feed bloc (list rendering) and the
  /// badge cubit (badge count). Every mutation — [getNotifications],
  /// [refresh], [markAsRead], [markAllAsRead], [acceptRealtime] —
  /// updates this subject so consumers can never diverge.
  final BehaviorSubject<NotificationPage> _snapshot =
      BehaviorSubject<NotificationPage>.seeded(NotificationPage.empty);

  /// Stream of the latest [NotificationPage] snapshot.
  ///
  /// Use this for screen-level rendering. For badge counts, prefer
  /// [watchUnreadCount] — it is `.distinct()`-filtered so the badge
  /// only rebuilds on actual count changes.
  Stream<NotificationPage> watchSnapshot() => _snapshot.stream;

  /// Stream of the unread badge count derived from the consolidated
  /// visible list.
  ///
  /// Counts items in [NotificationPage.items] where `isRead == false`
  /// rather than using the server's `unreadCount` directly. The server
  /// reports one row per Kind 3 republish per follower (tracked at
  /// funnelcake#234); this method matches the same post-consolidation
  /// derivation that `NotificationFeedState.unreadBadgeCount` documents.
  Stream<int> watchUnreadCount() => _snapshot.stream
      .map((page) => page.items.where((n) => !n.isRead).length)
      .distinct();

  /// Disposes the internal snapshot subject.
  ///
  /// Called when the repository is no longer needed (e.g. on auth flip
  /// when a new repository instance replaces this one).
  Future<void> close() => _snapshot.close();

  /// Fetches the next page of notifications.
  ///
  /// Pass [cursor] to override the stored pagination cursor. On success,
  /// merges the new items into the snapshot — the first page replaces
  /// the snapshot's items, subsequent pages append.
  ///
  /// Rethrows any [Exception] (typically a [FunnelcakeException] subtype)
  /// after structured logging, so callers can drive a failure UI. The
  /// snapshot is left at its prior value on throw — the [BehaviorSubject]
  /// preserves it for downstream consumers.
  Future<NotificationPage> getNotifications({
    String? cursor,
    String? cursorId,
  }) async {
    try {
      final effectiveCursor = cursor ?? _lastCursor;
      final effectiveCursorId = cursor != null
          ? cursorId
          : cursorId ?? _lastCursorId;
      final requestUrl = _funnelcakeApiClient
          .notificationsUri(
            pubkey: _userPubkey,
            cursor: effectiveCursor,
            cursorId: effectiveCursorId,
          )
          .toString();

      final authHeaders = _authHeadersProvider != null
          ? await _authHeadersProvider(requestUrl, 'GET')
          : <String, String>{};

      final response = await _funnelcakeApiClient.getNotifications(
        pubkey: _userPubkey,
        cursor: effectiveCursor,
        cursorId: effectiveCursorId,
        requestUri: Uri.parse(requestUrl),
        authHeaders: authHeaders,
      );

      _lastCursor = response.nextCursor;
      _lastCursorId = response.nextCursorId;

      final items = await _enrichAndGroup(response.notifications);

      final page = NotificationPage(
        items: items,
        unreadCount: response.unreadCount,
        nextCursor: response.nextCursor,
        nextCursorId: response.nextCursorId,
        hasMore: response.hasMore,
      );
      _emitSnapshotForPage(page, isFirstPage: effectiveCursor == null);
      return page;
    } on Exception catch (e, s) {
      developer.log(
        'Failed to fetch notifications: $e',
        name: 'NotificationRepository.getNotifications',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  /// Refreshes notifications from the beginning (no cursor).
  Future<NotificationPage> refresh() {
    _lastCursor = null;
    _lastCursorId = null;
    return getNotifications();
  }

  /// Marks specific notifications as read on the server and locally.
  ///
  /// Optimistically flips matching items in the snapshot to `isRead:
  /// true`, then writes through to the API and the local DAO. On
  /// failure, restores the pre-write snapshot so subscribers see the
  /// authoritative state, and rethrows so callers can surface the
  /// error.
  Future<void> markAsRead(List<String> ids) async {
    if (ids.isEmpty) return;

    final idSet = ids.toSet();
    final before = _snapshot.value;
    _snapshot.add(before.copyWith(items: _flipIsRead(before.items, idSet)));

    try {
      final authHeaders = _authHeadersProvider != null
          ? await _authHeadersProvider(
              '/api/users/$_userPubkey/notifications/read',
              'POST',
            )
          : <String, String>{};

      await _funnelcakeApiClient.markNotificationsRead(
        pubkey: _userPubkey,
        notificationIds: ids,
        authHeaders: authHeaders,
      );

      for (final id in ids) {
        await _notificationsDao.markAsRead(id);
      }
    } catch (_) {
      _snapshot.add(before);
      rethrow;
    }
  }

  /// Marks all notifications as read on the server and locally.
  ///
  /// Optimistically flips every item in the snapshot to `isRead: true`,
  /// then writes through to the API and the local DAO. On failure,
  /// restores the pre-write snapshot — preserves the rollback semantics
  /// introduced by PR #4034 at the repository layer so every consumer
  /// (badge cubit, feed bloc) recovers consistently.
  Future<void> markAllAsRead() async {
    final before = _snapshot.value;
    if (before.items.every((n) => n.isRead)) return;

    _snapshot.add(before.copyWith(items: _flipAllRead(before.items)));

    try {
      final authHeaders = _authHeadersProvider != null
          ? await _authHeadersProvider(
              '/api/users/$_userPubkey/notifications/read',
              'POST',
            )
          : <String, String>{};

      await _funnelcakeApiClient.markNotificationsRead(
        pubkey: _userPubkey,
        authHeaders: authHeaders,
      );

      await _notificationsDao.markAllAsRead();
    } catch (_) {
      _snapshot.add(before);
      rethrow;
    }
  }

  /// Accepts a real-time WebSocket notification and merges it into the
  /// snapshot.
  ///
  /// Enriches the raw relay event via [_enrichAndGroup], applies the
  /// block filter, deduplicates by `id`, and then either:
  ///
  /// * merges into an existing matching [VideoNotification] group (same
  ///   `videoEventId` + `type`) by prepending the new actor, incrementing
  ///   `totalCount`, flipping `isRead` back to false, and bumping
  ///   `timestamp` — the merged row stays at its existing position; or
  /// * prepends the new item when no matching group exists.
  ///
  /// The merge step preserves the pre-snapshot bloc-layer behavior
  /// (deleted in `ead8114f8`) so a second realtime like/comment/repost on
  /// a video that already has a grouped row updates the existing row's
  /// count rather than creating a duplicate.
  ///
  /// Replaces the legacy
  /// `mobile/lib/providers/notification_realtime_bridge_provider.dart`
  /// which wrote into the now-unused Riverpod cache.
  Future<void> acceptRealtime(RelayNotification raw) async {
    if (_snapshotContainsSourceEventId(raw.id)) return;

    final enriched = await _enrichAndGroup([raw]);
    if (enriched.isEmpty) return;

    final current = _snapshot.value;
    // Re-check against the post-await snapshot so concurrent refresh/page
    // updates can neither be clobbered nor bypass the cross-path dedupe.
    if (_snapshotContainsSourceEventId(raw.id)) return;

    final newItem = enriched.first;
    // Final by-id dedupe gate (the deliberate WS → WS guard). The
    // `_snapshotContainsSourceEventId` checks above match on the
    // snapshot's `sourceEventIds` set; this catches the residual
    // same-id arrival whose `id` isn't represented in any existing
    // row's `sourceEventIds`. Preserves the original by-id contract.
    if (current.items.any((n) => n.id == newItem.id)) return;

    if (newItem is VideoNotification) {
      final merged = _mergeIntoExistingVideoGroup(current.items, newItem);
      if (merged != null) {
        _snapshot.add(current.copyWith(items: merged));
        return;
      }
    }

    _snapshot.add(current.copyWith(items: [newItem, ...current.items]));
  }

  bool _snapshotContainsSourceEventId(String sourceEventId) {
    if (sourceEventId.isEmpty) return false;
    return _snapshot.value.items.any(
      (n) => n.sourceEventIds.contains(sourceEventId),
    );
  }

  /// If [items] contains a [VideoNotification] matching [incoming] by
  /// `videoEventId` and `type`, returns a new list with that row replaced
  /// by the merged group; otherwise returns null.
  ///
  /// Merge semantics (mirror the pre-snapshot bloc handler): add the
  /// incoming actor, reapply the grouped-row actor ordering, increment
  /// `totalCount`, flip `isRead` to false, bump `timestamp` to the
  /// incoming arrival, and union the underlying `sourceEventIds` so the
  /// merged row carries every Nostr event it represents. The row stays
  /// at its existing index — no re-sort, so the visible list doesn't
  /// jump.
  static List<NotificationItem>? _mergeIntoExistingVideoGroup(
    List<NotificationItem> items,
    VideoNotification incoming,
  ) {
    final result = <NotificationItem>[];
    var merged = false;
    for (final existing in items) {
      if (!merged &&
          existing is VideoNotification &&
          existing.videoEventId == incoming.videoEventId &&
          existing.type == incoming.type) {
        final incomingActor = incoming.actors.first;
        final mergedActors = _orderVideoGroupActors([
          incomingActor,
          ...existing.actors.where((a) => a.pubkey != incomingActor.pubkey),
        ]).take(_maxGroupActors).toList();
        final mergedSourceEventIds = <String>{
          ...existing.sourceEventIds,
          ...incoming.sourceEventIds,
        }.toList();
        result.add(
          existing.copyWith(
            actors: mergedActors,
            totalCount: existing.totalCount + 1,
            isRead: false,
            timestamp: incoming.timestamp,
            sourceEventIds: mergedSourceEventIds,
          ),
        );
        merged = true;
      } else {
        result.add(existing);
      }
    }
    return merged ? result : null;
  }

  /// Updates [_snapshot] with [page]'s contents.
  ///
  /// First-page emissions replace the items list (used by [refresh] and
  /// the initial [getNotifications] call) — the REST first page is the
  /// authoritative ground truth, so a full replace is correct.
  ///
  /// Subsequent pages merge incoming items into the existing snapshot
  /// using three gates:
  ///
  /// 1. **`(videoEventId, type)` overlap (VideoNotification only)** —
  ///    when an incoming group matches an existing snapshot group, the
  ///    existing row is replaced in place by
  ///    [_mergeAppendedVideoGroup] (richer REST data folded into the
  ///    existing WS-built row, preserving its position).
  /// 2. **`sourceEventIds` overlap** — when an incoming item's
  ///    underlying Nostr event ids overlap the rendered snapshot's set,
  ///    the incoming item is skipped as a cross-path duplicate. Same
  ///    logical-event identity that [acceptRealtime] queries against the
  ///    current snapshot (Nostr event id).
  /// 3. **`id` equality fallback** — defensive against the rare case of
  ///    items with empty `sourceEventIds` (server returned a notification
  ///    without `source_event_id`). Preserves the original
  ///    `_emitSnapshotForPage` contract; PR #4247's REST→WS guard relied
  ///    only on (1)+(2) and is untouched.
  ///
  /// Closes the symmetric gap to PR #4247: WS-first arrival followed by
  /// a REST pagination that returns the same Nostr event(s) no longer
  /// duplicates the row (#4264).
  void _emitSnapshotForPage(
    NotificationPage page, {
    required bool isFirstPage,
  }) {
    if (isFirstPage) {
      _snapshot.add(page);
      return;
    }
    final current = _snapshot.value;
    final mergedItems = _mergeAppendedPage(current.items, page.items);
    _snapshot.add(page.copyWith(items: mergedItems));
  }

  /// Returns the merged item list for a non-first-page emission.
  ///
  /// See [_emitSnapshotForPage] for the dedupe/merge contract.
  static List<NotificationItem> _mergeAppendedPage(
    List<NotificationItem> current,
    List<NotificationItem> incoming,
  ) {
    final result = [...current];
    final allSourceEventIds = <String>{
      for (final n in result) ...n.sourceEventIds,
    };
    final allIds = <String>{for (final n in result) n.id};
    final videoGroupIndex = <(String, NotificationKind), int>{};
    for (var i = 0; i < result.length; i++) {
      final item = result[i];
      if (item is VideoNotification) {
        videoGroupIndex[(item.videoEventId, item.type)] = i;
      }
    }

    final appended = <NotificationItem>[];
    for (final item in incoming) {
      if (item is VideoNotification) {
        final idx = videoGroupIndex[(item.videoEventId, item.type)];
        if (idx != null) {
          result[idx] = _mergeAppendedVideoGroup(
            result[idx] as VideoNotification,
            item,
          );
          allSourceEventIds.addAll(item.sourceEventIds);
          allIds.add(item.id);
          continue;
        }
      }
      final hasOverlap = item.sourceEventIds.any(allSourceEventIds.contains);
      if (hasOverlap) continue;
      // Fallback: catch same-id repeats when sourceEventIds is empty (server
      // omitted source_event_id). Preserves the original by-id dedupe
      // contract.
      if (allIds.contains(item.id)) continue;
      appended.add(item);
      allSourceEventIds.addAll(item.sourceEventIds);
      allIds.add(item.id);
    }
    return [...result, ...appended];
  }

  /// Merges [incoming] (from a REST pagination page) into [existing] (a
  /// snapshot row, typically WS-built) without changing the row's
  /// position in the snapshot.
  ///
  /// Mirror of [_mergeIntoExistingVideoGroup] in the opposite direction
  /// (incoming group → existing single, instead of incoming single →
  /// existing group). Semantics:
  ///
  /// - `sourceEventIds` = set union of both sides (preserves uniqueness).
  /// - `totalCount` = size of the union (so the count reflects unique
  ///   underlying logical events, not the sum of overlapping totals);
  ///   floored at `mergedActors.length` so the constructor's
  ///   `totalCount >= actors.length` invariant always holds even in the
  ///   defensive edge case where both sides had empty `sourceEventIds`
  ///   (server response missing `source_event_id`).
  /// - `actors` = the union of existing + incoming actors, then
  ///   re-ordered to keep an explicitly named actor in front and capped
  ///   at [_maxGroupActors].
  /// - `isRead` = `existing.isRead && incoming.isRead` (either side
  ///   being unread keeps the row unread).
  /// - `timestamp` = `max(existing.timestamp, incoming.timestamp)`.
  /// - Thumbnail / title / addressable id = existing if non-empty, else
  ///   incoming (parallel to `_groupVideoAnchored`'s
  ///   `_nonEmpty(...) ?? _nonEmpty(...)` pattern).
  /// - `commentText` for comment-kind rows: pick from the side with the
  ///   larger `timestamp`, falling back to the other side only when the
  ///   newer side has no text. Mirrors the long-standing pagination
  ///   merge contract even after lead-actor reordering.
  static VideoNotification _mergeAppendedVideoGroup(
    VideoNotification existing,
    VideoNotification incoming,
  ) {
    final unionIds = <String>{
      ...existing.sourceEventIds,
      ...incoming.sourceEventIds,
    }.toList();
    final mergedActors = _orderVideoGroupActors([
      ...existing.actors,
      ...incoming.actors.where(
        (a) => !existing.actors.any((e) => e.pubkey == a.pubkey),
      ),
    ]).take(_maxGroupActors).toList();
    final existingIsNewer = !existing.timestamp.isBefore(incoming.timestamp);
    final mergedTimestamp = existingIsNewer
        ? existing.timestamp
        : incoming.timestamp;
    final mergedCommentText = existing.type == NotificationKind.comment
        ? (existingIsNewer
              ? (existing.commentText ?? incoming.commentText)
              : (incoming.commentText ?? existing.commentText))
        : null;
    final mergedTotalCount = unionIds.length >= mergedActors.length
        ? unionIds.length
        : mergedActors.length;
    return existing.copyWith(
      sourceEventIds: unionIds,
      actors: mergedActors,
      totalCount: mergedTotalCount,
      isRead: existing.isRead && incoming.isRead,
      timestamp: mergedTimestamp,
      videoThumbnailUrl:
          _nonEmpty(existing.videoThumbnailUrl) ??
          _nonEmpty(incoming.videoThumbnailUrl),
      videoTitle:
          _nonEmpty(existing.videoTitle) ?? _nonEmpty(incoming.videoTitle),
      videoAddressableId:
          _nonEmpty(existing.videoAddressableId) ??
          _nonEmpty(incoming.videoAddressableId),
      commentText: mergedCommentText,
    );
  }

  /// Returns [items] with the matching ids flipped to `isRead: true`.
  static List<NotificationItem> _flipIsRead(
    List<NotificationItem> items,
    Set<String> ids,
  ) {
    return items.map((n) {
      if (!ids.contains(n.id) || n.isRead) return n;
      return switch (n) {
        VideoNotification() => n.copyWith(isRead: true),
        ActorNotification() => n.copyWith(isRead: true),
      };
    }).toList();
  }

  /// Returns [items] with every item flipped to `isRead: true`.
  static List<NotificationItem> _flipAllRead(List<NotificationItem> items) {
    return items.map((n) {
      if (n.isRead) return n;
      return switch (n) {
        VideoNotification() => n.copyWith(isRead: true),
        ActorNotification() => n.copyWith(isRead: true),
      };
    }).toList();
  }

  /// Enriches raw relay notifications with profile + video metadata, then
  /// groups them into [VideoNotification]s and [ActorNotification]s.
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
    final (profiles, videosById) = await (profilesFuture, videosFuture).wait;

    final consolidated = _consolidateFollows(raw);
    final videos = _groupVideoAnchored(consolidated, profiles, videosById);
    final actors = _mapActorAnchored(consolidated, profiles);

    final items = <NotificationItem>[...videos, ...actors]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return _applyBlockFilter(items);
  }

  /// Filters notifications from blocked/muted users.
  ///
  /// - [VideoNotification]: blocked actors stripped; if no actors remain,
  ///   the entire notification is dropped. The displayed totalCount is
  ///   recomputed from the remaining actors.
  /// - [ActorNotification]: dropped if the actor is blocked.
  List<NotificationItem> _applyBlockFilter(List<NotificationItem> items) {
    final filter = _blockFilter;
    if (filter == null) return items;
    return items
        .map(
          (n) => switch (n) {
            VideoNotification() => () {
              final filtered = n.actors
                  .where((a) => !filter(a.pubkey))
                  .toList();
              if (filtered.isEmpty) return null;
              if (filtered.length == n.actors.length) return n;
              return n.copyWith(actors: filtered, totalCount: filtered.length);
            }(),
            ActorNotification() => filter(n.actor.pubkey) ? null : n,
          },
        )
        .whereType<NotificationItem>()
        .toList();
  }

  /// Filters a single real-time [NotificationItem].
  ///
  /// Returns `null` if the notification should be hidden (all actors
  /// blocked). Use this for WebSocket events that bypass [getNotifications].
  NotificationItem? filterRealtimeNotification(NotificationItem item) {
    final result = _applyBlockFilter([item]);
    return result.isEmpty ? null : result.first;
  }

  /// Fetches [VideoStats] for each id in parallel.
  ///
  /// Per-id failures are tolerated — a single failed lookup yields no
  /// entry in the result map.
  Future<Map<String, VideoStats>> _fetchVideoMetadata(
    List<String> eventIds,
  ) async {
    if (eventIds.isEmpty) return const <String, VideoStats>{};
    final futures = eventIds.map((id) async {
      try {
        return await _funnelcakeApiClient.getVideoStats(id);
      } on Object {
        return null;
      }
    });
    final results = await Future.wait(futures);
    final map = <String, VideoStats>{};
    for (var i = 0; i < eventIds.length; i++) {
      final stats = results[i];
      if (stats != null) map[eventIds[i]] = stats;
    }
    return map;
  }

  /// Builds [VideoNotification]s by grouping like/comment/repost
  /// notifications by `(referencedEventId, kind)`.
  ///
  /// Threshold is 1 — every video-anchored notification with a non-null
  /// `referencedEventId` becomes a [VideoNotification], even if only one
  /// actor interacted. Notifications missing `referencedEventId` are
  /// dropped.
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
      final eventId = _videoAnchorEventId(kind, n);
      if (eventId == null || eventId.isEmpty) continue;
      final key = _VideoGroupKey(eventId, kind);
      (groups[key] ??= []).add(n);
    }

    final result = <VideoNotification>[];
    for (final entry in groups.entries) {
      final group = entry.value
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final actorNotifications = _orderVideoGroupActorNotifications(
        group,
        profiles,
      );
      final actors = _orderVideoGroupActors(
        actorNotifications
            .take(_maxGroupActors)
            .map((n) => _buildActor(n.sourcePubkey, profiles))
            .toList(),
      );
      final video = videosById[entry.key.eventId];
      final dTag = group
          .map((n) => n.referencedDTag)
          .firstWhere((d) => d != null, orElse: () => null);
      final addressableId = _buildVideoAddressableId(dTag);
      // Prefer thumbnail from the notification payload — it comes directly from
      // the server and is stable even after a metadata update (unlike the stats
      // lookup which uses the mutable event ID and may 404 post-edit).
      final thumbnailFromNotif = group
          .map((n) => n.referencedVideoThumbnail)
          .firstWhere((t) => t != null && t.isNotEmpty, orElse: () => null);
      final titleFromNotif = group
          .map((n) => n.referencedVideoTitle)
          .firstWhere((t) => t != null && t.isNotEmpty, orElse: () => null);
      // Carry the lead actor's comment text so the quoted body stays in
      // sync with the bold first-actor span after named-actor reordering.
      // Only meaningful for `comment` kind — likes and reposts have no
      // body text. Reuses the same length-cap as actor-anchored comments
      // / replies for layout safety.
      final commentTextForRow = entry.key.kind == NotificationKind.comment
          ? _truncateComment(actorNotifications.first.content, entry.key.kind)
          : null;
      result.add(
        VideoNotification(
          id: group.first.dedupeKey,
          type: entry.key.kind,
          videoEventId: entry.key.eventId,
          videoAddressableId: addressableId,
          videoThumbnailUrl:
              _nonEmpty(thumbnailFromNotif) ?? _nonEmpty(video?.thumbnail),
          videoTitle: _nonEmpty(titleFromNotif) ?? _nonEmpty(video?.title),
          actors: actors,
          totalCount: group.length,
          timestamp: group.first.createdAt,
          isRead: group.every((n) => n.read),
          commentText: commentTextForRow,
          sourceEventIds: group
              .map((n) => n.sourceEventId)
              .where((s) => s.isNotEmpty)
              .toList(),
        ),
      );
    }
    return result;
  }

  /// Builds [ActorNotification]s for follow/mention/system kinds.
  ///
  /// `reply` and other unmapped kinds are also routed here as
  /// [ActorNotification] — they don't have a clean video anchor, so we
  /// surface them as actor-anchored rows.
  List<ActorNotification> _mapActorAnchored(
    List<RelayNotification> raw,
    Map<String, UserProfile> profiles,
  ) {
    final result = <ActorNotification>[];
    for (final n in raw) {
      final kind = _mapNotificationKind(n);
      // Skip kinds that became VideoNotifications.
      if (kind == NotificationKind.like ||
          kind == NotificationKind.comment ||
          kind == NotificationKind.repost) {
        continue;
      }
      // ActorNotification supports follow/mention/system/likeComment/reply;
      // coerce any other kind to system.
      final mapped =
          (kind == NotificationKind.follow ||
              kind == NotificationKind.mention ||
              kind == NotificationKind.system ||
              kind == NotificationKind.likeComment ||
              kind == NotificationKind.reply)
          ? kind
          : NotificationKind.system;
      result.add(
        ActorNotification(
          id: n.dedupeKey,
          type: mapped,
          actor: _buildActor(n.sourcePubkey, profiles),
          timestamp: n.createdAt,
          isRead: n.read,
          commentText: _truncateComment(n.content, kind),
          targetEventId: _actorTargetEventId(mapped, n),
          sourceEventIds: n.sourceEventId.isNotEmpty
              ? [n.sourceEventId]
              : const [],
          videoAddressableId: _actorVideoAddressableId(mapped, n),
        ),
      );
    }
    return result;
  }

  /// Enriches a single raw [RelayNotification] for realtime insertion.
  ///
  /// Fetches the actor's profile and (if applicable) the referenced
  /// video's stats in parallel. Returns null if the notification cannot
  /// be turned into a [NotificationItem] (e.g. a video-anchored type
  /// missing a `referencedEventId`).
  Future<NotificationItem?> enrichOne(RelayNotification raw) async {
    final kind = _mapNotificationKind(raw);
    final referenced = _videoAnchorEventId(kind, raw);
    final isVideoAnchored =
        kind == NotificationKind.like ||
        kind == NotificationKind.comment ||
        kind == NotificationKind.repost;

    final profilesFuture = _profileRepository.fetchBatchProfiles(
      pubkeys: [raw.sourcePubkey],
    );
    final videoFuture = (referenced != null && referenced.isNotEmpty)
        ? _fetchVideoMetadata([referenced])
        : Future<Map<String, VideoStats>>.value(const {});

    final (profiles, videosById) = await (profilesFuture, videoFuture).wait;

    final actor = _buildActor(raw.sourcePubkey, profiles);

    if (isVideoAnchored) {
      if (referenced == null || referenced.isEmpty) return null;
      final video = videosById[referenced];
      final addressableId = _buildVideoAddressableId(raw.referencedDTag);
      return VideoNotification(
        id: raw.dedupeKey,
        type: kind,
        videoEventId: referenced,
        videoAddressableId: addressableId,
        videoThumbnailUrl:
            _nonEmpty(raw.referencedVideoThumbnail) ??
            _nonEmpty(video?.thumbnail),
        videoTitle:
            _nonEmpty(raw.referencedVideoTitle) ?? _nonEmpty(video?.title),
        actors: [actor],
        totalCount: 1,
        timestamp: raw.createdAt,
        isRead: raw.read,
        commentText: kind == NotificationKind.comment
            ? _truncateComment(raw.content, kind)
            : null,
        sourceEventIds: raw.sourceEventId.isNotEmpty
            ? [raw.sourceEventId]
            : const [],
      );
    }

    final mapped =
        (kind == NotificationKind.follow ||
            kind == NotificationKind.mention ||
            kind == NotificationKind.system ||
            kind == NotificationKind.likeComment ||
            kind == NotificationKind.reply)
        ? kind
        : NotificationKind.system;
    return ActorNotification(
      id: raw.dedupeKey,
      type: mapped,
      actor: actor,
      timestamp: raw.createdAt,
      isRead: raw.read,
      commentText: _truncateComment(raw.content, kind),
      targetEventId: _actorTargetEventId(mapped, raw),
      sourceEventIds: raw.sourceEventId.isNotEmpty
          ? [raw.sourceEventId]
          : const [],
      videoAddressableId: _actorVideoAddressableId(mapped, raw),
    );
  }

  /// Returns null if [s] is null or empty, otherwise [s].
  static String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

  /// Returns the `targetEventId` for an actor-anchored notification.
  ///
  /// - `likeComment`/`reply` → the referenced comment event ID (resolver
  ///   walks its E-tags to reach the root video).
  /// - `mention` → the source event ID (the kind-1 event that mentioned
  ///   the user; same resolver path).
  /// - Everything else → null.
  ///
  /// Used by both the page-load path ([_mapActorAnchored]) and the
  /// realtime path ([enrichOne]) to stay in lockstep.
  static String? _actorTargetEventId(
    NotificationKind mapped,
    RelayNotification n,
  ) => switch (mapped) {
    NotificationKind.likeComment || NotificationKind.reply =>
      // Prefer the referenced (parent) event ID. Fall back to the source
      // event ID (the reply event itself) when the server omits
      // referenced_event_id — both carry NIP-22 E-tags the resolver can
      // walk to find the root video.
      n.referencedEventId?.isNotEmpty == true
          ? n.referencedEventId
          : (n.sourceEventId.isNotEmpty ? n.sourceEventId : null),
    NotificationKind.mention =>
      n.sourceEventId.isNotEmpty ? n.sourceEventId : null,
    _ => null,
  };

  /// Builds the stable NIP-33 addressable ID for a video the current
  /// user owns.
  ///
  /// All notifications surfaced here are about the current user's own
  /// content, so [_userPubkey] is always the right author component.
  /// Returns null when the server didn't provide a usable [dTag].
  String? _buildVideoAddressableId(String? dTag) {
    if (dTag == null || dTag.isEmpty) return null;
    return '${NIP71VideoKinds.addressableShortVideo}:$_userPubkey:$dTag';
  }

  /// Returns the stable NIP-33 addressable ID for an actor-anchored
  /// notification, when the server provided the video's `d_tag`.
  ///
  /// Only populated for `likeComment` and `reply` — the tap handler uses
  /// it to navigate directly to the video without a relay round-trip.
  ///
  /// Used by both the page-load path ([_mapActorAnchored]) and the
  /// realtime path ([enrichOne]) to stay in lockstep.
  String? _actorVideoAddressableId(
    NotificationKind mapped,
    RelayNotification n,
  ) {
    if (mapped != NotificationKind.likeComment &&
        mapped != NotificationKind.reply) {
      return null;
    }
    return _buildVideoAddressableId(n.referencedDTag);
  }

  /// Consolidates follow notifications — keeps the earliest per pubkey.
  List<RelayNotification> _consolidateFollows(List<RelayNotification> raw) {
    final followsByPubkey = <String, RelayNotification>{};
    final result = <RelayNotification>[];

    for (final n in raw) {
      final kind = _mapNotificationKind(n);
      if (kind == NotificationKind.follow) {
        final existing = followsByPubkey[n.sourcePubkey];
        if (existing == null || n.createdAt.isBefore(existing.createdAt)) {
          followsByPubkey[n.sourcePubkey] = n;
        }
      } else {
        result.add(n);
      }
    }

    result.addAll(followsByPubkey.values);
    return result;
  }

  /// Builds an [ActorInfo] from a pubkey and the profile lookup map.
  ActorInfo _buildActor(String pubkey, Map<String, UserProfile> profiles) {
    final profile = profiles[pubkey];
    return ActorInfo(
      pubkey: pubkey,
      displayName: _displayNameForActor(pubkey, profile),
      pictureUrl: profile?.picture,
    );
  }

  /// Orders grouped video notifications with a named profile in the lead
  /// actor position.
  List<RelayNotification> _orderVideoGroupActorNotifications(
    List<RelayNotification> group,
    Map<String, UserProfile> profiles,
  ) {
    RelayNotification? lead;
    for (final n in group) {
      if (_hasExplicitActorName(n.sourcePubkey, profiles)) {
        lead = n;
        break;
      }
    }

    final ordered = lead == null
        ? group
        : <RelayNotification>[lead, ...group.where((n) => !identical(n, lead))];
    return ordered;
  }

  static bool _hasExplicitActorName(
    String pubkey,
    Map<String, UserProfile> profiles,
  ) => _explicitActorName(pubkey, profiles[pubkey]) != null;

  static String _displayNameForActor(String pubkey, UserProfile? profile) {
    final explicit = _explicitActorName(pubkey, profile);
    if (explicit != null) return explicit;

    final fallback = profile?.bestDisplayName;
    if (_isUsableActorName(fallback, pubkey)) return fallback!.trim();

    return UserProfile.defaultDisplayNameFor(pubkey);
  }

  static String? _explicitActorName(String pubkey, UserProfile? profile) {
    if (profile == null) return null;

    final displayName = profile.displayName;
    if (_isUsableActorName(displayName, pubkey)) {
      return stripZalgo(displayName!).trim();
    }

    final name = profile.name;
    if (_isUsableActorName(name, pubkey)) return stripZalgo(name!).trim();

    return null;
  }

  static List<ActorInfo> _orderVideoGroupActors(List<ActorInfo> actors) {
    ActorInfo? lead;
    for (final actor in actors) {
      if (_hasPreferredLeadActorName(actor.displayName, actor.pubkey)) {
        lead = actor;
        break;
      }
    }

    if (lead == null) return actors;
    return [lead, ...actors.where((actor) => actor.pubkey != lead!.pubkey)];
  }

  static bool _hasPreferredLeadActorName(String displayName, String pubkey) {
    if (!_isUsableActorName(displayName, pubkey)) {
      return false;
    }
    return displayName.trim() != UserProfile.defaultDisplayNameFor(pubkey);
  }

  static bool _isUsableActorName(String? value, String pubkey) {
    final name = value?.trim();
    if (name == null || name.isEmpty) return false;

    final lower = name.toLowerCase();
    if (lower == 'unknown' || lower == 'unknown user') return false;
    if (name == pubkey) return false;
    if (_hexIdentifierPattern.hasMatch(name)) return false;
    if (_npubIdentifierPattern.hasMatch(name)) return false;

    return true;
  }

  /// Maps a relay notification type string + source kind to
  /// [NotificationKind].
  ///
  /// Likes (and zaps) on a non-video target — typically a kind 1111
  /// comment — map to [NotificationKind.likeComment] so the UI can
  /// render "liked your comment" instead of "liked your video".
  ///
  /// Replies (kind 1111) split the same way: a reply directly on a video
  /// is indistinguishable from a comment for the user, so we map it to
  /// [NotificationKind.comment]. A reply on a non-video (i.e. on one of
  /// the user's own comments) maps to [NotificationKind.reply].
  static NotificationKind _mapNotificationKind(RelayNotification n) {
    final isReaction = switch (n.notificationType) {
      'reaction' || 'zap' => true,
      _ => n.sourceKind == 7,
    };
    if (isReaction) {
      return n.isReferencedVideo
          ? NotificationKind.like
          : NotificationKind.likeComment;
    }
    if (n.notificationType != 'reply' &&
        n.sourceKind == 1111 &&
        n.rootEventId != null &&
        n.rootEventId!.isNotEmpty) {
      return NotificationKind.comment;
    }
    return switch (n.notificationType) {
      'reply' =>
        n.isReferencedVideo ? NotificationKind.comment : NotificationKind.reply,
      'comment' => NotificationKind.comment,
      'repost' => NotificationKind.repost,
      'mention' => NotificationKind.mention,
      'follow' || 'contact' => NotificationKind.follow,
      _ when n.sourceKind == 6 => NotificationKind.repost,
      _ when n.sourceKind == 3 => NotificationKind.follow,
      _ when n.sourceKind == 1 => NotificationKind.comment,
      _ => NotificationKind.system,
    };
  }

  /// Returns the video event ID a video-anchored notification should group by.
  ///
  /// New staging Funnelcake payloads for NIP-22 comments can omit
  /// `referenced_event_id` while including `root_event_id`. For comments, the
  /// root ID is the video we want to open and group on.
  static String? _videoAnchorEventId(
    NotificationKind kind,
    RelayNotification n,
  ) {
    if (kind == NotificationKind.comment &&
        n.rootEventId != null &&
        n.rootEventId!.isNotEmpty) {
      return n.rootEventId;
    }
    return n.referencedEventId;
  }

  /// Truncates comment text to [_maxCommentLength] characters.
  ///
  /// Only applies to comment and reply notifications.
  static String? _truncateComment(String? content, NotificationKind kind) {
    if (content == null) return null;
    if (kind != NotificationKind.comment && kind != NotificationKind.reply) {
      return null;
    }
    if (content.length <= _maxCommentLength) return content;
    return '${content.substring(0, _maxCommentLength)}...';
  }
}

@immutable
class _VideoGroupKey {
  const _VideoGroupKey(this.eventId, this.kind);
  final String eventId;
  final NotificationKind kind;

  @override
  bool operator ==(Object other) =>
      other is _VideoGroupKey && other.eventId == eventId && other.kind == kind;

  @override
  int get hashCode => Object.hash(eventId, kind);
}
