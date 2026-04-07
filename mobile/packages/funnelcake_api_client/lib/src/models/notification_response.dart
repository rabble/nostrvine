import 'package:funnelcake_api_client/src/models/relay_notification.dart';

/// Paginated response from the Divine Relay notification API.
class NotificationResponse {
  /// Creates a parsed notification response model.
  const NotificationResponse({
    required this.notifications,
    required this.unreadCount,
    required this.hasMore,
    this.nextCursor,
  });

  /// Parses the REST response body into a typed notification payload.
  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    final notificationsJson =
        (json['notifications'] as List<dynamic>?) ?? <dynamic>[];
    return NotificationResponse(
      notifications: notificationsJson
          .whereType<Map<String, dynamic>>()
          .map(RelayNotification.fromJson)
          .toList(),
      unreadCount: json['unread_count'] as int? ?? 0,
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  /// The current page of notifications returned by the API.
  final List<RelayNotification> notifications;

  /// The total number of unread notifications.
  final int unreadCount;

  /// Cursor for fetching the next page when available.
  final String? nextCursor;

  /// Whether more notifications are available beyond this page.
  final bool hasMore;
}

/// Response from the mark-as-read API endpoint.
class MarkReadResponse {
  /// Creates a parsed mark-read response model.
  const MarkReadResponse({
    required this.success,
    required this.markedCount,
    this.error,
  });

  /// Parses the REST response body into a typed mark-read payload.
  factory MarkReadResponse.fromJson(Map<String, dynamic> json) {
    return MarkReadResponse(
      success: json['success'] as bool? ?? false,
      markedCount: json['marked_count'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }

  /// Whether the mark-read operation succeeded.
  final bool success;

  /// The number of notifications marked as read.
  final int markedCount;

  /// An optional error message when the operation fails.
  final String? error;
}
