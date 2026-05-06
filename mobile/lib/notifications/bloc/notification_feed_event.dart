// ABOUTME: Events for NotificationFeedBloc — initial load, pagination,
// ABOUTME: refresh, real-time push, mark-read, and follow-back actions.

part of 'notification_feed_bloc.dart';

/// Base class for all notification feed events.
sealed class NotificationFeedEvent extends Equatable {
  const NotificationFeedEvent();
}

/// Initial load of the notification feed.
///
/// Dispatched when the notification screen initializes.
final class NotificationFeedStarted extends NotificationFeedEvent {
  const NotificationFeedStarted();

  @override
  List<Object?> get props => [];
}

/// Load the next page of notifications (scroll pagination).
final class NotificationFeedLoadMore extends NotificationFeedEvent {
  const NotificationFeedLoadMore();

  @override
  List<Object?> get props => [];
}

/// Pull-to-refresh — reloads from the beginning.
final class NotificationFeedRefreshed extends NotificationFeedEvent {
  const NotificationFeedRefreshed();

  @override
  List<Object?> get props => [];
}

/// Push notification received — triggers a refresh.
final class NotificationFeedPushReceived extends NotificationFeedEvent {
  const NotificationFeedPushReceived();

  @override
  List<Object?> get props => [];
}

/// WebSocket real-time notification received.
///
/// Carries the raw [RelayNotification] — the BLoC enriches it via
/// [NotificationRepository.enrichOne] before merging into state. This
/// avoids the "row arrives nameless then snaps to real name" flicker.
final class NotificationFeedRealtimeReceived extends NotificationFeedEvent {
  const NotificationFeedRealtimeReceived(this.raw);

  /// The raw relay notification delivered via WebSocket.
  final RelayNotification raw;

  @override
  List<Object?> get props => [raw];
}

/// User tapped a notification — mark it as read.
final class NotificationFeedItemTapped extends NotificationFeedEvent {
  const NotificationFeedItemTapped(this.notificationId);

  /// The ID of the tapped notification.
  final String notificationId;

  @override
  List<Object?> get props => [notificationId];
}

/// Mark all notifications as read.
final class NotificationFeedMarkAllRead extends NotificationFeedEvent {
  const NotificationFeedMarkAllRead();

  @override
  List<Object?> get props => [];
}

/// Follow back a user from a follow notification.
final class NotificationFeedFollowBack extends NotificationFeedEvent {
  const NotificationFeedFollowBack(this.pubkey);

  /// The pubkey of the user to follow back.
  final String pubkey;

  @override
  List<Object?> get props => [pubkey];
}
