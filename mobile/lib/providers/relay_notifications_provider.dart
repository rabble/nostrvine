// ABOUTME: Riverpod provider for Divine Relay notifications API with pagination
// ABOUTME: Combines REST API for initial load/pagination with profile enrichment

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/notification_model_converter.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/services/relay_notification_api_service.dart';
import 'package:openvine/utils/unified_logger.dart';
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
    this.isInitialLoad = true,
    this.error,
    this.lastUpdated,
  });

  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool hasMoreContent;
  final bool isLoadingMore;
  final bool isInitialLoad;
  final String? error;
  final DateTime? lastUpdated;

  NotificationFeedState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? hasMoreContent,
    bool? isLoadingMore,
    bool? isInitialLoad,
    String? error,
    DateTime? lastUpdated,
  }) {
    return NotificationFeedState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMoreContent: hasMoreContent ?? this.hasMoreContent,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
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
@Riverpod(keepAlive: false)
class RelayNotifications extends _$RelayNotifications {
  // Pagination state
  String? _nextCursor;
  bool _hasMoreFromApi = true;

  // Auto-refresh timer
  Timer? _autoRefreshTimer;
  static const _autoRefreshInterval = Duration(minutes: 5);

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer(_autoRefreshInterval, () {
      Log.info(
        'RelayNotifications: Auto-refresh triggered',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      if (ref.mounted) {
        refresh();
      }
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
    state = const AsyncData(
      NotificationFeedState(notifications: [], isInitialLoad: true),
    );

    try {
      // Fetch initial notifications from REST API
      final response = await apiService.getNotifications(
        pubkey: currentUserPubkey,
        limit: 50,
      );

      if (!ref.mounted) {
        keepAliveLink.close();
        return NotificationFeedState.empty;
      }

      // Update pagination state
      _nextCursor = response.nextCursor;
      _hasMoreFromApi = response.hasMore;

      // Enrich notifications with profile data
      final enrichedNotifications = await _enrichNotifications(
        response.notifications,
      );

      if (!ref.mounted) {
        keepAliveLink.close();
        return NotificationFeedState.empty;
      }

      // Log breakdown by type for debugging
      final typeBreakdown = <String, int>{};
      for (final n in enrichedNotifications) {
        final typeName = n.type.name;
        typeBreakdown[typeName] = (typeBreakdown[typeName] ?? 0) + 1;
      }
      Log.info(
        'RelayNotifications: Loaded ${enrichedNotifications.length} notifications, '
        'unread: ${response.unreadCount}, hasMore: ${response.hasMore}, '
        'types: $typeBreakdown',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );

      keepAliveLink.close();
      return NotificationFeedState(
        notifications: enrichedNotifications,
        unreadCount: response.unreadCount,
        hasMoreContent: response.hasMore,
        isLoadingMore: false,
        isInitialLoad: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      Log.error(
        'RelayNotifications: Error loading notifications: $e',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      keepAliveLink.close();
      return NotificationFeedState(
        notifications: [],
        error: e.toString(),
        isInitialLoad: false,
      );
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    final currentState = await future;

    if (!ref.mounted) return;

    if (currentState.isLoadingMore) {
      Log.debug(
        'RelayNotifications: loadMore() skipped - already loading',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      return;
    }

    if (!_hasMoreFromApi) {
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
      final authService = ref.read(authServiceProvider);
      final currentUserPubkey = authService.currentPublicKeyHex;

      if (currentUserPubkey == null) {
        if (!ref.mounted) return;
        state = AsyncData(currentState.copyWith(isLoadingMore: false));
        return;
      }

      final apiService = ref.read(relayNotificationApiServiceProvider);

      Log.info(
        'RelayNotifications: Loading more with cursor: $_nextCursor',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );

      final response = await apiService.getNotifications(
        pubkey: currentUserPubkey,
        limit: 50,
        before: _nextCursor,
      );

      if (!ref.mounted) return;

      // Deduplicate (case-insensitive for Nostr IDs)
      final existingIds = currentState.notifications
          .map((n) => n.id.toLowerCase())
          .toSet();
      final newRelayNotifications = response.notifications
          .where((n) => !existingIds.contains(n.id.toLowerCase()))
          .toList();

      // Enrich with profile data
      final enrichedNew = await _enrichNotifications(newRelayNotifications);

      if (!ref.mounted) return;

      // Update pagination state
      _nextCursor = response.nextCursor;
      _hasMoreFromApi = response.hasMore;

      if (enrichedNew.isNotEmpty) {
        final allNotifications = [
          ...currentState.notifications,
          ...enrichedNew,
        ];
        Log.info(
          'RelayNotifications: Loaded ${enrichedNew.length} more notifications '
          '(total: ${allNotifications.length})',
          name: 'RelayNotificationsProvider',
          category: LogCategory.system,
        );

        state = AsyncData(
          currentState.copyWith(
            notifications: allNotifications,
            unreadCount: response.unreadCount,
            hasMoreContent: response.hasMore,
            isLoadingMore: false,
          ),
        );
      } else {
        Log.info(
          'RelayNotifications: All returned notifications already in state',
          name: 'RelayNotificationsProvider',
          category: LogCategory.system,
        );
        state = AsyncData(
          currentState.copyWith(
            hasMoreContent: response.hasMore,
            isLoadingMore: false,
          ),
        );
      }
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

    // Deduplicate
    if (currentState.notifications.any((n) => n.id == notification.id)) return;

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

    final currentState = await future;
    if (!ref.mounted) return;

    // Reset pagination state
    _nextCursor = null;
    _hasMoreFromApi = true;

    final authService = ref.read(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;

    if (currentUserPubkey == null || !authService.isAuthenticated) return;

    final apiService = ref.read(relayNotificationApiServiceProvider);
    if (!apiService.isAvailable) return;

    try {
      final response = await apiService.getNotifications(
        pubkey: currentUserPubkey,
        limit: 50,
      );

      if (!ref.mounted) return;

      _nextCursor = response.nextCursor;
      _hasMoreFromApi = response.hasMore;

      final enrichedNotifications = await _enrichNotifications(
        response.notifications,
      );

      if (!ref.mounted) return;

      Log.info(
        'RelayNotifications: Refreshed with '
        '${enrichedNotifications.length} notifications, '
        'unread: ${response.unreadCount}, hasMore: ${response.hasMore}',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );

      state = AsyncData(
        NotificationFeedState(
          notifications: enrichedNotifications,
          unreadCount: response.unreadCount,
          hasMoreContent: response.hasMore,
          isInitialLoad: false,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      Log.error(
        'RelayNotifications: Error refreshing: $e',
        name: 'RelayNotificationsProvider',
        category: LogCategory.system,
      );
      // Keep existing data on error
      if (ref.mounted) {
        state = AsyncData(currentState.copyWith(error: e.toString()));
      }
    }

    // Restart auto-refresh timer
    _startAutoRefresh();
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    final currentState = await future;
    if (!ref.mounted) return;

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

  /// Enrich RelayNotification objects with profile data
  Future<List<NotificationModel>> _enrichNotifications(
    List<RelayNotification> relayNotifications,
  ) async {
    if (relayNotifications.isEmpty) return [];

    // First, consolidate follow notifications (keep only most recent per user)
    final consolidatedNotifications = _consolidateFollowNotifications(
      relayNotifications,
    );

    final userProfileService = ref.read(userProfileServiceProvider);
    final videoEventService = ref.read(videoEventServiceProvider);

    // Batch fetch profiles for all unique pubkeys
    final pubkeys = consolidatedNotifications
        .map((n) => n.sourcePubkey)
        .toSet();

    // Trigger profile fetches (don't wait - profiles may already be cached)
    for (final pubkey in pubkeys) {
      // fetchProfile returns cached if available, fetches if not
      userProfileService.fetchProfile(pubkey);
    }

    // Convert to NotificationModel with available profile data
    final enriched = <NotificationModel>[];
    for (final relay in consolidatedNotifications) {
      // Get cached profile (may be null if still loading)
      final profile = userProfileService.getCachedProfile(relay.sourcePubkey);

      // Get video info if available
      String? videoUrl;
      String? videoThumbnail;
      if (relay.referencedEventId != null) {
        final video = videoEventService.getVideoEventById(
          relay.referencedEventId!,
        );
        videoUrl = video?.videoUrl;
        videoThumbnail = video?.thumbnailUrl;
      }

      enriched.add(
        notificationModelFromRelayApi(
          relay,
          actorName: profile?.bestDisplayName,
          actorPictureUrl: profile?.picture,
          targetVideoUrl: videoUrl,
          targetVideoThumbnail: videoThumbnail,
        ),
      );
    }

    return enriched;
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

    // Keep only the most recent follow notification per source pubkey
    final latestFollowByPubkey = <String, RelayNotification>{};
    for (final follow in followNotifications) {
      final existing = latestFollowByPubkey[follow.sourcePubkey];
      if (existing == null || follow.createdAt.isAfter(existing.createdAt)) {
        latestFollowByPubkey[follow.sourcePubkey] = follow;
      }
    }

    final consolidatedFollows = latestFollowByPubkey.values.toList();

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
}

/// Provider for relay notification API service
@riverpod
RelayNotificationApiService relayNotificationApiService(Ref ref) {
  final environmentConfig = ref.watch(currentEnvironmentProvider);
  final nip98AuthService = ref.watch(nip98AuthServiceProvider);

  return RelayNotificationApiService(
    baseUrl: environmentConfig.apiBaseUrl,
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
