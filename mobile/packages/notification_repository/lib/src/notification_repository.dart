// ABOUTME: Repository that fetches raw notifications from FunnelCake,
// ABOUTME: enriches them with profile data, groups likes by video,
// ABOUTME: consolidates follow duplicates, and returns NotificationItems.

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
/// 3. Group likes by referenced video (2+ becomes [GroupedNotification])
/// 4. Consolidate follow duplicates (keep earliest per source pubkey)
/// 5. Map relay notification types to [NotificationKind]
/// 6. Truncate long comment text
/// 7. Return enriched, grouped [NotificationItem]s
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

      final items = _applyBlockFilter(
        await _enrichAndGroup(response.notifications),
      );

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

  /// Filters notifications from blocked/muted users.
  ///
  /// - [SingleNotification]: removed if actor is blocked.
  /// - [GroupedNotification]: blocked actors stripped; entire notification
  ///   removed if no actors remain.
  List<NotificationItem> _applyBlockFilter(List<NotificationItem> items) {
    final filter = _blockFilter;
    if (filter == null) return items;
    return items
        .map(
          (n) => switch (n) {
            SingleNotification() => filter(n.actor.pubkey) ? null : n,
            GroupedNotification() => () {
              final filtered = n.actors
                  .where((a) => !filter(a.pubkey))
                  .toList();
              if (filtered.isEmpty) return null;
              if (filtered.length == n.actors.length) return n;
              return GroupedNotification(
                id: n.id,
                type: n.type,
                actors: filtered,
                totalCount: filtered.length,
                timestamp: n.timestamp,
                isRead: n.isRead,
                targetEventId: n.targetEventId,
                videoTitle: n.videoTitle,
              );
            }(),
          },
        )
        .whereType<NotificationItem>()
        .toList();
  }

  /// Filters a single real-time notification.
  ///
  /// Returns `null` if the notification should be hidden (all actors blocked).
  /// Use this for WebSocket events that bypass [getNotifications].
  NotificationItem? filterRealtimeNotification(NotificationItem item) {
    final result = _applyBlockFilter([item]);
    return result.isEmpty ? null : result.first;
  }

  /// Enriches raw relay notifications with profile data and groups them.
  Future<List<NotificationItem>> _enrichAndGroup(
    List<RelayNotification> raw,
  ) async {
    if (raw.isEmpty) return [];

    // 1. Collect unique pubkeys and batch-fetch profiles.
    final pubkeys = raw.map((n) => n.sourcePubkey).toSet().toList();

    final profiles = await _profileRepository.fetchBatchProfiles(
      pubkeys: pubkeys,
    );

    // 2. Consolidate follows — keep earliest per source pubkey.
    final consolidated = _consolidateFollows(raw);

    // 3. Separate likes for grouping vs everything else.
    final likes = <RelayNotification>[];
    final others = <RelayNotification>[];

    for (final n in consolidated) {
      final kind = _mapNotificationKind(n);
      if (kind == NotificationKind.like ||
          kind == NotificationKind.likeComment) {
        likes.add(n);
      } else {
        others.add(n);
      }
    }

    // 4. Group likes by referenced event ID.
    final groupedLikes = _groupLikesByTarget(likes, profiles);

    // 5. Map remaining notifications to SingleNotification.
    final singles = others.map((n) {
      final kind = _mapNotificationKind(n);
      final actor = _buildActor(n.sourcePubkey, profiles);
      return SingleNotification(
        id: n.dedupeKey,
        type: kind,
        actor: actor,
        timestamp: n.createdAt,
        isRead: n.read,
        targetEventId: _resolveTargetEventId(n, kind),
        videoTitle: n.referencedVideoTitle,
        commentText: _truncateComment(n.content, kind),
      );
    }).toList();

    // 6. Merge and sort by timestamp descending.
    final items = <NotificationItem>[...groupedLikes, ...singles]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return items;
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

  /// Groups likes by referenced event ID.
  ///
  /// 2+ likes on the same target become a [GroupedNotification].
  /// A single like stays as a [SingleNotification]. The target may be a
  /// video ([NotificationKind.like]) or a comment
  /// ([NotificationKind.likeComment]).
  List<NotificationItem> _groupLikesByTarget(
    List<RelayNotification> likes,
    Map<String, UserProfile> profiles,
  ) {
    final byTarget = <String, List<RelayNotification>>{};

    for (final like in likes) {
      final key = like.referencedEventId ?? like.dedupeKey;
      (byTarget[key] ??= []).add(like);
    }

    final items = <NotificationItem>[];

    for (final entry in byTarget.entries) {
      final group = entry.value;
      // All likes on the same event share the same target kind.
      final kind = _mapNotificationKind(group.first);
      final isVideoLike = kind == NotificationKind.like;
      if (group.length >= 2) {
        // Sort by timestamp descending so newest actors come first.
        group.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final actors = group
            .take(_maxGroupActors)
            .map((n) => _buildActor(n.sourcePubkey, profiles))
            .toList();

        items.add(
          GroupedNotification(
            // Stable ID based on the target, not the newest liker.
            id: 'group_like_${entry.key}',
            type: kind,
            actors: actors,
            totalCount: group.length,
            timestamp: group.first.createdAt,
            isRead: group.every((n) => n.read),
            targetEventId: entry.key,
            videoTitle: isVideoLike ? group.first.referencedVideoTitle : null,
          ),
        );
      } else {
        final n = group.first;
        items.add(
          SingleNotification(
            id: n.dedupeKey,
            type: kind,
            actor: _buildActor(n.sourcePubkey, profiles),
            timestamp: n.createdAt,
            isRead: n.read,
            targetEventId: n.referencedEventId,
            videoTitle: isVideoLike ? n.referencedVideoTitle : null,
          ),
        );
      }
    }

    return items;
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

  /// Resolves the navigation target for a notification.
  ///
  /// Mentions sometimes arrive with no `referenced_event_id` (e.g. a mention
  /// inside a NIP-22 comment). Fall back to the source event so taps still
  /// land on the post — the UI's resolver walks `E` / `e` tags back to the
  /// root video. Without this, mention taps route to the mentioner's
  /// profile (#3168).
  static String? _resolveTargetEventId(
    RelayNotification n,
    NotificationKind kind,
  ) {
    if (kind == NotificationKind.mention) {
      final source = n.sourceEventId;
      return n.referencedEventId ?? (source.isEmpty ? null : source);
    }
    return n.referencedEventId;
  }

  /// Maps a relay notification type string + source kind to
  /// [NotificationKind].
  ///
  /// Likes (and zaps) on a non-video target — typically a kind 1111
  /// comment — map to [NotificationKind.likeComment] so the UI can
  /// render "liked your comment" instead of "liked your video".
  static NotificationKind _mapNotificationKind(RelayNotification n) {
    final reaction = switch (n.notificationType) {
      'reaction' || 'zap' => true,
      _ => n.sourceKind == 7,
    };
    if (reaction) {
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
