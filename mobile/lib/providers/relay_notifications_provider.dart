// TODO(notifications-refactor): Remove after migration is verified
// ABOUTME: Riverpod provider for Divine Relay notifications API with pagination
// ABOUTME: Combines REST API for initial load/pagination with profile enrichment

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/notification_model_converter.dart';
import 'package:openvine/services/relay_notification_api_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/relay_url_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'relay_notifications_provider.g.dart';

/// State for the notifications feed
@immutable
class NotificationFeedState {
  const NotificationFeedState({
    required this.notifications,
    this.unreadCount = 0,
    this.hasMoreContent = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.isInitialLoad = true,
    this.error,
    this.lastUpdated,
  });

  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool hasMoreContent;
  final bool isLoadingMore;
  final bool isRefreshing;
  final bool isInitialLoad;
  final String? error;
  final DateTime? lastUpdated;

  NotificationFeedState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? hasMoreContent,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? isInitialLoad,
    String? error,
    DateTime? lastUpdated,
  }) {
    return NotificationFeedState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isInitialLoad: isInitialLoad ?? this.isInitialLoad,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  static const empty = NotificationFeedState(notifications: []);
}

/// Provider for relay-based notifications with REST API pagination
///
/// Uses Divine Relay's notifications API for:
/// - Server-side filtering (only events targeting current user)
/// - Cursor-based pagination with has_more
/// - Server-side unread count tracking
/// - Server-side mark-as-read persistence
///
/// Timer lifecycle:
/// - Starts when provider is first watched
/// - Pauses when all listeners detach (ref.onCancel)
/// - Resumes when a new listener attaches (ref.onResume)
/// - Cancels on dispose
@Riverpod()
class RelayNotifications extends _$RelayNotifications {
  // Pagination state
  String? _nextCursor;
  bool _hasMoreFromApi = true;

  // Guard against concurrent refresh/loadMore
  bool _isRefreshing = false;

  /// Minimum items to show before stopping auto-load.
  /// If consolidation reduces items below this, we automatically fetch more.
  static const _minVisibleItems = 10;

  // Auto-refresh timer
  Timer? _autoRefreshTimer;
  static const _autoRefreshInterval = Duration(minutes: 5);

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer(_autoRefreshInterval, () {
      if (!ref.mounted) return;

      // Skip refresh when app is backgrounded to avoid NIP-98 auth
      // attempts while the bunker signer is paused (which would timeout
      // after 60s and fail).
      final backgroundManager = ref.read(backgroundActivityManagerProvider);
      if (backgroundManager.isAppInBackground) {
        Log.debug(
          'RelayNotifications: Auto-refresh skipped (app is backgrounded)',
          name: 'RelayNotificationsProvider',
          category: LogCategory.system,
        );
        // Restart the timer so refresh triggers after app resumes
        _startAutoRefresh();
        return;
      }

      Log.info(
        'RelayNotifications: Auto-refresh triggered',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      refresh();
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  Future<NotificationFeedState> build() async {
    // Reset pagination state at start of build
    _nextCursor = null;
    _hasMoreFromApi = true;

    // Prevent auto-dispose during async operations
    final keepAliveLink = ref.keepAlive();

    Log.info(
      'RelayNotifications: BUILD START',
      name: 'RelayNotificationsProvider',
      category: LogCategory.system,
    );

    // Start timer when provider is first watched or resumed
    ref.onResume(() {
      Log.debug(
        'RelayNotifications: Resuming auto-refresh timer',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      _startAutoRefresh();
    });

    // Pause timer when all listeners detach
    ref.onCancel(() {
      Log.debug(
        'RelayNotifications: Pausing auto-refresh timer (no listeners)',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      _stopAutoRefresh();
    });

    // Clean up timer on dispose
    ref.onDispose(() {
      Log.info(
        'RelayNotifications: BUILD DISPOSED',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      _stopAutoRefresh();
    });

    // Start timer immediately for first build
    _startAutoRefresh();

    // Get current user pubkey
    final authService = ref.read(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;

    if (currentUserPubkey == null || !authService.isAuthenticated) {
      Log.warning(
        'RelayNotifications: User not authenticated',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      keepAliveLink.close();
      return NotificationFeedState.empty;
    }

    // Check if API is available
    final apiService = ref.read(relayNotificationApiServiceProvider);
    if (!apiService.isAvailable) {
      Log.warning(
        'RelayNotifications: API not available',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      keepAliveLink.close();
      return NotificationFeedState.empty;
    }

    // Emit initial loading state
    state = const AsyncData(NotificationFeedState(notifications: []));

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final videoEventService = ref.read(videoEventServiceProvider);
      final result = await _fetchRawNotifications(
        pubkey: currentUserPubkey,
        resetCursor: true,
      );

      if (!ref.mounted || result.notifications.isEmpty) {
        keepAliveLink.close();
        return NotificationFeedState(
          notifications: const [],
          unreadCount: result.unreadCount,
          hasMoreContent: result.hasMore,
          isInitialLoad: false,
          lastUpdated: DateTime.now(),
        );
      }

      final consolidatedNotifications = _consolidateFollowNotifications(
        result.notifications,
      );
      final rawNotifications = _buildNotificationModels(
        consolidatedNotifications,
        videoEventService: videoEventService,
      );
      final initialState = NotificationFeedState(
        notifications: rawNotifications,
        unreadCount: result.unreadCount,
        hasMoreContent: result.hasMore,
        isInitialLoad: false,
        lastUpdated: DateTime.now(),
      );
      state = AsyncData(initialState);
      _scheduleEnrichment(
        consolidatedNotifications,
        profileRepo: profileRepo,
        videoEventService: videoEventService,
      );

      // Log breakdown by type for debugging
      final typeBreakdown = <String, int>{};
      for (final n in rawNotifications) {
        final typeName = n.type.name;
        typeBreakdown[typeName] = (typeBreakdown[typeName] ?? 0) + 1;
      }
      Log.info(
        'RelayNotifications: Loaded ${rawNotifications.length} notifications '
        '(from ${result.notifications.length} raw), '
        'unread: ${result.unreadCount}, hasMore: ${result.hasMore}, '
        'types: $typeBreakdown',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );

      keepAliveLink.close();
      return initialState;
    } catch (e) {
      Log.error(
        'RelayNotifications: Error loading notifications: $e',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      keepAliveLink.close();
      return NotificationFeedState(
        notifications: const [],
        error: e.toString(),
        isInitialLoad: false,
      );
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    final currentState = await future;

    if (!ref.mounted) return;

    // Check both private guard and state for safety against race conditions
    if (_isRefreshing || currentState.isRefreshing) {
      Log.debug(
        'RelayNotifications: loadMore() skipped - refresh in progress',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      return;
    }

    if (currentState.isLoadingMore) {
      Log.debug(
        'RelayNotifications: loadMore() skipped - already loading',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      return;
    }

    if (!currentState.hasMoreContent) {
      Log.debug(
        'RelayNotifications: loadMore() skipped - no more content',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      return;
    }

    // Update state to show loading
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final videoEventService = ref.read(videoEventServiceProvider);
      final authService = ref.read(authServiceProvider);
      final currentUserPubkey = authService.currentPublicKeyHex;

      if (currentUserPubkey == null) {
        if (!ref.mounted) return;
        state = AsyncData(currentState.copyWith(isLoadingMore: false));
        return;
      }

      // Get existing IDs to exclude (ID-level dedup only).
      // Follow pubkeys are NOT excluded here — loadMore lets older follow
      // notifications through so the post-merge consolidation can pick the
      // earliest timestamp across batches.
      final existingIds = currentState.notifications
          .map((n) => n.id.toLowerCase())
          .toSet();

      Log.info(
        'RelayNotifications: Loading more with cursor: $_nextCursor '
        '(have ${currentState.notifications.length} existing)',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );

      final result = await _fetchRawNotifications(
        pubkey: currentUserPubkey,
        excludeIds: existingIds,
      );

      if (!ref.mounted) return;

      if (result.notifications.isEmpty) {
        Log.info(
          'RelayNotifications: No new unique notifications to add',
          name: 'RelayNotificationsProvider',
          category: LogCategory.system,
        );
        state = AsyncData(
          currentState.copyWith(
            hasMoreContent: result.hasMore,
            isLoadingMore: false,
          ),
        );
        return;
      }

      final consolidatedNotifications = _consolidateFollowNotifications(
        result.notifications,
      );
      final rawNew = _buildNotificationModels(
        consolidatedNotifications,
        videoEventService: videoEventService,
      );

      // Merge and consolidate follows across batches — keep earliest per actor.
      // This handles the case where batch 1 had follow_X at T2 (latest Kind 3)
      // and batch 2 has follow_X at T1 (original follow).
      final allNotifications = _consolidateFollowModels(
        [...currentState.notifications, ...rawNew],
      );

      Log.info(
        'RelayNotifications: Loaded ${rawNew.length} more notifications '
        '(total: ${allNotifications.length})',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );

      state = AsyncData(
        currentState.copyWith(
          notifications: allNotifications,
          unreadCount: result.unreadCount,
          hasMoreContent: result.hasMore,
          isLoadingMore: false,
        ),
      );
      _scheduleEnrichment(
        consolidatedNotifications,
        profileRepo: profileRepo,
        videoEventService: videoEventService,
      );
    } catch (e) {
      Log.error(
        'RelayNotifications: Error loading more: $e',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );

      if (!ref.mounted) return;
      final currentState = await future;
      if (!ref.mounted) return;
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
  }

  /// Insert a notification from the WebSocket real-time stream.
  ///
  /// Deduplicates against existing notifications and inserts at the correct
  /// position sorted by timestamp (newest first). Increments unread count
  /// if the notification is unread.
  Future<void> insertFromWebSocket(NotificationModel notification) async {
    final currentState = await future;
    if (!ref.mounted) return;

    // Deduplicate by ID
    if (currentState.notifications.any((n) => n.id == notification.id)) return;

    // Cross-path dedup: REST notifications store the Nostr event ID in
    // metadata['sourceEventId'], while WebSocket notifications use the Nostr
    // event ID as the model ID. Check both directions so the same logical
    // notification isn't shown twice.
    if (currentState.notifications.any(
      (n) => n.metadata?['sourceEventId'] == notification.id,
    )) {
      return;
    }

    // For follows, deduplicate by actor pubkey (Kind 3 republishes entire list)
    if (notification.type == NotificationType.follow &&
        currentState.notifications.any(
          (n) =>
              n.type == NotificationType.follow &&
              n.actorPubkey == notification.actorPubkey,
        )) {
      return;
    }

    // Insert at correct position (sorted by timestamp, newest first)
    final updated = [notification, ...currentState.notifications];
    updated.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    state = AsyncData(
      currentState.copyWith(
        notifications: updated,
        unreadCount: currentState.unreadCount + (notification.isRead ? 0 : 1),
      ),
    );
  }

  /// Refresh notifications from the API.
  ///
  /// Fetches fresh data while preserving existing notifications on screen
  /// until the new data arrives. This prevents a flash of empty state
  /// during pull-to-refresh.
  Future<void> refresh() async {
    Log.info(
      'RelayNotifications: Refreshing',
      name: 'RelayNotificationsProvider',
      category: LogCategory.system,
    );

    // Prevent loadMore from running during refresh - set BEFORE await
    _isRefreshing = true;

    final currentState = await future;

    // Snapshot IDs before the API fetch so we can detect WebSocket insertions
    // that arrive during the fetch window.
    final preRefreshIds = currentState.notifications.map((n) => n.id).toSet();
    if (!ref.mounted) {
      _isRefreshing = false;
      return;
    }

    // Update state to show refreshing (hides load-more indicator in UI)
    state = AsyncData(currentState.copyWith(isRefreshing: true));

    final authService = ref.read(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;

    if (currentUserPubkey == null || !authService.isAuthenticated) {
      _isRefreshing = false;
      return;
    }

    final apiService = ref.read(relayNotificationApiServiceProvider);
    if (!apiService.isAvailable) {
      _isRefreshing = false;
      return;
    }

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final videoEventService = ref.read(videoEventServiceProvider);
      final result = await _fetchRawNotifications(
        pubkey: currentUserPubkey,
        resetCursor: true,
      );

      if (!ref.mounted) return;

      final consolidatedNotifications = _consolidateFollowNotifications(
        result.notifications,
      );
      final rawNotifications = _buildNotificationModels(
        consolidatedNotifications,
        videoEventService: videoEventService,
      );
      // Re-read the live state to find WebSocket notifications inserted during
      // the API fetch window. Only notifications absent from the pre-refresh
      // snapshot are WebSocket insertions — old API data is replaced by the
      // fresh API response.
      final liveState = state.requireValue;
      final wsInsertions = liveState.notifications
          .where((n) => !preRefreshIds.contains(n.id))
          .toList();

      // Deduplicate WebSocket insertions against the API response by ID and
      // sourceEventId (cross-path: REST server ID vs WebSocket Nostr event ID).
      final apiIds = rawNotifications.map((n) => n.id).toSet();
      final apiSourceIds = rawNotifications
          .map((n) => n.metadata?['sourceEventId']?.toString())
          .whereType<String>()
          .toSet();

      final webSocketOnly = wsInsertions.where((ws) {
        if (apiIds.contains(ws.id)) return false;
        if (apiSourceIds.contains(ws.id)) return false;
        return true;
      }).toList();

      final merged = _consolidateFollowModels(
        [...rawNotifications, ...webSocketOnly],
      );

      Log.info(
        'RelayNotifications: Refreshed with '
        '${rawNotifications.length} API notifications '
        '(from ${result.notifications.length} raw), '
        '${webSocketOnly.length} WebSocket-only preserved, '
        'total: ${merged.length}, '
        'unread: ${result.unreadCount}, hasMore: ${result.hasMore}',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );

      state = AsyncData(
        currentState.copyWith(
          notifications: merged,
          unreadCount: result.unreadCount,
          hasMoreContent: result.hasMore,
          isInitialLoad: false,
          isRefreshing: false,
          lastUpdated: DateTime.now(),
        ),
      );
      _scheduleEnrichment(
        consolidatedNotifications,
        profileRepo: profileRepo,
        videoEventService: videoEventService,
      );
    } catch (e) {
      Log.error(
        'RelayNotifications: Error refreshing: $e',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      // Keep existing data on error
      if (ref.mounted) {
        state = AsyncData(
          currentState.copyWith(isRefreshing: false, error: e.toString()),
        );
      }
    } finally {
      _isRefreshing = false;
    }

    // Restart auto-refresh timer
    _startAutoRefresh();
  }

  /// Mark a single notification as read
  ///
  /// If [notificationId] is empty (e.g., the API returned a notification
  /// without an id field), this method performs only the local optimistic
  /// update and skips the API call to avoid sending an invalid payload.
  Future<void> markAsRead(String notificationId) async {
    final currentState = await future;
    if (!ref.mounted) return;

    // Skip API call for empty IDs but still allow local update
    final shouldPersistToApi = notificationId.isNotEmpty;

    // Optimistic update
    final updatedNotifications = currentState.notifications.map((n) {
      if (n.id == notificationId && !n.isRead) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    final newUnreadCount = currentState.unreadCount > 0
        ? currentState.unreadCount - 1
        : 0;

    state = AsyncData(
      currentState.copyWith(
        notifications: updatedNotifications,
        unreadCount: newUnreadCount,
      ),
    );

    // Skip API call for empty IDs - the server requires valid notification IDs
    if (!shouldPersistToApi) {
      Log.debug(
        'RelayNotifications: Skipping markAsRead API call - no valid notification ID',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      return;
    }

    // Persist to server
    try {
      final authService = ref.read(authServiceProvider);
      final currentUserPubkey = authService.currentPublicKeyHex;

      if (currentUserPubkey != null) {
        final apiService = ref.read(relayNotificationApiServiceProvider);
        await apiService.markAsRead(
          pubkey: currentUserPubkey,
          notificationIds: [notificationId],
        );
      }
    } catch (e) {
      Log.error(
        'RelayNotifications: Error marking as read: $e',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      // Don't revert optimistic update - server will sync on next refresh
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final currentState = await future;
    if (!ref.mounted) return;

    // Optimistic update
    final updatedNotifications = currentState.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();

    state = AsyncData(
      currentState.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      ),
    );

    // Persist to server
    try {
      final authService = ref.read(authServiceProvider);
      final currentUserPubkey = authService.currentPublicKeyHex;

      if (currentUserPubkey != null) {
        final apiService = ref.read(relayNotificationApiServiceProvider);
        await apiService.markAsRead(pubkey: currentUserPubkey);

        Log.info(
          'RelayNotifications: Marked all as read',
          name: 'RelayNotificationsProvider',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'RelayNotifications: Error marking all as read: $e',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
    }
  }

  /// Result type for _fetchRawNotifications
  ({List<RelayNotification> notifications, int unreadCount, bool hasMore})
  _makeFetchResult(
    List<RelayNotification> notifications,
    int unreadCount,
    bool hasMore,
  ) => (
    notifications: notifications,
    unreadCount: unreadCount,
    hasMore: hasMore,
  );

  /// Fetch raw notifications until we have at least [_minVisibleItems] after consolidation.
  ///
  /// Handles pagination, deduplication, and auto-loading in a single place.
  /// Used by build(), refresh(), and loadMore().
  Future<
    ({List<RelayNotification> notifications, int unreadCount, bool hasMore})
  >
  _fetchRawNotifications({
    required String pubkey,
    Set<String>? excludeIds,
    bool resetCursor = false,
  }) async {
    final apiService = ref.read(relayNotificationApiServiceProvider);

    if (resetCursor) {
      _nextCursor = null;
      _hasMoreFromApi = true;
    }

    final allRawNotifications = <RelayNotification>[];
    final mutableExcludeIds = excludeIds?.toSet() ?? <String>{};
    var unreadCount = 0;

    // Initial fetch
    final response = await apiService.getNotifications(
      pubkey: pubkey,
      before: _nextCursor,
    );

    if (!ref.mounted) {
      return _makeFetchResult([], 0, false);
    }

    _nextCursor = response.nextCursor;
    _hasMoreFromApi = response.hasMore;
    unreadCount = response.unreadCount;

    // Dedupe initial batch by notification ID.
    // Follow notifications are NOT deduped by pubkey here — that is handled
    // by _consolidateFollowNotifications (keeps earliest per source pubkey).
    for (final n in response.notifications) {
      final id = n.dedupeKey.toLowerCase();
      if (mutableExcludeIds.contains(id)) continue;

      mutableExcludeIds.add(id);
      allRawNotifications.add(n);
    }

    // Keep fetching until we have enough unique items after consolidation
    var consolidatedCount = _consolidateFollowNotifications(
      allRawNotifications,
    ).length;

    while (consolidatedCount < _minVisibleItems &&
        _hasMoreFromApi &&
        ref.mounted) {
      Log.debug(
        'RelayNotifications: Only $consolidatedCount unique items after '
        'consolidation (have ${allRawNotifications.length} raw), '
        'fetching more (need $_minVisibleItems)',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );

      final moreResponse = await apiService.getNotifications(
        pubkey: pubkey,
        before: _nextCursor,
      );

      if (!ref.mounted) {
        return _makeFetchResult([], 0, false);
      }

      _nextCursor = moreResponse.nextCursor;
      _hasMoreFromApi = moreResponse.hasMore;

      if (moreResponse.notifications.isEmpty) break;

      // Dedupe new batch by notification ID only
      var addedAny = false;
      for (final n in moreResponse.notifications) {
        final id = n.dedupeKey.toLowerCase();
        if (mutableExcludeIds.contains(id)) continue;

        mutableExcludeIds.add(id);
        allRawNotifications.add(n);
        addedAny = true;
      }

      if (!addedAny && !_hasMoreFromApi) break;

      consolidatedCount = _consolidateFollowNotifications(
        allRawNotifications,
      ).length;
    }

    return _makeFetchResult(allRawNotifications, unreadCount, _hasMoreFromApi);
  }

  /// Enrich RelayNotification objects with profile data
  Future<List<NotificationModel>> _enrichNotifications(
    List<RelayNotification> relayNotifications, {
    required ProfileRepository? profileRepo,
    required VideoEventService videoEventService,
  }) async {
    if (relayNotifications.isEmpty) return [];

    final rawPubkeys = relayNotifications.map((n) => n.sourcePubkey).toList();
    final uniqueRawPubkeys = rawPubkeys.toSet();
    Log.debug(
      'RelayNotifications: _enrichNotifications INPUT - '
      '${relayNotifications.length} notifications, '
      '${uniqueRawPubkeys.length} unique pubkeys, '
      'first 5 pubkeys: ${rawPubkeys.take(5).map((p) => p.isEmpty ? "(empty)" : p.substring(0, 8)).join(", ")}',
      name: 'RelayNotificationsProvider',
      category: LogCategory.system,
    );

    // Batch fetch profiles for all unique pubkeys
    final pubkeys = relayNotifications
        .map((n) => n.sourcePubkey)
        .toSet()
        .toList();

    final profiles =
        await profileRepo?.fetchBatchProfiles(pubkeys: pubkeys) ??
        <String, UserProfile>{};

    final profilesByPubkey = <String, UserProfile?>{
      for (final pubkey in pubkeys) pubkey: profiles[pubkey],
    };

    final enriched = _buildNotificationModels(
      relayNotifications,
      videoEventService: videoEventService,
      profilesByPubkey: profilesByPubkey,
    );

    Log.debug(
      'RelayNotifications: _enrichNotifications OUTPUT - '
      '${enriched.length} notifications after enrichment',
      name: 'RelayNotificationsProvider',
      category: LogCategory.system,
    );

    return enriched;
  }

  List<NotificationModel> _buildNotificationModels(
    List<RelayNotification> relayNotifications, {
    required VideoEventService videoEventService,
    Map<String, UserProfile?> profilesByPubkey = const {},
  }) {
    if (relayNotifications.isEmpty) return const [];

    return relayNotifications.map((relay) {
      final profile = profilesByPubkey[relay.sourcePubkey];

      String? videoUrl;
      String? videoThumbnail;
      if (relay.referencedEventId != null) {
        final video = videoEventService.getVideoEventById(
          relay.referencedEventId!,
        );
        videoUrl = video?.videoUrl;
        videoThumbnail = video?.thumbnailUrl;
      }

      return notificationModelFromRelayApi(
        relay,
        actorName: profile?.bestDisplayName,
        actorPictureUrl: profile?.picture,
        targetVideoUrl: videoUrl,
        targetVideoThumbnail: videoThumbnail,
      );
    }).toList();
  }

  void _scheduleEnrichment(
    List<RelayNotification> relayNotifications, {
    required ProfileRepository? profileRepo,
    required VideoEventService videoEventService,
  }) {
    if (relayNotifications.isEmpty) return;

    unawaited(() async {
      final enrichedNotifications = await _enrichNotifications(
        relayNotifications,
        profileRepo: profileRepo,
        videoEventService: videoEventService,
      );

      if (!ref.mounted || enrichedNotifications.isEmpty) return;

      final currentState = state.whenOrNull(data: (value) => value);
      if (currentState == null) return;

      state = AsyncData(
        currentState.copyWith(
          notifications: _mergeEnrichedNotifications(
            currentState.notifications,
            enrichedNotifications,
          ),
        ),
      );
    }());
  }

  List<NotificationModel> _mergeEnrichedNotifications(
    List<NotificationModel> currentNotifications,
    List<NotificationModel> enrichedNotifications,
  ) {
    // Build lookup by a stable key. When [id] is empty (API didn't provide
    // one), fall back to actorPubkey+timestamp so each notification still
    // gets its own enriched profile data.
    String stableKey(NotificationModel n) => n.id.isNotEmpty
        ? n.id
        : '${n.actorPubkey}_${n.timestamp.microsecondsSinceEpoch}';

    final enrichedByKey = {
      for (final notification in enrichedNotifications)
        stableKey(notification): notification,
    };

    return currentNotifications.map((current) {
      final enriched = enrichedByKey[stableKey(current)];
      if (enriched == null) return current;

      return current.copyWith(
        actorName: enriched.actorName,
        actorPictureUrl: enriched.actorPictureUrl,
        message: enriched.message,
        targetEventId: enriched.targetEventId,
        targetVideoUrl: enriched.targetVideoUrl,
        targetVideoThumbnail: enriched.targetVideoThumbnail,
        metadata: enriched.metadata,
      );
    }).toList();
  }

  /// Consolidate follow/unfollow notifications to show only the most recent per user
  ///
  /// When a user follows/unfollows multiple times, we only want to show
  /// the most recent action to avoid cluttering the notification list.
  List<RelayNotification> _consolidateFollowNotifications(
    List<RelayNotification> notifications,
  ) {
    // Separate follow notifications from others
    final followNotifications = <RelayNotification>[];
    final otherNotifications = <RelayNotification>[];

    for (final notification in notifications) {
      if (notification.notificationType.toLowerCase() == 'follow') {
        followNotifications.add(notification);
      } else {
        otherNotifications.add(notification);
      }
    }

    // Debug: Log type breakdown before consolidation
    Log.debug(
      'RelayNotifications: _consolidateFollowNotifications - '
      'total: ${notifications.length}, '
      'follows: ${followNotifications.length}, '
      'other: ${otherNotifications.length}, '
      'unique follow pubkeys: ${followNotifications.map((f) => f.sourcePubkey).toSet().length}',
      name: 'RelayNotificationsProvider',
      category: LogCategory.system,
    );

    // Keep the earliest (original) follow notification per source pubkey.
    // Kind 3 republishes the full contact list on every change, so the latest
    // event timestamp reflects when the follower's list last changed, NOT when
    // they originally followed this user.
    final earliestFollowByPubkey = <String, RelayNotification>{};
    for (final follow in followNotifications) {
      final existing = earliestFollowByPubkey[follow.sourcePubkey];
      if (existing == null || follow.createdAt.isBefore(existing.createdAt)) {
        earliestFollowByPubkey[follow.sourcePubkey] = follow;
      }
    }

    final consolidatedFollows = earliestFollowByPubkey.values.toList();

    if (followNotifications.length != consolidatedFollows.length) {
      Log.info(
        'Consolidated ${followNotifications.length} follow notifications to '
        '${consolidatedFollows.length} (removed ${followNotifications.length - consolidatedFollows.length} duplicates)',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
    }

    // Combine and sort by timestamp (newest first)
    final result = [...otherNotifications, ...consolidatedFollows];
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return result;
  }

  /// Consolidate follow NotificationModels across batches, keeping the
  /// earliest follow per actor pubkey.  Non-follow notifications pass through
  /// unchanged.  Used after merging existing + new notifications in loadMore.
  List<NotificationModel> _consolidateFollowModels(
    List<NotificationModel> notifications,
  ) {
    final earliestFollowByActor = <String, NotificationModel>{};
    final nonFollows = <NotificationModel>[];

    for (final n in notifications) {
      if (n.type != NotificationType.follow) {
        nonFollows.add(n);
        continue;
      }
      final existing = earliestFollowByActor[n.actorPubkey];
      if (existing == null || n.timestamp.isBefore(existing.timestamp)) {
        earliestFollowByActor[n.actorPubkey] = n;
      }
    }

    final result = [...nonFollows, ...earliestFollowByActor.values];
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }
}

/// Provider for relay notification API service
@riverpod
RelayNotificationApiService relayNotificationApiService(Ref ref) {
  final environmentConfig = ref.watch(currentEnvironmentProvider);
  final nostrService = ref.watch(nostrServiceProvider);
  // Fallback must use the relay URL, not apiBaseUrl (Fastly CDN).
  // The notification API is served by the relay server itself.
  final baseUrl = resolvePinnedApiBaseUrlFromRelays(
    configuredRelays: nostrService.configuredRelays,
    fallbackBaseUrl: relayWsToHttpBase(environmentConfig.relayUrl),
  );
  final nip98AuthService = ref.watch(nip98AuthServiceProvider);

  return RelayNotificationApiService(
    baseUrl: baseUrl,
    nip98AuthService: nip98AuthService,
  );
}

/// Provider to get current unread notification count
@riverpod
int relayNotificationUnreadCount(Ref ref) {
  final asyncState = ref.watch(relayNotificationsProvider);
  return asyncState.whenOrNull(data: (state) => state.unreadCount) ?? 0;
}

/// Provider to check if notifications are loading
@riverpod
bool relayNotificationsLoading(Ref ref) {
  final asyncState = ref.watch(relayNotificationsProvider);
  if (asyncState.isLoading) return true;

  final state = asyncState.whenOrNull(data: (s) => s);
  if (state == null) return false;

  return state.isLoadingMore || state.isInitialLoad;
}

/// Provider to get notifications filtered by type.
///
/// Results are sorted by timestamp (newest first).
@riverpod
List<NotificationModel> relayNotificationsByType(
  Ref ref,
  NotificationType? type,
) {
  final asyncState = ref.watch(relayNotificationsProvider);
  final notifications =
      asyncState.whenOrNull(data: (state) => state.notifications) ?? [];

  if (type == null) return notifications;

  // Filter and sort to ensure chronological order
  final filtered = notifications.where((n) => n.type == type).toList();
  filtered.sort((a, b) {
    final timeCompare = b.timestamp.compareTo(a.timestamp);
    if (timeCompare != 0) return timeCompare;
    return a.id.compareTo(b.id);
  });
  return filtered;
}
