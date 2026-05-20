import 'package:funnelcake_api_client/src/models/relay_notification.dart';

/// Paginated response from the Divine Relay notification API.
class NotificationResponse {
  /// Creates a parsed notification response model.
  const NotificationResponse({
    required this.notifications,
    required this.unreadCount,
    required this.hasMore,
    this.nextCursor,
    this.nextCursorId,
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
      nextCursorId: json['next_cursor_id'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  /// The current page of notifications returned by the API.
  final List<RelayNotification> notifications;

  /// The total number of unread notifications.
  final int unreadCount;

  /// Cursor for fetching the next page when available.
  final String? nextCursor;

  /// Cursor tiebreaker for fetching the next page when available.
  final String? nextCursorId;

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
  ///
  /// The funnelcake server returns `{"marked_count": N, "marked_all": bool}`
  /// on success and `{"error": "..."}` on soft-failure. The `success` field
  /// that #4271 introduced was speculative — the real funnelcake response
  /// never sends it, so defaulting to `false` made every successful 200
  /// parse as a soft-failure (badge bounce-back from the repository
  /// rollback). Accept the explicit `success` value when present (for
  /// forward-compat with a server that adopts the field), otherwise derive
  /// it from the absence of `error`.
  factory MarkReadResponse.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as String?;
    return MarkReadResponse(
      success: (json['success'] as bool?) ?? (error == null),
      markedCount: json['marked_count'] as int? ?? 0,
      error: error,
    );
  }

  /// Whether the mark-read operation succeeded.
  final bool success;

  /// The number of notifications marked as read.
  final int markedCount;

  /// An optional error message when the operation fails.
  final String? error;
}
