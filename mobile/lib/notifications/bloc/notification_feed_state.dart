// ABOUTME: State for NotificationFeedBloc — tracks notifications list,
// ABOUTME: load/refresh status, and unread count.

part of 'notification_feed_bloc.dart';

/// Status of the notification feed.
///
/// "Refresh in flight" is tracked separately via
/// [NotificationFeedState.isRefreshing] so a background revalidation never
/// blanks out already-rendered (cached) items — see
/// [NotificationFeedState] for the stale-while-revalidate contract.
enum NotificationFeedStatus {
  /// No data loaded yet (cold start, before the first emission).
  initial,

  /// Notifications loaded successfully.
  loaded,

  /// An error occurred while loading notifications and there is nothing
  /// cached to fall back to.
  failure,
}

/// State for the NotificationFeedBloc.
final class NotificationFeedState extends Equatable {
  const NotificationFeedState({
    this.status = NotificationFeedStatus.initial,
    this.notifications = const [],
    this.unreadCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.refreshError = false,
  });

  /// The current loading status.
  ///
  /// `failure` is reserved for the empty-cache hard failure path. When
  /// the repository surfaces a refresh error but still has cached items
  /// to show, [status] stays `loaded` and [refreshError] flips to `true`
  /// instead — the view renders the cached list with an inline error
  /// affordance rather than a Retry-only blackout.
  final NotificationFeedStatus status;

  /// The list of enriched, grouped notification items.
  final List<NotificationItem> notifications;

  /// Server-reported unread count.
  ///
  /// Held as the diagnostic source — the inbox badge derives from
  /// [unreadBadgeCount] instead so Kind 3 republish duplicates do not
  /// inflate the user-visible counter past the consolidated list.
  final int unreadCount;

  /// Whether more pages are available for pagination.
  final bool hasMore;

  /// Whether a load-more operation is in progress.
  final bool isLoadingMore;

  /// Whether a first-page network refresh is currently in flight.
  ///
  /// This is the stale-while-revalidate signal: when cached items are
  /// already on screen, the view keeps rendering them and shows a thin
  /// `LinearProgressIndicator` instead of a blanking full-screen spinner.
  /// The full-screen spinner is reserved for the cold-start case where
  /// there is nothing cached to show yet.
  final bool isRefreshing;

  /// Whether the most recent first-page refresh failed.
  ///
  /// Mirrors `NotificationPage.lastRefreshError` from the repository. The
  /// view shows an inline banner above the list when this is `true` and
  /// [notifications] is non-empty; the full failure screen fires only
  /// when [notifications] is also empty (i.e. cache miss + refresh
  /// failure).
  final bool refreshError;

  /// Inbox unread badge count, derived from the consolidated visible list.
  ///
  /// The server reports one row per Kind 3 republish per follower — so the
  /// same N followers can produce 2N+ rows after a few contact-list edits,
  /// even though [NotificationRepository] has already merged them on screen
  /// via `_consolidateFollows`. Counting unread items in the
  /// post-consolidation list keeps the badge in sync with what the user
  /// actually sees.
  ///
  // TODO(funnelcake#234): Revert to [unreadCount] once server-side Kind 3
  // republish dedup ships and the visible list and server count agree
  // again. Tracking: divinevideo/divine-funnelcake#234.
  int get unreadBadgeCount => notifications.where((n) => !n.isRead).length;

  /// Create a copy with updated values.
  NotificationFeedState copyWith({
    NotificationFeedStatus? status,
    List<NotificationItem>? notifications,
    int? unreadCount,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? refreshError,
  }) {
    return NotificationFeedState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshError: refreshError ?? this.refreshError,
    );
  }

  @override
  List<Object?> get props => [
    status,
    notifications,
    unreadCount,
    hasMore,
    isLoadingMore,
    isRefreshing,
    refreshError,
  ];
}
