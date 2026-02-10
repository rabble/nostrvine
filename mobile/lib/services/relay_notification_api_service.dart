// ABOUTME: HTTP client for Divine Relay notifications REST API with NIP-98 authentication
// ABOUTME: Provides server-side filtered notifications, pagination, and mark-as-read functionality

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Notification from the Divine Relay API
class RelayNotification {
  const RelayNotification({
    required this.id,
    required this.sourcePubkey,
    required this.sourceEventId,
    required this.sourceKind,
    required this.notificationType,
    required this.createdAt,
    required this.read,
    this.referencedEventId,
    this.content,
  });

  factory RelayNotification.fromJson(Map<String, dynamic> json) {
    return RelayNotification(
      id: json['id']?.toString() ?? '',
      sourcePubkey: json['source_pubkey']?.toString() ?? '',
      sourceEventId: json['source_event_id']?.toString() ?? '',
      sourceKind: json['source_kind'] as int? ?? 0,
      referencedEventId: json['referenced_event_id']?.toString(),
      notificationType: json['notification_type']?.toString() ?? 'unknown',
      createdAt: _parseDateTime(json['created_at']),
      read: json['read'] as bool? ?? false,
      content: json['content']?.toString(),
    );
  }

  final String id;
  final String sourcePubkey;
  final String sourceEventId;
  final int sourceKind;
  final String? referencedEventId;
  final String
  notificationType; // "reaction", "reply", "repost", "follow", "zap"
  final DateTime createdAt;
  final bool read;
  final String? content;

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  RelayNotification copyWith({
    String? id,
    String? sourcePubkey,
    String? sourceEventId,
    int? sourceKind,
    String? referencedEventId,
    String? notificationType,
    DateTime? createdAt,
    bool? read,
    String? content,
  }) {
    return RelayNotification(
      id: id ?? this.id,
      sourcePubkey: sourcePubkey ?? this.sourcePubkey,
      sourceEventId: sourceEventId ?? this.sourceEventId,
      sourceKind: sourceKind ?? this.sourceKind,
      referencedEventId: referencedEventId ?? this.referencedEventId,
      notificationType: notificationType ?? this.notificationType,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      content: content ?? this.content,
    );
  }

  @override
  String toString() =>
      'RelayNotification(id: $id, type: $notificationType, from: $sourcePubkey)';
}

/// Response from GET /api/users/{pubkey}/notifications
class NotificationsResponse {
  const NotificationsResponse({
    required this.notifications,
    required this.unreadCount,
    this.nextCursor,
    this.hasMore = false,
  });

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    final notificationsData = json['notifications'] as List<dynamic>? ?? [];

    return NotificationsResponse(
      notifications: notificationsData
          .map((n) => RelayNotification.fromJson(n as Map<String, dynamic>))
          .toList(),
      unreadCount: json['unread_count'] as int? ?? 0,
      nextCursor: json['next_cursor']?.toString(),
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  final List<RelayNotification> notifications;
  final int unreadCount;
  final String? nextCursor;
  final bool hasMore;

  static const empty = NotificationsResponse(notifications: [], unreadCount: 0);
}

/// Response from POST /api/users/{pubkey}/notifications/read
class MarkReadResponse {
  const MarkReadResponse({
    required this.success,
    this.markedCount = 0,
    this.error,
  });

  factory MarkReadResponse.fromJson(Map<String, dynamic> json) {
    return MarkReadResponse(
      success: json['success'] as bool? ?? false,
      markedCount: json['marked_count'] as int? ?? 0,
      error: json['error']?.toString(),
    );
  }

  final bool success;
  final int markedCount;
  final String? error;
}

/// Service for interacting with Divine Relay notifications REST API
///
/// Uses NIP-98 HTTP authentication for all requests.
/// Provides server-side filtering, pagination, and read state management.
class RelayNotificationApiService {
  static const Duration _defaultTimeout = Duration(seconds: 15);

  RelayNotificationApiService({
    required String? baseUrl,
    required Nip98AuthService nip98AuthService,
    http.Client? httpClient,
  }) : _baseUrl = baseUrl,
       _nip98AuthService = nip98AuthService,
       _httpClient = httpClient ?? http.Client();

  final String? _baseUrl;
  final Nip98AuthService _nip98AuthService;
  final http.Client _httpClient;

  /// Whether the API is available (has a configured base URL)
  bool get isAvailable => _baseUrl != null && _baseUrl.isNotEmpty;

  /// Fetch notifications for a user
  ///
  /// [pubkey] - Hex public key of the user
  /// [types] - Optional list of notification types to filter ("reaction", "reply", "repost", "follow", "zap")
  /// [unreadOnly] - If true, only return unread notifications
  /// [limit] - Maximum number of notifications to return (default 50)
  /// [before] - Cursor for pagination (get notifications before this cursor)
  Future<NotificationsResponse> getNotifications({
    required String pubkey,
    List<String>? types,
    bool unreadOnly = false,
    int limit = 50,
    String? before,
  }) async {
    if (!isAvailable) {
      Log.warning(
        'Relay Notifications API not available (no base URL configured)',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );
      return NotificationsResponse.empty;
    }

    if (pubkey.isEmpty) {
      Log.warning(
        'Cannot fetch notifications without pubkey',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );
      return NotificationsResponse.empty;
    }

    try {
      // Build URL with query parameters
      final queryParams = <String, String>{'limit': limit.toString()};
      if (types != null && types.isNotEmpty) {
        queryParams['types'] = types.join(',');
      }
      if (unreadOnly) {
        queryParams['unread_only'] = 'true';
      }
      if (before != null) {
        queryParams['before'] = before;
      }

      final uri = Uri.parse(
        '$_baseUrl/api/users/$pubkey/notifications',
      ).replace(queryParameters: queryParams);
      final url = uri.toString();

      Log.info(
        'Fetching notifications from Relay API: $url',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );

      // Create NIP-98 auth token
      final authToken = await _nip98AuthService.createAuthToken(
        url: url,
        method: HttpMethod.get,
      );

      if (authToken == null) {
        Log.error(
          'Failed to create NIP-98 auth token for notifications',
          name: 'RelayNotificationApiService',
          category: LogCategory.system,
        );
        return NotificationsResponse.empty;
      }

      final header = authToken.authorizationHeader;
      final headerPreview = header.length > 50
          ? '${header.substring(0, 50)}...'
          : header;
      Log.debug(
        'NIP-98 Auth header: $headerPreview',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );

      final response = await _httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
              'Authorization': authToken.authorizationHeader,
            },
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = NotificationsResponse.fromJson(data);

        // Log type breakdown from raw API response
        final typeBreakdown = <String, int>{};
        for (final n in result.notifications) {
          typeBreakdown[n.notificationType] =
              (typeBreakdown[n.notificationType] ?? 0) + 1;
        }
        Log.info(
          'Received ${result.notifications.length} notifications, '
          'unread: ${result.unreadCount}, hasMore: ${result.hasMore}, '
          'types: $typeBreakdown',
          name: 'RelayNotificationApiService',
          category: LogCategory.system,
        );

        return result;
      } else if (response.statusCode == 404) {
        Log.debug(
          'Notifications endpoint returned 404 (user may have no notifications)',
          name: 'RelayNotificationApiService',
          category: LogCategory.system,
        );
        return NotificationsResponse.empty;
      } else if (response.statusCode == 401) {
        Log.error(
          'Notifications API authentication failed (401)\n'
          'URL: $url\n'
          'Response: ${response.body}',
          name: 'RelayNotificationApiService',
          category: LogCategory.system,
        );
        return NotificationsResponse.empty;
      } else {
        Log.error(
          'Notifications API error: ${response.statusCode}\n'
          'URL: $url\n'
          'Response: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}',
          name: 'RelayNotificationApiService',
          category: LogCategory.system,
        );
        return NotificationsResponse.empty;
      }
    } catch (e) {
      Log.error(
        'Error fetching notifications: $e',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );
      return NotificationsResponse.empty;
    }
  }

  /// Mark notifications as read
  ///
  /// [pubkey] - Hex public key of the user
  /// [notificationIds] - Optional list of specific notification IDs to mark as read.
  ///                     If null or empty, marks ALL notifications as read.
  Future<MarkReadResponse> markAsRead({
    required String pubkey,
    List<String>? notificationIds,
  }) async {
    if (!isAvailable) {
      Log.warning(
        'Relay Notifications API not available (no base URL configured)',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );
      return const MarkReadResponse(success: false, error: 'API not available');
    }

    if (pubkey.isEmpty) {
      Log.warning(
        'Cannot mark notifications without pubkey',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );
      return const MarkReadResponse(success: false, error: 'Missing pubkey');
    }

    try {
      final url = '$_baseUrl/api/users/$pubkey/notifications/read';
      final uri = Uri.parse(url);

      // Build request body
      final requestBody = <String, dynamic>{};
      if (notificationIds != null && notificationIds.isNotEmpty) {
        requestBody['notification_ids'] = notificationIds;
      }
      // Empty body means mark all as read

      final payload = jsonEncode(requestBody);

      Log.info(
        'Marking notifications as read: ${notificationIds?.length ?? "all"}',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );

      // Create NIP-98 auth token with payload
      final authToken = await _nip98AuthService.createAuthToken(
        url: url,
        method: HttpMethod.post,
        payload: payload,
      );

      if (authToken == null) {
        Log.error(
          'Failed to create NIP-98 auth token for mark as read',
          name: 'RelayNotificationApiService',
          category: LogCategory.system,
        );
        return const MarkReadResponse(
          success: false,
          error: 'Auth token creation failed',
        );
      }

      final response = await _httpClient
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
              'Authorization': authToken.authorizationHeader,
            },
            body: payload,
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = MarkReadResponse.fromJson(data);

        Log.info(
          'Marked ${result.markedCount} notifications as read',
          name: 'RelayNotificationApiService',
          category: LogCategory.system,
        );

        return result;
      } else if (response.statusCode == 401) {
        Log.error(
          'Mark as read API authentication failed (401)',
          name: 'RelayNotificationApiService',
          category: LogCategory.system,
        );
        return const MarkReadResponse(
          success: false,
          error: 'Authentication failed',
        );
      } else {
        Log.error(
          'Mark as read API error: ${response.statusCode}',
          name: 'RelayNotificationApiService',
          category: LogCategory.system,
        );
        return MarkReadResponse(
          success: false,
          error: 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      Log.error(
        'Error marking notifications as read: $e',
        name: 'RelayNotificationApiService',
        category: LogCategory.system,
      );
      return MarkReadResponse(success: false, error: e.toString());
    }
  }

  /// Get unread notification count
  ///
  /// This is a convenience method that fetches just the unread count
  /// without loading all notification data.
  Future<int> getUnreadCount({required String pubkey}) async {
    final response = await getNotifications(
      pubkey: pubkey,
      limit: 1, // Minimal load - we only need the unread_count field
      unreadOnly: true,
    );
    return response.unreadCount;
  }

  /// Dispose of resources
  void dispose() {
    _httpClient.close();
  }
}
