// ABOUTME: Repository that fetches raw notifications from FunnelCake,
// ABOUTME: enriches them with profile + video metadata, groups video-anchored
// ABOUTME: notifications by (referencedEventId, kind), and maps actor-anchored
// ABOUTME: notifications.

import 'dart:async';
import 'dart:math' as math;

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
import 'package:unified_logger/unified_logger.dart';

/// Callback that returns NIP-98 auth headers for an outgoing request.
///
/// The repository invokes this with the **full** URL the request will use
/// (scheme + host + path + query) and the HTTP method. For requests with
/// a body, [body] is the exact byte-identical JSON the request will send
/// so the implementation can compute the matching `payload` tag — passing
/// an empty body for a POST/PUT/PATCH causes the server to 401 with
/// `payload hash mismatch`.
typedef AuthHeadersProvider =
    Future<Map<String, String>> Function(
      String url,
      String method, {
      String? body,
    });

/// Maximum length for comment preview text before truncation.
const _maxCommentLength = 50;

/// Maximum number of actor avatars shown in a grouped notification.
const _maxGroupActors = 3;

final RegExp _hexIdentifierPattern = RegExp(r'^[0-9a-fA-F]{32,}$');
final RegExp _npubIdentifierPattern = RegExp(
  r'^npub1[023456789acdefghjklmnpqrstuvwxyz]+$',
  caseSensitive: false,
);

/// Retry policy for the first-page notifications fetch.
///
/// Retries only transient server faults — HTTP `5xx` and request timeouts
/// — with full-jitter backoff. Auth (`401`) and client errors (`4xx` other
/// than 408/429) are caller bugs, not transient, and are surfaced
/// immediately so the failure UI can fire.
abstract class _NotificationRetryConfig {
  /// Number of attempts including the initial call.
  static const maxAttempts = 3;

  /// Base backoff applied to the i-th retry (0-indexed) as `base * 3^i`.
  static const baseBackoff = Duration(milliseconds: 200);

  /// Upper bound on a single retry's delay before jitter.
  static const maxBackoff = Duration(milliseconds: 1500);
}

/// Number of cached rows hydrated from the DAO on cold start.
const _hydrationLimit = 50;

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
  ///
  /// When [hydrateOnStart] is `true` (default), the repository kicks off a
  /// best-effort load from [notificationsDao] so the inbox can render
  /// cached items before the first REST call resolves. Tests pass `false`
  /// to keep the snapshot at [NotificationPage.empty] for deterministic
  /// assertions.
  NotificationRepository({
    required FunnelcakeApiClient funnelcakeApiClient,
    required ProfileRepository profileRepository,
    required NotificationsDao notificationsDao,
    required String userPubkey,
    BlockedNotificationFilter? blockFilter,
    AuthHeadersProvider? authHeadersProvider,
    bool hydrateOnStart = true,
  }) : _funnelcakeApiClient = funnelcakeApiClient,
       _profileRepository = profileRepository,
       _notificationsDao = notificationsDao,
       _userPubkey = userPubkey,
       _blockFilter = blockFilter,
       _authHeadersProvider = authHeadersProvider {
    if (hydrateOnStart) {
      unawaited(_hydrateFromCache());
    }
  }

  final FunnelcakeApiClient _funnelcakeApiClient;
  final ProfileRepository _profileRepository;
  final NotificationsDao _notificationsDao;
  final String _userPubkey;
  final BlockedNotificationFilter? _blockFilter;
  final AuthHeadersProvider? _authHeadersProvider;

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
  /// the snapshot's items, subsequent pages append. First-page successes
  /// also write the enriched items through to [NotificationsDao] so a
  /// later cold-start can hydrate the inbox before the network responds,
  /// and clear any pending `lastRefreshError` flag on the snapshot.
  ///
  /// Transient first-page failures (`5xx`, request timeout) are retried
  /// per [_NotificationRetryConfig]. On terminal failure the snapshot is
  /// stamped with `lastRefreshError: true` so the BLoC can keep cached
  /// items visible alongside an inline error affordance, and the typed
  /// [FunnelcakeException] is rethrown after structured logging so
  /// callers can also drive a hard-failure UI when the cache is empty.
  Future<NotificationPage> getNotifications({
    String? cursor,
    String? cursorId,
  }) async {
    final effectiveCursor = cursor ?? _lastCursor;
    final effectiveCursorId = cursor != null
        ? cursorId
        : cursorId ?? _lastCursorId;
    final isFirstPage = effectiveCursor == null;

    try {
      final response = isFirstPage
          ? await _fetchWithRetry(
              cursor: effectiveCursor,
              cursorId: effectiveCursorId,
            )
          : await _fetchOnce(
              cursor: effectiveCursor,
              cursorId: effectiveCursorId,
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
      _emitSnapshotForPage(page, isFirstPage: isFirstPage);

      if (isFirstPage) {
        unawaited(_persistSnapshot(items));
      }
      return page;
    } on Exception catch (e, s) {
      Log.error(
        'Failed to fetch notifications: $e',
        name: 'NotificationRepository.getNotifications',
        category: LogCategory.api,
        error: e,
        stackTrace: s,
      );
      if (isFirstPage) {
        _markRefreshError();
      }
      rethrow;
    }
  }

  /// Single-attempt fetch — used for paginate-load-more requests where
  /// retrying could shift `before` past the user-visible boundary.
  Future<NotificationResponse> _fetchOnce({
    required String? cursor,
    required String? cursorId,
  }) async {
    final requestUrl = _funnelcakeApiClient
        .notificationsUri(
          pubkey: _userPubkey,
          cursor: cursor,
          cursorId: cursorId,
        )
        .toString();
    final authHeaders = _authHeadersProvider != null
        ? await _authHeadersProvider(requestUrl, 'GET')
        : <String, String>{};
    return _funnelcakeApiClient.getNotifications(
      pubkey: _userPubkey,
      cursor: cursor,
      cursorId: cursorId,
      requestUri: Uri.parse(requestUrl),
      authHeaders: authHeaders,
    );
  }

  /// First-page fetch with bounded retry on transient server faults.
  Future<NotificationResponse> _fetchWithRetry({
    required String? cursor,
    required String? cursorId,
  }) async {
    Object? lastError;
    StackTrace? lastStack;
    for (
      var attempt = 0;
      attempt < _NotificationRetryConfig.maxAttempts;
      attempt++
    ) {
      try {
        return await _fetchOnce(cursor: cursor, cursorId: cursorId);
      } on Exception catch (e, s) {
        if (!_isTransient(e) ||
            attempt == _NotificationRetryConfig.maxAttempts - 1) {
          rethrow;
        }
        lastError = e;
        lastStack = s;
        Log.error(
          'Transient notifications fetch failure '
          '(attempt ${attempt + 1}/${_NotificationRetryConfig.maxAttempts}): '
          '$e',
          name: 'NotificationRepository._fetchWithRetry',
          category: LogCategory.api,
          error: e,
          stackTrace: s,
        );
        await Future<void>.delayed(_backoffFor(attempt));
      }
    }
    // Unreachable — the loop either returns on success or rethrows on the
    // final attempt — but the analyzer can't prove that.
    Error.throwWithStackTrace(
      lastError ?? StateError('retry exhausted'),
      lastStack ?? StackTrace.current,
    );
  }

  /// Whether [e] is a transient error worth retrying.
  ///
  /// Retries timeouts and HTTP `5xx` plus 408/429. Skips `401`/`403`
  /// (auth) and other `4xx` (caller bug) so failure UI fires immediately.
  static bool _isTransient(Exception e) {
    if (e is FunnelcakeTimeoutException) return true;
    if (e is FunnelcakeApiException) {
      final status = e.statusCode;
      if (status == 408 || status == 429) return true;
      return status >= 500 && status < 600;
    }
    return false;
  }

  /// Computes the delay for the i-th retry (0-indexed) using full jitter
  /// on top of an exponential schedule, capped at
  /// [_NotificationRetryConfig.maxBackoff].
  Duration _backoffFor(int attempt) {
    final scaled =
        _NotificationRetryConfig.baseBackoff.inMilliseconds *
        math.pow(3, attempt).toInt();
    final capped = math.min(
      scaled,
      _NotificationRetryConfig.maxBackoff.inMilliseconds,
    );
    final jittered = _jitter.nextInt(capped + 1);
    return Duration(milliseconds: jittered);
  }

  /// Stamps the snapshot with `lastRefreshError: true` so the UI can
  /// render an inline error affordance while keeping cached items.
  void _markRefreshError() {
    final current = _snapshot.value;
    if (current.lastRefreshError) return;
    _snapshot.add(current.copyWith(lastRefreshError: true));
  }

  /// Best-effort load of cached rows into the snapshot on construction.
  ///
  /// Runs only when the snapshot is still empty (avoids racing the first
  /// REST response). Cached rows are surfaced as lightweight placeholders
  /// — video-anchored rows stay video-anchored when reconstructable, and
  /// the next REST/WS arrival replaces them with fully enriched items.
  Future<void> _hydrateFromCache() async {
    try {
      if (_snapshot.value.items.isNotEmpty) return;
      final rows = await _notificationsDao.getAllNotifications(
        limit: _hydrationLimit,
      );
      if (rows.isEmpty) return;
      if (_snapshot.value.items.isNotEmpty) return;
      final items = rows
          .map(_rowToPlaceholder)
          .whereType<NotificationItem>()
          .toList();
      if (items.isEmpty) return;
      _snapshot.add(
        _snapshot.value.copyWith(
          items: items,
          // Hydrated rows are a degraded view; assume more is available
          // until the first REST refresh resolves.
          hasMore: true,
        ),
      );
    } on Exception catch (e, s) {
      Log.error(
        'Failed to hydrate notifications cache: $e',
        name: 'NotificationRepository._hydrateFromCache',
        category: LogCategory.storage,
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Maps a [NotificationRow] into a placeholder [NotificationItem].
  ///
  /// Returns null when the cached row cannot be reconstructed as a valid
  /// item (e.g. a `like`/`comment`/`repost` row whose `targetEventId` is
  /// missing — [VideoNotification] requires a non-null `videoEventId`).
  /// Skipping is preferable to degrading video-anchored rows into
  /// [NotificationKind.system], because system rows disappear from the
  /// Likes/Comments/Reposts tab filters and become inert on tap.
  ///
  /// Profile and video metadata aren't refetched here — placeholders are
  /// always replaced by the next first-page REST emission, so we keep
  /// the hydration path synchronous and dependency-free.
  static NotificationItem? _rowToPlaceholder(NotificationRow row) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      row.timestamp * 1000,
      isUtc: true,
    ).toLocal();
    final actor = ActorInfo(
      pubkey: row.fromPubkey,
      displayName: UserProfile.defaultDisplayNameFor(row.fromPubkey),
    );

    // Video-anchored kinds — reconstruct VideoNotification using the cached
    // targetEventId (which `_itemToCacheRow` writes as videoEventId).
    final videoKind = _videoKindFromCachedType(row.type);
    if (videoKind != null) {
      final videoEventId = row.targetEventId;
      if (videoEventId == null || videoEventId.isEmpty) return null;
      return VideoNotification(
        id: row.id,
        type: videoKind,
        videoEventId: videoEventId,
        actors: [actor],
        totalCount: 1,
        timestamp: timestamp,
        isRead: row.isRead,
        commentText: videoKind == NotificationKind.comment ? row.content : null,
        notificationIds: row.id.isNotEmpty ? [row.id] : const [],
        // sourceEventIds intentionally empty — the cache stores only the
        // persisted row id and the videoEventId (`targetEventId`), not the
        // underlying Nostr source event id set. First-page REST emission
        // replaces the placeholder, so the union-by-sourceEventId merge path
        // doesn't need a value here.
      );
    }

    // Actor-anchored kinds — `follow`, `mention`, `likeComment`, `reply`,
    // `system` (and unknown future types fall through to `system`).
    return ActorNotification(
      id: row.id,
      type: _actorKindFromCachedType(row.type),
      actor: actor,
      timestamp: timestamp,
      isRead: row.isRead,
      commentText: row.content,
      targetEventId: row.targetEventId,
      notificationIds: row.id.isNotEmpty ? [row.id] : const [],
    );
  }

  /// Maps a cached `type` column to a video-anchored [NotificationKind].
  ///
  /// Returns null for non-video types — those are routed through
  /// [_actorKindFromCachedType] instead.
  static NotificationKind? _videoKindFromCachedType(String type) =>
      switch (type) {
        'like' => NotificationKind.like,
        'comment' => NotificationKind.comment,
        'repost' => NotificationKind.repost,
        _ => null,
      };

  /// Maps a cached `type` column to an actor-anchored [NotificationKind].
  ///
  /// Unknown types fall back to [NotificationKind.system] so the row
  /// stays renderable until REST refreshes it.
  static NotificationKind _actorKindFromCachedType(String type) =>
      switch (type) {
        'follow' => NotificationKind.follow,
        'mention' => NotificationKind.mention,
        'likeComment' => NotificationKind.likeComment,
        'reply' => NotificationKind.reply,
        _ => NotificationKind.system,
      };

  /// Writes [items] through to [NotificationsDao] so a future cold start
  /// can hydrate the inbox before the network responds.
  ///
  /// Per-item failures are swallowed — the in-memory snapshot is the
  /// active source of truth; the cache is a fallback, not a critical
  /// path.
  Future<void> _persistSnapshot(List<NotificationItem> items) async {
    try {
      final rows = items.map(_itemToCacheRow).toList();
      await _notificationsDao.replaceAll(rows);
    } on Exception catch (e, s) {
      Log.error(
        'Failed to persist notifications cache: $e',
        name: 'NotificationRepository._persistSnapshot',
        category: LogCategory.storage,
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Projects an enriched [NotificationItem] into the persistence record
  /// shape accepted by [NotificationsDao.replaceAll].
  static NotificationCacheRow _itemToCacheRow(NotificationItem item) {
    final (fromPubkey, targetEventId, targetPubkey, content) = switch (item) {
      VideoNotification(
        :final actors,
        :final videoEventId,
        :final commentText,
      ) =>
        (
          actors.isNotEmpty ? actors.first.pubkey : '',
          videoEventId,
          null,
          commentText,
        ),
      ActorNotification(
        :final actor,
        :final targetEventId,
        :final commentText,
      ) =>
        (actor.pubkey, targetEventId, actor.pubkey, commentText),
    };
    return (
      id: item.id,
      type: _persistType(item.type),
      fromPubkey: fromPubkey,
      timestamp: item.timestamp.toUtc().millisecondsSinceEpoch ~/ 1000,
      targetEventId: targetEventId,
      targetPubkey: targetPubkey,
      content: content,
      isRead: item.isRead,
    );
  }

  /// String form persisted in the `type` column.
  ///
  /// Inverse of [_videoKindFromCachedType] plus [_actorKindFromCachedType].
  static String _persistType(NotificationKind kind) => switch (kind) {
    NotificationKind.like => 'like',
    NotificationKind.comment => 'comment',
    NotificationKind.repost => 'repost',
    NotificationKind.follow => 'follow',
    NotificationKind.mention => 'mention',
    NotificationKind.likeComment => 'likeComment',
    NotificationKind.reply => 'reply',
    NotificationKind.system => 'system',
  };

  static final math.Random _jitter = math.Random();

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
    final notificationIds = _expandServerNotificationIds(before.items, idSet);

    try {
      // Sign the exact URL + body the request will use, otherwise the
      // funnelcake server 401s with `URL mismatch` / `payload hash
      // mismatch` and the rollback bounces the badge back to N.
      final url = _funnelcakeApiClient
          .notificationsReadUri(pubkey: _userPubkey)
          .toString();
      final body = FunnelcakeApiClient.buildMarkNotificationsReadBody(
        notificationIds: notificationIds,
      );
      final authHeaders = _authHeadersProvider != null
          ? await _authHeadersProvider(url, 'POST', body: body)
          : <String, String>{};

      await _funnelcakeApiClient.markNotificationsRead(
        pubkey: _userPubkey,
        notificationIds: notificationIds,
        authHeaders: authHeaders,
      );

      for (final id in notificationIds) {
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
      final url = _funnelcakeApiClient
          .notificationsReadUri(pubkey: _userPubkey)
          .toString();
      final body = FunnelcakeApiClient.buildMarkNotificationsReadBody();
      final authHeaders = _authHeadersProvider != null
          ? await _authHeadersProvider(url, 'POST', body: body)
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
        final mergedNotificationIds = <String>{
          ...existing.notificationIds,
          ...incoming.notificationIds,
        }.toList();
        result.add(
          existing.copyWith(
            actors: mergedActors,
            totalCount: existing.totalCount + 1,
            isRead: false,
            timestamp: incoming.timestamp,
            sourceEventIds: mergedSourceEventIds,
            notificationIds: mergedNotificationIds,
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
    final unionNotificationIds = <String>{
      ...existing.notificationIds,
      ...incoming.notificationIds,
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
      notificationIds: unionNotificationIds,
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
      if (!_matchesMarkReadId(n, ids) || n.isRead) return n;
      return switch (n) {
        VideoNotification() => n.copyWith(isRead: true),
        ActorNotification() => n.copyWith(isRead: true),
      };
    }).toList();
  }

  /// Expands display-row ids to all raw server notification ids represented by
  /// those rows. Unknown ids pass through so callers can still mark a raw id
  /// that is not present in the current snapshot.
  static List<String> _expandServerNotificationIds(
    List<NotificationItem> items,
    Set<String> ids,
  ) {
    final expanded = <String>{};
    final matchedInputIds = <String>{};

    for (final item in items) {
      if (!_matchesMarkReadId(item, ids)) continue;

      matchedInputIds
        ..add(item.id)
        ..addAll(item.notificationIds.where(ids.contains));

      final rawIds = item.notificationIds.isNotEmpty
          ? item.notificationIds
          : [item.id];
      expanded.addAll(rawIds.where((id) => id.isNotEmpty));
    }

    for (final id in ids) {
      if (id.isNotEmpty && !matchedInputIds.contains(id)) {
        expanded.add(id);
      }
    }

    return expanded.toList();
  }

  static bool _matchesMarkReadId(NotificationItem item, Set<String> ids) {
    return ids.contains(item.id) || item.notificationIds.any(ids.contains);
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
      if (_hasKnownReferencedVideoOwnerMismatch(
        referencedVideoEventId: eventId,
        videosById: videosById,
      )) {
        _logDroppedKnownOwnerMismatch(
          notificationId: n.id,
          sourcePubkey: n.sourcePubkey,
          referencedVideoEventId: eventId,
          referencedVideoOwnerPubkey: videosById[eventId]?.pubkey,
        );
        continue;
      }
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
      final addressableId = _recipientOwnedVideoAddressableId(
        dTag: dTag,
        video: video,
      );
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
          notificationIds: group
              .map((n) => n.dedupeKey)
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
          notificationIds: n.dedupeKey.isNotEmpty ? [n.dedupeKey] : const [],
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
      if (_hasKnownReferencedVideoOwnerMismatch(
        referencedVideoEventId: referenced,
        videosById: videosById,
      )) {
        _logDroppedKnownOwnerMismatch(
          notificationId: raw.id,
          sourcePubkey: raw.sourcePubkey,
          referencedVideoEventId: referenced,
          referencedVideoOwnerPubkey: video?.pubkey,
        );
        return null;
      }
      final addressableId = _recipientOwnedVideoAddressableId(
        dTag: raw.referencedDTag,
        video: video,
      );
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
        notificationIds: raw.dedupeKey.isNotEmpty ? [raw.dedupeKey] : const [],
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
      notificationIds: raw.dedupeKey.isNotEmpty ? [raw.dedupeKey] : const [],
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
  /// recipient *authoritatively* owns, or null when ownership is unknown.
  ///
  /// Only safe when [video] confirms the referenced video's owner is the
  /// recipient. On a metadata miss — a stale/edited event id, a fetch failure,
  /// or a comment whose `referenced_event_id` is empty — ownership is unknown,
  /// so we return null and let navigation fall back to the canonical
  /// `referencedEventId`. The synthesized id is always scoped to [_userPubkey],
  /// so a wrong guess would surface the recipient's *own* (or a non-existent)
  /// video — never another creator's — and failing safe avoids that. An empty
  /// owner pubkey is treated as unknown for the same reason.
  ///
  /// The d-tag comes from the authoritative [video], falling back to the
  /// payload [dTag] only when `VideoStats` omits one, so a `referenced_video`
  /// block that disagrees with `referenced_event_id` can't build a mismatched
  /// route.
  ///
  /// Known gaps (deferred, see #4730): the stable route is lost on a metadata
  /// miss for the recipient's own *edited* video; and the page-load path
  /// fetches only `referenced_event_id` metadata, so `root_event_id`-anchored
  /// comments confirm ownership on the realtime path only.
  String? _recipientOwnedVideoAddressableId({
    required String? dTag,
    required VideoStats? video,
  }) {
    if (video == null || video.pubkey != _userPubkey) return null;
    final resolvedDTag = _nonEmpty(video.dTag) ?? _nonEmpty(dTag);
    if (resolvedDTag == null) return null;
    return '${NIP71VideoKinds.addressableShortVideo}'
        ':$_userPubkey:$resolvedDTag';
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
    RelayNotification notification,
  ) {
    // The current payload does not include the owning pubkey for the parent
    // video, so synthesizing a stable route here can point at the wrong
    // creator's addressable video. Fall back to resolver-based navigation
    // until the API includes an authoritative owner component.
    return null;
  }

  bool _hasKnownReferencedVideoOwnerMismatch({
    required String referencedVideoEventId,
    required Map<String, VideoStats> videosById,
  }) {
    final ownerPubkey = videosById[referencedVideoEventId]?.pubkey;
    if (ownerPubkey == null || ownerPubkey.isEmpty) return false;
    return ownerPubkey != _userPubkey;
  }

  void _logDroppedKnownOwnerMismatch({
    required String notificationId,
    required String sourcePubkey,
    required String referencedVideoEventId,
    required String? referencedVideoOwnerPubkey,
  }) {
    Log.warning(
      'Dropping misattributed video notification: '
      'notificationId=$notificationId '
      'sourcePubkey=$sourcePubkey '
      'referencedVideoEventId=$referencedVideoEventId '
      'referencedVideoOwnerPubkey=${referencedVideoOwnerPubkey ?? 'unknown'} '
      'currentUserPubkey=$_userPubkey',
      name: 'NotificationRepository',
      category: LogCategory.api,
    );
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
  /// Replies (kind 1111) split by the immediate target, not by whether the
  /// payload also carries root video metadata. A reply directly on a video
  /// is indistinguishable from a comment for the user, so we map it to
  /// [NotificationKind.comment]. A reply on another comment maps to
  /// [NotificationKind.reply], even when Funnelcake also includes the root
  /// video's metadata for navigation.
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
    if (_isNestedCommentReply(n)) {
      return NotificationKind.reply;
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

  static bool _isNestedCommentReply(RelayNotification n) {
    if (n.notificationType != 'reply' && n.notificationType != 'comment') {
      return false;
    }
    if (n.sourceKind != 1111) return false;
    final rootEventId = n.rootEventId;
    if (rootEventId == null || rootEventId.isEmpty) return false;

    final referencedEventId = n.referencedEventId;
    if (referencedEventId != null &&
        referencedEventId.isNotEmpty &&
        referencedEventId != rootEventId) {
      return true;
    }

    final targetCommentId = n.targetCommentId;
    return targetCommentId != null &&
        targetCommentId.isNotEmpty &&
        n.sourceEventId.isNotEmpty &&
        targetCommentId != n.sourceEventId &&
        targetCommentId != rootEventId;
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
