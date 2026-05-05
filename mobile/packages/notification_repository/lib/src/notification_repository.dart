// ABOUTME: Repository that fetches raw notifications from FunnelCake,
// ABOUTME: enriches them with profile + video metadata, groups video-anchored
// ABOUTME: notifications by (referencedEventId, kind), and maps actor-anchored
// ABOUTME: notifications.

import 'dart:developer' as developer;

import 'package:db_client/db_client.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:notification_repository/src/blocked_notification_filter.dart';
import 'package:notification_repository/src/notification_page.dart';
import 'package:profile_repository/profile_repository.dart';

/// Maximum length for comment preview text before truncation.
const _maxCommentLength = 50;

/// Maximum number of actor avatars shown in a grouped notification.
const _maxGroupActors = 3;

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
    NostrClient? nostrClient,
    BlockedNotificationFilter? blockFilter,
    Future<Map<String, String>> Function(String url, String method)?
    authHeadersProvider,
  }) : _funnelcakeApiClient = funnelcakeApiClient,
       _profileRepository = profileRepository,
       _notificationsDao = notificationsDao,
       _userPubkey = userPubkey,
       _nostrClient = nostrClient,
       _blockFilter = blockFilter,
       _authHeadersProvider = authHeadersProvider;

  final FunnelcakeApiClient _funnelcakeApiClient;
  final ProfileRepository _profileRepository;
  final NotificationsDao _notificationsDao;
  final String _userPubkey;

  /// Reserved for future WebSocket real-time support.
  // ignore: unused_field
  final NostrClient? _nostrClient;
  final BlockedNotificationFilter? _blockFilter;
  final Future<Map<String, String>> Function(String url, String method)?
  _authHeadersProvider;

  /// Last cursor returned by the API, used for pagination.
  String? _lastCursor;

  /// Fetches the next page of notifications.
  ///
  /// Pass [cursor] to override the stored pagination cursor.
  Future<NotificationPage> getNotifications({String? cursor}) async {
    try {
      final effectiveCursor = cursor ?? _lastCursor;
      final requestUrl = _funnelcakeApiClient
          .notificationsUri(
            pubkey: _userPubkey,
            cursor: effectiveCursor,
          )
          .toString();

      final authHeaders = _authHeadersProvider != null
          ? await _authHeadersProvider(
              requestUrl,
              'GET',
            )
          : <String, String>{};

      final response = await _funnelcakeApiClient.getNotifications(
        pubkey: _userPubkey,
        cursor: effectiveCursor,
        requestUri: Uri.parse(requestUrl),
        authHeaders: authHeaders,
      );

      _lastCursor = response.nextCursor;

      final items = await _enrichAndGroup(response.notifications);

      return NotificationPage(
        items: items,
        unreadCount: response.unreadCount,
        nextCursor: response.nextCursor,
        hasMore: response.hasMore,
      );
    } on Exception catch (e, s) {
      developer.log(
        'Failed to fetch notifications: $e',
        name: 'NotificationRepository.getNotifications',
        error: e,
        stackTrace: s,
      );
      return NotificationPage.empty;
    }
  }

  /// Refreshes notifications from the beginning (no cursor).
  Future<NotificationPage> refresh() {
    _lastCursor = null;
    return getNotifications();
  }

  /// Marks specific notifications as read on the server and locally.
  Future<void> markAsRead(List<String> ids) async {
    if (ids.isEmpty) return;

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
  }

  /// Marks all notifications as read on the server and locally.
  Future<void> markAllAsRead() async {
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
    final (profiles, videosById) = await (
      profilesFuture,
      videosFuture,
    ).wait;

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
              return n.copyWith(
                actors: filtered,
                totalCount: filtered.length,
              );
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
      // ActorNotification supports follow/mention/system/likeComment;
      // coerce other kinds (e.g. reply) to system.
      final mapped =
          (kind == NotificationKind.follow ||
              kind == NotificationKind.mention ||
              kind == NotificationKind.system ||
              kind == NotificationKind.likeComment)
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
    final referenced = raw.referencedEventId;
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

    final (profiles, videosById) = await (
      profilesFuture,
      videoFuture,
    ).wait;

    final actor = _buildActor(raw.sourcePubkey, profiles);

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

    final mapped =
        (kind == NotificationKind.follow ||
            kind == NotificationKind.mention ||
            kind == NotificationKind.system ||
            kind == NotificationKind.likeComment)
        ? kind
        : NotificationKind.system;
    return ActorNotification(
      id: raw.dedupeKey,
      type: mapped,
      actor: actor,
      timestamp: raw.createdAt,
      isRead: raw.read,
      commentText: _truncateComment(raw.content, kind),
    );
  }

  /// Returns null if [s] is null or empty, otherwise [s].
  static String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

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
  ActorInfo _buildActor(
    String pubkey,
    Map<String, UserProfile> profiles,
  ) {
    final profile = profiles[pubkey];
    return ActorInfo(
      pubkey: pubkey,
      displayName: profile?.bestDisplayName ?? 'Unknown user',
      pictureUrl: profile?.picture,
    );
  }

  /// Maps a relay notification type string + source kind to
  /// [NotificationKind].
  ///
  /// Likes (and zaps) on a non-video target — typically a kind 1111
  /// comment — map to [NotificationKind.likeComment] so the UI can
  /// render "liked your comment" instead of "liked your video".
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
    return switch (n.notificationType) {
      'reply' => NotificationKind.reply,
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
