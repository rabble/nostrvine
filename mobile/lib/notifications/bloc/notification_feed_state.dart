// ABOUTME: State for NotificationFeedBloc — tracks notifications list,
// ABOUTME: loading/pagination status, and unread count.

part of 'notification_feed_bloc.dart';

/// Status of the notification feed.
enum NotificationFeedStatus {
  /// No data loaded yet.
  initial,

  /// Currently loading notifications.
  loading,

  /// Notifications loaded successfully.
  loaded,

  /// An error occurred while loading notifications.
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
  });

  /// The current loading status.
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
  }) {
    return NotificationFeedState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    status,
    notifications,
    unreadCount,
    hasMore,
    isLoadingMore,
  ];
}
