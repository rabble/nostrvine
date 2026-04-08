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

  /// Total unread count reported by the server.
  final int unreadCount;

  /// Whether more pages are available for pagination.
  final bool hasMore;

  /// Whether a load-more operation is in progress.
  final bool isLoadingMore;

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
