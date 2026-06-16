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
/// 6. Consolidate follow duplicates (keep most recent per source pubkey)
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

  /// Monotonic token bumped by [refresh] so in-flight page fetches from a
  /// replaced pagination stream skip their post-await writes.
  int _fetchGeneration = 0;

  /// Count of page fetches applied since the last first-page emission.
  int _pagesLoaded = 0;

  /// Reactive snapshot of the enriched, grouped notification feed.
  ///
  /// Single source of truth for the feed bloc (list rendering) and the
  /// badge cubit (badge count). Every mutation — [getNotifications],
  /// [refresh], [markAsRead], [markAllAsRead] — updates this subject so
  /// consumers can never diverge.
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

  /// Whether [close] has been called on this repository.
  ///
  /// After an auth flip the provider closes the outgoing instance while a
  /// long-lived consumer (e.g. the refresh coordinator) may still hold it
  /// across an in-flight call. Such callers use this to classify the
  /// resulting [StateError] as expected account-switch noise.
  bool get isClosed => _snapshot.isClosed;

  /// Whether the snapshot currently holds more than the first page.
  ///
  /// Resume-driven liveness triggers consult this to avoid collapsing a
  /// user-visible paginated feed back to page 1. An explicit [refresh]
  /// (pull-to-refresh, page mount) still replaces the snapshot and resets
  /// this to `false`.
  bool get hasPaginatedBeyondFirstPage => _pagesLoaded > 1;

  /// Releases the current page-depth guard after the feed UI is gone.
  ///
  /// While the notifications screen is visible, app-resume refreshes skip
  /// over a paginated snapshot so they do not collapse the list under the
  /// user. Once the feed BLoC closes, no visible list can collapse; resetting
  /// the depth lets out-of-screen liveness refresh the badge again.
  void resetPaginationDepth() {
    _pagesLoaded = _snapshot.value.items.isEmpty ? 0 : 1;
  }

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
  ///
  /// A [refresh] issued while this call is in flight supersedes it: the
  /// late completion neither updates the stored cursor nor touches the
  /// snapshot, and returns the current snapshot unchanged.
  Future<NotificationPage> getNotifications({
    String? cursor,
    String? cursorId,
  }) async => (await _getNotificationsResult(
    cursor: cursor,
    cursorId: cursorId,
  )).page;

  Future<({NotificationPage page, bool applied})> _getNotificationsResult({
    String? cursor,
    String? cursorId,
  }) async {
    final generation = _fetchGeneration;
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
      if (generation != _fetchGeneration) {
        return (page: _snapshot.value, applied: false);
      }

      _lastCursor = response.nextCursor;
      _lastCursorId = response.nextCursorId;

      final items = await _enrichAndGroup(response.notifications);
      if (generation != _fetchGeneration) {
        return (page: _snapshot.value, applied: false);
      }

      final page = NotificationPage(
        items: items,
        unreadCount: response.unreadCount,
        nextCursor: response.nextCursor,
        nextCursorId: response.nextCursorId,
        hasMore: response.hasMore,
      );
      _pagesLoaded = isFirstPage ? 1 : _pagesLoaded + 1;
      _emitSnapshotForPage(page, isFirstPage: isFirstPage);

      if (isFirstPage) {
        unawaited(_persistSnapshot(items));
      }
      return (page: page, applied: true);
    } on Exception catch (e, s) {
      Log.error(
        'Failed to fetch notifications: $e',
        name: 'NotificationRepository.getNotifications',
        category: LogCategory.api,
        error: e,
        stackTrace: s,
      );
      if (isFirstPage && generation == _fetchGeneration) {
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
  ///
  /// Starts a new pagination stream: bumps the fetch generation so any
  /// in-flight page fetch from the previous stream completes without
  /// touching the cursor or snapshot, then clears the stored cursor.
  Future<NotificationPage> refresh() {
    return _refreshResult().then((result) => result.page);
  }

  /// Refreshes notifications and reports whether this call applied a snapshot.
  ///
  /// App-resume refresh coordination uses this to avoid consuming its cooldown
  /// when the refresh was superseded by another first-page fetch before it
  /// could apply.
  Future<bool> refreshApplied() {
    return _refreshResult().then((result) => result.applied);
  }

  Future<({NotificationPage page, bool applied})> _refreshResult() {
    _fetchGeneration++;
    _lastCursor = null;
    _lastCursorId = null;
    return _getNotificationsResult();
  }

  /// Fetches the page after the last one applied to the snapshot.
  ///
  /// Returns `null` without issuing a request when no pagination cursor
  /// is stored — before the first page resolves, or immediately after
  /// [refresh] reset the stream — so a racing load-more can never turn
  /// into a duplicate first-page fetch.
  Future<NotificationPage?> loadNextPage() async {
    if (_lastCursor == null) return null;
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
    final pagesLoadedBefore = _pagesLoaded;
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
      _pagesLoaded = pagesLoadedBefore;
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
    final pagesLoadedBefore = _pagesLoaded;

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
      _pagesLoaded = pagesLoadedBefore;
      _snapshot.add(before);
      rethrow;
    }
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
  ///    [_mergeAppendedVideoGroup] (richer page data folded into the
  ///    existing row, preserving its position).
  /// 2. **`sourceEventIds` overlap** — when an incoming item's
  ///    underlying Nostr event ids overlap the rendered snapshot's set,
  ///    the incoming item is skipped as a cross-page duplicate (the
  ///    server can deliver the same logical Nostr event as distinct
  ///    rows across pages).
  /// 3. **`id` equality fallback** — defensive against the rare case of
  ///    items with empty `sourceEventIds` (server returned a notification
  ///    without `source_event_id`).
  ///
  /// Together these keep a logical event that reappears on a later page
  /// from duplicating its existing row (#4264).
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
  /// row already in the snapshot) without changing the row's position in
  /// the snapshot. Semantics:
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
    final misattributed = <RelayNotification>[];
    final videos = _groupVideoAnchored(
      consolidated,
      profiles,
      videosById,
      misattributed: misattributed,
    );
    final actors = _mapActorAnchored(consolidated, profiles);
    final reclassified = _reclassifyMisattributed(misattributed, profiles);

    final items = <NotificationItem>[...videos, ...actors, ...reclassified]
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
  ///
  /// Notifications whose referenced video is confirmed to belong to a
  /// different user are collected in [misattributed] for reclassification
  /// as actor-anchored notifications (e.g. "liked your comment" instead of
  /// "liked your video"). This fixes #4813.
  List<VideoNotification> _groupVideoAnchored(
    List<RelayNotification> raw,
    Map<String, UserProfile> profiles,
    Map<String, VideoStats> videosById, {
    List<RelayNotification>? misattributed,
  }) {
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
        _logReclassifiedOwnerMismatch(
          notificationId: n.id,
          sourcePubkey: n.sourcePubkey,
          referencedVideoEventId: eventId,
          referencedVideoOwnerPubkey: videosById[eventId]?.pubkey,
        );
        misattributed?.add(n);
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
      final addressableId = _recipientScopedVideoAddressableId(
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
        _buildActorNotification(
          n,
          type: mapped,
          profiles: profiles,
          commentKind: kind,
        ),
      );
    }
    return result;
  }

  /// Reclassifies video-anchored notifications that were dropped because
  /// the referenced video is owned by a different user.
  ///
  /// Instead of silently dropping these, they are surfaced as
  /// [ActorNotification]s with the correct kind:
  /// - `like` (reaction on someone else's video) → `likeComment`
  ///   ("liked your comment")
  /// - `comment` (reply on someone else's video) → `reply`
  ///   ("replied to your comment")
  /// - `repost` remains dropped — a repost of someone else's video should
  ///   not notify the commenter.
  ///
  /// Fixes #4813: user sees "liked your video" / "commented on your video"
  /// for interactions that are actually on their comments on other users'
  /// videos.
  List<ActorNotification> _reclassifyMisattributed(
    List<RelayNotification> misattributed,
    Map<String, UserProfile> profiles,
  ) {
    final result = <ActorNotification>[];
    for (final n in misattributed) {
      final originalKind = _mapNotificationKind(n);
      final reclassifiedKind = _reclassifiedMisattributedKind(originalKind);
      if (reclassifiedKind == null) continue;
      result.add(
        _buildActorNotification(
          n,
          type: reclassifiedKind,
          profiles: profiles,
          targetEventId: _reclassifiedMisattributedTargetEventId(
            reclassifiedKind,
            n,
          ),
        ),
      );
    }
    return result;
  }

  ActorNotification _buildActorNotification(
    RelayNotification notification, {
    required NotificationKind type,
    required Map<String, UserProfile> profiles,
    NotificationKind? commentKind,
    String? targetEventId,
  }) {
    return ActorNotification(
      id: notification.dedupeKey,
      type: type,
      actor: _buildActor(notification.sourcePubkey, profiles),
      timestamp: notification.createdAt,
      isRead: notification.read,
      commentText: _truncateComment(notification.content, commentKind ?? type),
      targetEventId: targetEventId ?? _actorTargetEventId(type, notification),
      sourceEventIds: notification.sourceEventId.isNotEmpty
          ? [notification.sourceEventId]
          : const [],
      notificationIds: notification.dedupeKey.isNotEmpty
          ? [notification.dedupeKey]
          : const [],
      videoAddressableId: _actorVideoAddressableId(type, notification),
    );
  }

  static NotificationKind? _reclassifiedMisattributedKind(
    NotificationKind originalKind,
  ) => switch (originalKind) {
    NotificationKind.like => NotificationKind.likeComment,
    NotificationKind.comment => NotificationKind.reply,
    // Reposts on foreign videos are not meaningful for the commenter.
    _ => null,
  };

  static String? _reclassifiedMisattributedTargetEventId(
    NotificationKind reclassifiedKind,
    RelayNotification notification,
  ) {
    final targetCommentId = _nonEmpty(notification.targetCommentId);
    if (targetCommentId != null) return targetCommentId;

    // Misattributed rows often carry the foreign video as referencedEventId
    // because FunnelCake included it for navigation context. Without the
    // comment id, keep the standard actor target fallback so taps can still
    // resolve or degrade through the existing navigation path.
    return _actorTargetEventId(reclassifiedKind, notification);
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
  /// Used by the page-load path ([_mapActorAnchored]).
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

  /// Builds the stable NIP-33 addressable route for the video a video-anchored
  /// notification (like/comment/repost) points at, always scoped to
  /// [_userPubkey], or null when no usable d-tag is available.
  ///
  /// Video-anchored notifications are structurally about the recipient's own
  /// video; a confirmed *different* owner is reclassified to an actor row
  /// upstream ([_groupVideoAnchored] / #4920) before this is reached. So
  /// ownership here is either confirmed-recipient or unconfirmable (a metadata
  /// miss: stale/edited event id, fetch failure, or a comment with an empty
  /// `referenced_event_id`). In both cases we synthesize the route rather than
  /// dropping to the raw, often-stale `referencedEventId` — which is the #4730
  /// broken-link gap: once the recipient edits a video, its old event id no
  /// longer resolves, so the stable route is the only thing that reopens it.
  ///
  /// Safety bound (unchanged from #4730): the pubkey is pinned to
  /// [_userPubkey], so a wrong/stale d-tag can only ever surface the
  /// recipient's *own* (or a non-existent) video — never another creator's.
  /// The relaxation is purely *when* to synthesize (now also on a metadata
  /// miss), not *whose* video the route can address. Tradeoff: a misattributed
  /// notification whose ownership the metadata fetch happened to miss now
  /// resolves to the recipient's d-tag match (or not-found) instead of the
  /// other creator's event id. The route resolver preserves this bound by
  /// validating addressable candidates before cache or REST hits can satisfy
  /// the coordinate.
  ///
  /// Prefers the authoritative `VideoStats` d-tag over the payload [dTag] so a
  /// `referenced_video` block disagreeing with `referenced_event_id` cannot
  /// build a mismatched route.
  String? _recipientScopedVideoAddressableId({
    required String? dTag,
    required VideoStats? video,
  }) {
    // Defensive local invariant: metadata that resolves and names a different
    // owner never yields a recipient-scoped route. Unreachable via
    // _groupVideoAnchored (those are reclassified to actor rows, #4920).
    if (video != null && video.pubkey != _userPubkey) return null;
    final resolvedDTag = _nonEmpty(video?.dTag) ?? _nonEmpty(dTag);
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
  /// Used by the page-load path ([_mapActorAnchored]).
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

  void _logReclassifiedOwnerMismatch({
    required String notificationId,
    required String sourcePubkey,
    required String referencedVideoEventId,
    required String? referencedVideoOwnerPubkey,
  }) {
    Log.info(
      'Reclassifying misattributed video notification as actor-anchored: '
      'notificationId=$notificationId '
      'sourcePubkey=$sourcePubkey '
      'referencedVideoEventId=$referencedVideoEventId '
      'referencedVideoOwnerPubkey=${referencedVideoOwnerPubkey ?? 'unknown'} '
      'currentUserPubkey=$_userPubkey',
      name: 'NotificationRepository',
      category: LogCategory.api,
    );
  }

  /// Consolidates follow notifications — keeps the most recent per pubkey.
  ///
  /// Kind 3 (contact list) is a replaceable event: a single follower can
  /// produce several follow notifications over time (re-publishes).
  /// Collapsing them to one row per `sourcePubkey` keeps the Follows tab
  /// from showing the same person repeatedly.
  ///
  /// The surviving row must carry the *latest* `createdAt`, not the
  /// earliest. The feed sorts newest-first and paginates, so stamping a
  /// recent follow with a stale timestamp sinks it below older
  /// notifications — potentially off the first page entirely, which
  /// surfaces as an empty "Follows" tab even though the follow exists.
  List<RelayNotification> _consolidateFollows(List<RelayNotification> raw) {
    final followsByPubkey = <String, RelayNotification>{};
    final result = <RelayNotification>[];

    for (final n in raw) {
      final kind = _mapNotificationKind(n);
      if (kind == NotificationKind.follow) {
        final existing = followsByPubkey[n.sourcePubkey];
        if (existing == null || n.createdAt.isAfter(existing.createdAt)) {
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
