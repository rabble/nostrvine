# Notifications BLoC Refactor Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken Riverpod notification system with a BLoC-based architecture that shows real usernames, avatars, video titles, comment previews, grouped likes, and proper navigation — matching the Figma design spec.

**Architecture:** `UI (Page/View) → NotificationFeedBloc → NotificationRepository → FunnelcakeApiClient + ProfileRepository + NostrClient + NotificationsDao`. Repository owns all data fetching, enrichment, and grouping. BLoC handles pagination, real-time events, and push triggers. UI renders per Figma design with no business logic.

**Tech Stack:** flutter_bloc, bloc_concurrency, equatable, mocktail, bloc_test, funnelcake_api_client, profile_repository, nostr_client, db_client (Drift)

**Spec:** `docs/superpowers/specs/2026-04-06-notifications-bloc-refactor-design.md`

**Related issues:** #2688, #2667, #2478, #2444, #2433, #2340, #2218, #272

---

## Chunk 1: Data Layer — FunnelcakeApiClient Notification Endpoints

### Task 1: Add notification DTOs to funnelcake_api_client

**Files:**
- Create: `packages/funnelcake_api_client/lib/src/models/notification_response.dart`
- Create: `packages/funnelcake_api_client/lib/src/models/relay_notification.dart`
- Modify: `packages/funnelcake_api_client/lib/funnelcake_api_client.dart` (barrel export)
- Test: `packages/funnelcake_api_client/test/src/models/notification_response_test.dart`
- Test: `packages/funnelcake_api_client/test/src/models/relay_notification_test.dart`

These DTOs move from `lib/services/relay_notification_api_service.dart` into the proper data layer package.


- [ ] **Step 1: Write tests for RelayNotification.fromJson**

```dart
// packages/funnelcake_api_client/test/src/models/relay_notification_test.dart
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('RelayNotification', () {
    group('fromJson', () {
      test('parses valid notification JSON', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
          'content': '+',
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.id, equals('notif_123'));
        expect(notification.sourcePubkey, equals('aabbccdd' * 8));
        expect(notification.sourceKind, equals(7));
        expect(notification.notificationType, equals('reaction'));
        expect(notification.read, isFalse);
        expect(notification.content, equals('+'));
      });

      test('handles null optional fields', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.referencedEventId, isNull);
        expect(notification.content, isNull);
      });

      test('dedupeKey uses id when present', () {
        final notification = RelayNotification.fromJson({
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        });

        expect(notification.dedupeKey, equals('notif_123'));
      });

      test('dedupeKey falls back to sourceEventId when id empty', () {
        final notification = RelayNotification.fromJson({
          'id': '',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        });

        expect(notification.dedupeKey, equals('11223344' * 8));
      });
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test packages/funnelcake_api_client/test/src/models/relay_notification_test.dart`
Expected: FAIL — file/class not found

- [ ] **Step 3: Create RelayNotification model**

Move the `RelayNotification` class from `lib/services/relay_notification_api_service.dart` (lines 12-93) into:

```dart
// packages/funnelcake_api_client/lib/src/models/relay_notification.dart

/// Raw notification from the Divine Relay REST API.
/// Represents a single notification event before enrichment or grouping.
/// Plain class (no Equatable) — matches other DTOs in this package.
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
      id: json['id'] as String? ?? '',
      sourcePubkey: json['source_pubkey'] as String? ?? '',
      sourceEventId: json['source_event_id'] as String? ?? '',
      sourceKind: json['source_kind'] as int? ?? 0,
      referencedEventId: json['referenced_event_id'] as String?,
      notificationType: json['notification_type'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        ((json['created_at'] as int?) ?? 0) * 1000,
      ),
      read: json['read'] as bool? ?? false,
      content: json['content'] as String?,
    );
  }

  final String id;
  final String sourcePubkey;
  final String sourceEventId;
  final int sourceKind;
  final String? referencedEventId;
  final String notificationType;
  final DateTime createdAt;
  final bool read;
  final String? content;

  /// Stable dedup key — falls back to sourceEventId if id is empty.
  String get dedupeKey => id.isNotEmpty ? id : sourceEventId;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test packages/funnelcake_api_client/test/src/models/relay_notification_test.dart`
Expected: PASS

- [ ] **Step 5: Write tests for NotificationResponse.fromJson**

```dart
// packages/funnelcake_api_client/test/src/models/notification_response_test.dart
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('NotificationResponse', () {
    test('parses response with notifications', () {
      final json = {
        'notifications': [
          {
            'id': 'notif_1',
            'source_pubkey': 'aabbccdd' * 8,
            'source_event_id': '11223344' * 8,
            'source_kind': 7,
            'notification_type': 'reaction',
            'created_at': 1712345678,
            'read': false,
          },
        ],
        'unread_count': 5,
        'next_cursor': 'cursor_abc',
        'has_more': true,
      };

      final response = NotificationResponse.fromJson(json);

      expect(response.notifications, hasLength(1));
      expect(response.unreadCount, equals(5));
      expect(response.nextCursor, equals('cursor_abc'));
      expect(response.hasMore, isTrue);
    });

    test('handles empty notifications list', () {
      final json = {
        'notifications': <Map<String, dynamic>>[],
        'unread_count': 0,
        'has_more': false,
      };

      final response = NotificationResponse.fromJson(json);

      expect(response.notifications, isEmpty);
      expect(response.unreadCount, equals(0));
      expect(response.nextCursor, isNull);
      expect(response.hasMore, isFalse);
    });
  });

  group('MarkReadResponse', () {
    test('parses success response', () {
      final json = {
        'success': true,
        'marked_count': 10,
      };

      final response = MarkReadResponse.fromJson(json);

      expect(response.success, isTrue);
      expect(response.markedCount, equals(10));
      expect(response.error, isNull);
    });
  });
}
```

- [ ] **Step 6: Create NotificationResponse and MarkReadResponse models**

```dart
// packages/funnelcake_api_client/lib/src/models/notification_response.dart
import 'package:funnelcake_api_client/src/models/relay_notification.dart';

/// Paginated response from the Divine Relay notification API.
class NotificationResponse {
  const NotificationResponse({
    required this.notifications,
    required this.unreadCount,
    required this.hasMore,
    this.nextCursor,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    final notificationsJson =
        (json['notifications'] as List<dynamic>?) ?? <dynamic>[];
    return NotificationResponse(
      notifications: notificationsJson
          .cast<Map<String, dynamic>>()
          .map(RelayNotification.fromJson)
          .toList(),
      unreadCount: json['unread_count'] as int? ?? 0,
      nextCursor: json['next_cursor'] as String?,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  final List<RelayNotification> notifications;
  final int unreadCount;
  final String? nextCursor;
  final bool hasMore;
}

/// Response from the mark-as-read API endpoint.
class MarkReadResponse {
  const MarkReadResponse({
    required this.success,
    required this.markedCount,
    this.error,
  });

  factory MarkReadResponse.fromJson(Map<String, dynamic> json) {
    return MarkReadResponse(
      success: json['success'] as bool? ?? false,
      markedCount: json['marked_count'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }

  final bool success;
  final int markedCount;
  final String? error;
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd mobile && flutter test packages/funnelcake_api_client/test/src/models/notification_response_test.dart`
Expected: PASS

- [ ] **Step 8: Export models from barrel file**

Add to `packages/funnelcake_api_client/lib/src/models/models.dart` (the existing intermediate barrel):

```dart
export 'notification_response.dart';
export 'relay_notification.dart';
```

The top-level barrel `packages/funnelcake_api_client/lib/funnelcake_api_client.dart` already re-exports `src/models/models.dart`, so no change needed there.

- [ ] **Step 9: Commit**

```bash
git add packages/funnelcake_api_client/
git commit -m "feat(notifications): add notification DTOs to funnelcake_api_client"
```

---

### Task 2: Add notification methods to FunnelcakeApiClient

**Files:**
- Modify: `packages/funnelcake_api_client/lib/src/funnelcake_api_client.dart`
- Test: `packages/funnelcake_api_client/test/src/funnelcake_api_client_notification_test.dart`

The existing client uses NIP-98 auth via a service injected from outside. Check how the current `RelayNotificationApiService` handles auth (lines 225-228) and replicate in the client. The client will need a `Nip98AuthService` dependency — check the constructor and add it if not already present.

**Important:** Read the current `FunnelcakeApiClient` constructor (line 41-52) and `_get()`/`_post()` helper methods before implementing. The notification endpoints use NIP-98 auth which the existing client may not have — you may need to add an optional `nip98AuthService` parameter.

- [ ] **Step 1: Write tests for getNotifications method**

```dart
// packages/funnelcake_api_client/test/src/funnelcake_api_client_notification_test.dart
import 'dart:convert';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {}
class MockNip98AuthService extends Mock implements Nip98AuthService {}
// Note: Nip98AuthService interface may need to be defined or imported.
// Check lib/services/nip98_auth_service.dart for the existing interface.
// If it's app-level only, create a minimal interface in the client package.

void main() {
  late MockHttpClient mockHttpClient;
  late FunnelcakeApiClient client;

  const baseUrl = 'https://relay.divine.video';
  const testPubkey = 'aabbccdd' * 8;

  setUp(() {
    mockHttpClient = MockHttpClient();
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group('getNotifications', () {
    test('fetches notifications with correct URL and headers', () async {
      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'notifications': [],
            'unread_count': 0,
            'has_more': false,
          }),
          200,
        ),
      );

      client = FunnelcakeApiClient(
        baseUrl: baseUrl,
        httpClient: mockHttpClient,
      );

      final response = await client.getNotifications(pubkey: testPubkey);

      expect(response.notifications, isEmpty);
      expect(response.unreadCount, equals(0));

      final captured = verify(
        () => mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
      ).captured;
      final url = captured.first as Uri;
      expect(url.path, contains('/api/users/$testPubkey/notifications'));
    });

    test('passes cursor as before parameter', () async {
      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'notifications': [],
            'unread_count': 0,
            'has_more': false,
          }),
          200,
        ),
      );

      client = FunnelcakeApiClient(
        baseUrl: baseUrl,
        httpClient: mockHttpClient,
      );

      await client.getNotifications(
        pubkey: testPubkey,
        cursor: 'cursor_abc',
      );

      final captured = verify(
        () => mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
      ).captured;
      final url = captured.first as Uri;
      expect(url.queryParameters['before'], equals('cursor_abc'));
    });

    test('returns empty response on 404', () async {
      when(() => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer(
        (_) async => http.Response('Not found', 404),
      );

      client = FunnelcakeApiClient(
        baseUrl: baseUrl,
        httpClient: mockHttpClient,
      );

      final response = await client.getNotifications(pubkey: testPubkey);

      expect(response.notifications, isEmpty);
      expect(response.unreadCount, equals(0));
    });
  });

  group('markNotificationsRead', () {
    test('posts to correct endpoint', () async {
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'success': true, 'marked_count': 5}),
          200,
        ),
      );

      client = FunnelcakeApiClient(
        baseUrl: baseUrl,
        httpClient: mockHttpClient,
      );

      await client.markNotificationsRead(pubkey: testPubkey);

      final captured = verify(
        () => mockHttpClient.post(
          captureAny(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).captured;
      final url = captured.first as Uri;
      expect(url.path, contains('/api/users/$testPubkey/notifications/read'));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test packages/funnelcake_api_client/test/src/funnelcake_api_client_notification_test.dart`
Expected: FAIL — methods don't exist

- [ ] **Step 3: Implement getNotifications and markNotificationsRead**

Add to `packages/funnelcake_api_client/lib/src/funnelcake_api_client.dart`:

```dart
/// Fetches notifications for a user from the relay REST API.
///
/// Uses NIP-98 authentication. The [cursor] parameter enables pagination
/// via the `before` query param. The [authHeaders] parameter allows the
/// caller to provide pre-built NIP-98 auth headers.
Future<NotificationResponse> getNotifications({
  required String pubkey,
  int limit = 50,
  String? cursor,
  Map<String, String>? authHeaders,
}) async {
  final queryParams = <String, String>{
    'limit': '$limit',
    if (cursor != null) 'before': cursor,
  };

  final url = Uri.parse('$_baseUrl/api/users/$pubkey/notifications')
      .replace(queryParameters: queryParams);

  try {
    final response = await _httpClient
        .get(
          url,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'OpenVine-Mobile/1.0',
            ...?authHeaders,
          },
        )
        .timeout(_timeout);

    if (response.statusCode == 404) {
      return const NotificationResponse(
        notifications: [],
        unreadCount: 0,
        hasMore: false,
      );
    }

    if (response.statusCode != 200) {
      return const NotificationResponse(
        notifications: [],
        unreadCount: 0,
        hasMore: false,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return NotificationResponse.fromJson(json);
  } catch (e) {
    return const NotificationResponse(
      notifications: [],
      unreadCount: 0,
      hasMore: false,
    );
  }
}

/// Marks notifications as read. Pass [notificationIds] to mark specific
/// ones, or omit to mark all as read.
Future<MarkReadResponse> markNotificationsRead({
  required String pubkey,
  List<String>? notificationIds,
  Map<String, String>? authHeaders,
}) async {
  final url =
      Uri.parse('$_baseUrl/api/users/$pubkey/notifications/read');

  final payload = jsonEncode({
    if (notificationIds != null) 'notification_ids': notificationIds,
  });

  try {
    final response = await _httpClient
        .post(
          url,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'User-Agent': 'OpenVine-Mobile/1.0',
            ...?authHeaders,
          },
          body: payload,
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      return const MarkReadResponse(success: false, markedCount: 0);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return MarkReadResponse.fromJson(json);
  } catch (e) {
    return const MarkReadResponse(success: false, markedCount: 0);
  }
}
```

**Note on NIP-98 auth:** The current `FunnelcakeApiClient` does not have NIP-98 auth built in — it's handled by `RelayNotificationApiService` at the app level. Rather than adding the NIP-98 service as a dependency of the client package (which would create a circular dep), we pass `authHeaders` from the repository layer where the NIP-98 service is available. The repository calls `nip98AuthService.createAuthToken(url: url, method: HttpMethod.get)` and passes the resulting headers.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test packages/funnelcake_api_client/test/src/funnelcake_api_client_notification_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/funnelcake_api_client/
git commit -m "feat(notifications): add getNotifications and markNotificationsRead to FunnelcakeApiClient"
```

---

## Chunk 2: Domain Model — NotificationItem Sealed Class

### Task 3: Create notification domain models

**Files:**
- Create: `packages/models/lib/src/notification_item.dart`
- Create: `packages/models/lib/src/actor_info.dart`
- Modify: `packages/models/lib/models.dart` (barrel export)
- Test: `packages/models/test/src/notification_item_test.dart`
- Test: `packages/models/test/src/actor_info_test.dart`

These replace the existing `NotificationModel`. The old model stays until migration is complete, then gets deleted.

- [ ] **Step 1: Write tests for ActorInfo**

```dart
// packages/models/test/src/actor_info_test.dart
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('ActorInfo', () {
    test('equality works', () {
      const actor1 = ActorInfo(
        pubkey: 'aabbccdd' * 8,
        displayName: 'alice',
        pictureUrl: 'https://example.com/avatar.jpg',
      );
      const actor2 = ActorInfo(
        pubkey: 'aabbccdd' * 8,
        displayName: 'alice',
        pictureUrl: 'https://example.com/avatar.jpg',
      );

      expect(actor1, equals(actor2));
    });

    test('handles null pictureUrl', () {
      const actor = ActorInfo(
        pubkey: 'aabbccdd' * 8,
        displayName: 'alice',
      );

      expect(actor.pictureUrl, isNull);
    });
  });
}
```

- [ ] **Step 2: Create ActorInfo model**

```dart
// packages/models/lib/src/actor_info.dart
import 'package:equatable/equatable.dart';

/// Lightweight profile snapshot for display in notifications.
class ActorInfo extends Equatable {
  const ActorInfo({
    required this.pubkey,
    required this.displayName,
    this.pictureUrl,
  });

  final String pubkey;
  final String displayName;
  final String? pictureUrl;

  @override
  List<Object?> get props => [pubkey, displayName, pictureUrl];
}
```

- [ ] **Step 3: Run ActorInfo tests**

Run: `cd mobile && flutter test packages/models/test/src/actor_info_test.dart`
Expected: PASS

- [ ] **Step 4: Write tests for NotificationItem sealed classes**

```dart
// packages/models/test/src/notification_item_test.dart
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  const testActor = ActorInfo(
    pubkey: 'aabbccdd' * 8,
    displayName: 'alice_rebel',
    pictureUrl: 'https://example.com/alice.jpg',
  );

  group('SingleNotification', () {
    test('creates like notification', () {
      final notification = SingleNotification(
        id: 'notif_1',
        type: NotificationType.like,
        actor: testActor,
        timestamp: DateTime(2026, 4, 6),
        isRead: false,
        targetEventId: '11223344' * 8,
        videoTitle: 'Best Post Ever',
      );

      expect(notification.type, equals(NotificationType.like));
      expect(notification.actor.displayName, equals('alice_rebel'));
      expect(notification.videoTitle, equals('Best Post Ever'));
    });

    test('creates comment notification with text', () {
      final notification = SingleNotification(
        id: 'notif_2',
        type: NotificationType.comment,
        actor: testActor,
        timestamp: DateTime(2026, 4, 6),
        isRead: false,
        targetEventId: '11223344' * 8,
        videoTitle: 'Best Post Ever',
        commentText: "It's the power of Nostr in full effect. Let's go!",
      );

      expect(notification.commentText, isNotNull);
    });

    test('creates follow notification with followBack flag', () {
      final notification = SingleNotification(
        id: 'notif_3',
        type: NotificationType.follow,
        actor: testActor,
        timestamp: DateTime(2026, 4, 6),
        isRead: false,
        isFollowingBack: false,
      );

      expect(notification.isFollowingBack, isFalse);
      expect(notification.targetEventId, isNull);
      expect(notification.videoTitle, isNull);
    });

  });

  group('GroupedNotification', () {
    test('creates grouped like notification', () {
      const actors = [
        ActorInfo(pubkey: 'aa' * 32, displayName: 'alice'),
        ActorInfo(pubkey: 'bb' * 32, displayName: 'bob'),
        ActorInfo(pubkey: 'cc' * 32, displayName: 'carol'),
      ];

      final notification = GroupedNotification(
        id: 'group_1',
        type: NotificationType.like,
        actors: actors,
        totalCount: 94,
        timestamp: DateTime(2026, 4, 6),
        isRead: false,
        targetEventId: '11223344' * 8,
        videoTitle: 'Best Post Ever',
      );

      expect(notification.actors, hasLength(3));
      expect(notification.totalCount, equals(94));
      expect(notification.videoTitle, equals('Best Post Ever'));
    });

    test('message returns grouped format', () {
      const actors = [
        ActorInfo(pubkey: 'aa' * 32, displayName: 'alice'),
      ];

      final notification = GroupedNotification(
        id: 'group_1',
        type: NotificationType.like,
        actors: actors,
        totalCount: 94,
        timestamp: DateTime(2026, 4, 6),
        isRead: false,
        videoTitle: 'Best Post Ever',
      );

      expect(notification.message, contains('alice'));
      expect(notification.message, contains('93 others'));
      expect(notification.message, contains('Best Post Ever'));
    });
  });

  group('pattern matching', () {
    test('exhaustive switch on NotificationItem', () {
      final NotificationItem item = SingleNotification(
        id: 'notif_1',
        type: NotificationType.like,
        actor: testActor,
        timestamp: DateTime(2026, 4, 6),
        isRead: false,
      );

      final result = switch (item) {
        SingleNotification(:final actor) => actor.displayName,
        GroupedNotification(:final totalCount) => '$totalCount',
      };

      expect(result, equals('alice_rebel'));
    });
  });
}
```

- [ ] **Step 5: Create NotificationItem sealed class**

```dart
// packages/models/lib/src/notification_item.dart
import 'package:equatable/equatable.dart';
import 'package:models/src/actor_info.dart';

/// Notification types matching the Figma design spec.
enum NotificationType { like, comment, reply, follow, repost, mention, system }

/// Base for all displayable notifications.
/// Sealed so the UI can exhaustively switch on subtypes.
sealed class NotificationItem extends Equatable {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.targetEventId,
    this.videoTitle,
  });

  final String id;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? targetEventId;
  final String? videoTitle;

  /// Human-readable message for display.
  String get message;

  // Note: Type icon and formatted timestamp are presentation concerns.
  // Use DivineIcon from divine_ui for type icons in the widget layer.
  // Use the time_formatter package for relative timestamps.
}

/// A notification from a single actor.
class SingleNotification extends NotificationItem {
  const SingleNotification({
    required super.id,
    required super.type,
    required this.actor,
    required super.timestamp,
    super.isRead,
    super.targetEventId,
    super.videoTitle,
    this.commentText,
    this.isFollowingBack = false,
  });

  final ActorInfo actor;
  final String? commentText;
  final bool isFollowingBack;

  @override
  String get message {
    final name = actor.displayName;
    final title = videoTitle;
    return switch (type) {
      NotificationType.like when title != null =>
        '$name liked your video $title',
      NotificationType.like => '$name liked your video',
      NotificationType.comment when title != null =>
        '$name commented on your video $title',
      NotificationType.comment => '$name commented on your video',
      NotificationType.reply => '$name replied to your comment',
      NotificationType.follow => '$name started following you',
      NotificationType.repost when title != null =>
        '$name reposted your video $title',
      NotificationType.repost => '$name reposted your video',
      NotificationType.mention => '$name mentioned you',
      NotificationType.system => 'You have a new update',
    };
  }

  SingleNotification copyWith({
    String? id,
    NotificationType? type,
    ActorInfo? actor,
    DateTime? timestamp,
    bool? isRead,
    String? targetEventId,
    String? videoTitle,
    String? commentText,
    bool? isFollowingBack,
  }) {
    return SingleNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      actor: actor ?? this.actor,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      targetEventId: targetEventId ?? this.targetEventId,
      videoTitle: videoTitle ?? this.videoTitle,
      commentText: commentText ?? this.commentText,
      isFollowingBack: isFollowingBack ?? this.isFollowingBack,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        actor,
        timestamp,
        isRead,
        targetEventId,
        videoTitle,
        commentText,
        isFollowingBack,
      ];
}

/// Grouped notification — "alice and 93 others liked your video".
class GroupedNotification extends NotificationItem {
  const GroupedNotification({
    required super.id,
    required super.type,
    required this.actors,
    required this.totalCount,
    required super.timestamp,
    super.isRead,
    super.targetEventId,
    super.videoTitle,
  });

  /// First few actors for stacked avatar display (max 3).
  final List<ActorInfo> actors;

  /// Total number of actors in this group.
  final int totalCount;

  @override
  String get message {
    if (actors.isEmpty) return 'Someone liked your video';
    final name = actors.first.displayName;
    final othersCount = totalCount - 1;
    final title = videoTitle;
    if (othersCount <= 0) {
      return title != null
          ? '$name liked your video $title'
          : '$name liked your video';
    }
    final others = '$othersCount ${othersCount == 1 ? 'other' : 'others'}';
    return title != null
        ? '$name and $others liked your video $title'
        : '$name and $others liked your video';
  }

  @override
  List<Object?> get props => [
        id,
        type,
        actors,
        totalCount,
        timestamp,
        isRead,
        targetEventId,
        videoTitle,
      ];
}
```

- [ ] **Step 6: Export from barrel file**

Add to `packages/models/lib/models.dart`:

```dart
export 'src/actor_info.dart';
export 'src/notification_item.dart';
```

- [ ] **Step 7: Run tests**

Run: `cd mobile && flutter test packages/models/test/src/notification_item_test.dart && flutter test packages/models/test/src/actor_info_test.dart`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add packages/models/
git commit -m "feat(notifications): add NotificationItem sealed class and ActorInfo model"
```

---

## Chunk 3: Repository Layer — NotificationRepository Package

### Task 4: Create notification_repository package scaffold

**Files:**
- Create: `packages/notification_repository/pubspec.yaml`
- Create: `packages/notification_repository/lib/notification_repository.dart`
- Create: `packages/notification_repository/lib/src/notification_repository.dart`
- Create: `packages/notification_repository/test/src/notification_repository_test.dart`

**Important:** Before creating this package, read the existing `packages/comments_repository/pubspec.yaml` and `packages/profile_repository/pubspec.yaml` to match the project's package conventions (SDK constraints, dependency versions, linter rules). Also check `mobile/pubspec.yaml` to see how repository packages are referenced (path dependency).

- [ ] **Step 1: Create pubspec.yaml**

```yaml
# packages/notification_repository/pubspec.yaml
name: notification_repository
description: Repository for notification data (REST API + WebSocket + local cache)
version: 0.1.0
publish_to: none
resolution: workspace

environment:
  sdk: ^3.11.0

dependencies:
  equatable: ^2.0.7
  funnelcake_api_client:
    path: ../funnelcake_api_client
  models:
    path: ../models
  profile_repository:
    path: ../profile_repository
  nostr_client:
    path: ../nostr_client
  db_client:
    path: ../db_client

dev_dependencies:
  bloc_test: ^10.0.0
  mocktail: ^1.0.4
  flutter_test:
    sdk: flutter
  very_good_analysis: ^10.0.0
```

**Important:** Also add `packages/notification_repository` to the `workspace:` list in `mobile/pubspec.yaml` (around line 25-52) — without this, `flutter pub get` will not resolve the package.

- [ ] **Step 2: Create barrel file**

```dart
// packages/notification_repository/lib/notification_repository.dart
export 'src/notification_repository.dart';
```

- [ ] **Step 3: Write repository tests — enrichment and grouping**

This is the core test. The repository must:
1. Fetch raw notifications from FunnelcakeApiClient
2. Await profile enrichment (fixing the race condition)
3. Group likes by video
4. Consolidate follows
5. Return enriched, grouped NotificationItems

```dart
// packages/notification_repository/test/src/notification_repository_test.dart
import 'package:db_client/db_client.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:test/test.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}
class _MockProfileRepository extends Mock implements ProfileRepository {}
class _MockNotificationsDao extends Mock implements NotificationsDao {}

void main() {
  late _MockFunnelcakeApiClient mockApiClient;
  late _MockProfileRepository mockProfileRepo;
  late _MockNotificationsDao mockDao;
  late NotificationRepository repository;

  const testPubkey = 'aabbccdd' * 8;
  const actorPubkey1 = '11111111' * 8;
  const actorPubkey2 = '22222222' * 8;
  const actorPubkey3 = '33333333' * 8;
  const videoEventId = '44444444' * 8;

  setUp(() {
    mockApiClient = _MockFunnelcakeApiClient();
    mockProfileRepo = _MockProfileRepository();
    mockDao = _MockNotificationsDao();

    repository = NotificationRepository(
      funnelcakeApiClient: mockApiClient,
      profileRepository: mockProfileRepo,
      notificationsDao: mockDao,
      userPubkey: testPubkey,
    );
  });

  group('getNotifications', () {
    test('returns enriched notifications with real profile data', () async {
      // API returns raw notifications
      when(() => mockApiClient.getNotifications(
            pubkey: testPubkey,
            authHeaders: any(named: 'authHeaders'),
          )).thenAnswer(
        (_) async => NotificationResponse(
          notifications: [
            RelayNotification.fromJson({
              'id': 'notif_1',
              'source_pubkey': actorPubkey1,
              'source_event_id': 'a1b2c3d4' * 8,
              'source_kind': 7,
              'referenced_event_id': videoEventId,
              'notification_type': 'reaction',
              'created_at': 1712345678,
              'read': false,
            }),
          ],
          unreadCount: 1,
          hasMore: false,
        ),
      );

      // Profile enrichment returns real data
      when(() => mockProfileRepo.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          )).thenAnswer(
        (_) async => {
          actorPubkey1: UserProfile(
            pubkey: actorPubkey1,
            name: 'alice_rebel',
            picture: 'https://example.com/alice.jpg',
          ),
        },
      );

      final page = await repository.getNotifications();

      expect(page.items, hasLength(1));
      final item = page.items.first;
      expect(item, isA<SingleNotification>());
      final single = item as SingleNotification;
      expect(single.actor.displayName, equals('alice_rebel'));
      expect(single.actor.pictureUrl, equals('https://example.com/alice.jpg'));
      expect(single.type, equals(NotificationType.like));
    });

    test('groups likes for the same video', () async {
      when(() => mockApiClient.getNotifications(
            pubkey: testPubkey,
            authHeaders: any(named: 'authHeaders'),
          )).thenAnswer(
        (_) async => NotificationResponse(
          notifications: [
            RelayNotification.fromJson({
              'id': 'notif_1',
              'source_pubkey': actorPubkey1,
              'source_event_id': 'a1b2c3d4' * 8,
              'source_kind': 7,
              'referenced_event_id': videoEventId,
              'notification_type': 'reaction',
              'created_at': 1712345680,
              'read': false,
            }),
            RelayNotification.fromJson({
              'id': 'notif_2',
              'source_pubkey': actorPubkey2,
              'source_event_id': 'b2c3d4e5' * 8,
              'source_kind': 7,
              'referenced_event_id': videoEventId,
              'notification_type': 'reaction',
              'created_at': 1712345679,
              'read': false,
            }),
            RelayNotification.fromJson({
              'id': 'notif_3',
              'source_pubkey': actorPubkey3,
              'source_event_id': 'c3d4e5f6' * 8,
              'source_kind': 7,
              'referenced_event_id': videoEventId,
              'notification_type': 'reaction',
              'created_at': 1712345678,
              'read': false,
            }),
          ],
          unreadCount: 3,
          hasMore: false,
        ),
      );

      when(() => mockProfileRepo.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          )).thenAnswer(
        (_) async => {
          actorPubkey1: UserProfile(pubkey: actorPubkey1, name: 'alice'),
          actorPubkey2: UserProfile(pubkey: actorPubkey2, name: 'bob'),
          actorPubkey3: UserProfile(pubkey: actorPubkey3, name: 'carol'),
        },
      );

      final page = await repository.getNotifications();

      // 3 individual likes for same video → 1 grouped notification
      expect(page.items, hasLength(1));
      final item = page.items.first;
      expect(item, isA<GroupedNotification>());
      final grouped = item as GroupedNotification;
      expect(grouped.totalCount, equals(3));
      expect(grouped.actors, hasLength(3));
      expect(grouped.actors.first.displayName, equals('alice'));
    });

    test('consolidates follow duplicates keeping earliest', () async {
      when(() => mockApiClient.getNotifications(
            pubkey: testPubkey,
            authHeaders: any(named: 'authHeaders'),
          )).thenAnswer(
        (_) async => NotificationResponse(
          notifications: [
            RelayNotification.fromJson({
              'id': 'notif_1',
              'source_pubkey': actorPubkey1,
              'source_event_id': 'a1b2c3d4' * 8,
              'source_kind': 3,
              'notification_type': 'follow',
              'created_at': 1712345680,
              'read': false,
            }),
            // Duplicate follow from same user (Kind 3 republish)
            RelayNotification.fromJson({
              'id': 'notif_2',
              'source_pubkey': actorPubkey1,
              'source_event_id': 'b2c3d4e5' * 8,
              'source_kind': 3,
              'notification_type': 'follow',
              'created_at': 1712345678,
              'read': false,
            }),
          ],
          unreadCount: 1,
          hasMore: false,
        ),
      );

      when(() => mockProfileRepo.fetchBatchProfiles(
            pubkeys: [actorPubkey1],
          )).thenAnswer(
        (_) async => {
          actorPubkey1: UserProfile(pubkey: actorPubkey1, name: 'alice'),
        },
      );

      final page = await repository.getNotifications();

      // 2 follows from same pubkey → 1 notification (earliest)
      expect(page.items, hasLength(1));
      final item = page.items.first as SingleNotification;
      expect(item.type, equals(NotificationType.follow));
    });

    test('does not group comments — each is individual', () async {
      when(() => mockApiClient.getNotifications(
            pubkey: testPubkey,
            authHeaders: any(named: 'authHeaders'),
          )).thenAnswer(
        (_) async => NotificationResponse(
          notifications: [
            RelayNotification.fromJson({
              'id': 'notif_1',
              'source_pubkey': actorPubkey1,
              'source_event_id': 'a1b2c3d4' * 8,
              'source_kind': 1111,
              'referenced_event_id': videoEventId,
              'notification_type': 'comment',
              'created_at': 1712345680,
              'read': false,
              'content': 'Great video!',
            }),
            RelayNotification.fromJson({
              'id': 'notif_2',
              'source_pubkey': actorPubkey2,
              'source_event_id': 'b2c3d4e5' * 8,
              'source_kind': 1111,
              'referenced_event_id': videoEventId,
              'notification_type': 'comment',
              'created_at': 1712345678,
              'read': false,
              'content': 'Amazing!',
            }),
          ],
          unreadCount: 2,
          hasMore: false,
        ),
      );

      when(() => mockProfileRepo.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          )).thenAnswer(
        (_) async => {
          actorPubkey1: UserProfile(pubkey: actorPubkey1, name: 'alice'),
          actorPubkey2: UserProfile(pubkey: actorPubkey2, name: 'bob'),
        },
      );

      final page = await repository.getNotifications();

      // Comments stay individual — not grouped
      expect(page.items, hasLength(2));
      expect(page.items.first, isA<SingleNotification>());
      expect(
        (page.items.first as SingleNotification).commentText,
        equals('Great video!'),
      );
    });
  });
}
```

- [ ] **Step 4: Implement NotificationRepository**

```dart
// packages/notification_repository/lib/src/notification_repository.dart
import 'package:db_client/db_client.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:profile_repository/profile_repository.dart';

/// Paginated response from the notification repository.
class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.unreadCount,
    required this.hasMore,
    this.nextCursor,
  });

  final List<NotificationItem> items;
  final int unreadCount;
  final String? nextCursor;
  final bool hasMore;
}

/// Repository for notification data.
///
/// Owns all data fetching (REST + WebSocket), profile enrichment,
/// like grouping, and follow consolidation.
class NotificationRepository {
  NotificationRepository({
    required FunnelcakeApiClient funnelcakeApiClient,
    required ProfileRepository profileRepository,
    required NotificationsDao notificationsDao,
    required String userPubkey,
    NostrClient? nostrClient,
    this.authHeadersProvider,
  })  : _apiClient = funnelcakeApiClient,
        _profileRepository = profileRepository,
        _dao = notificationsDao,
        _userPubkey = userPubkey,
        _nostrClient = nostrClient;

  final FunnelcakeApiClient _apiClient;
  final ProfileRepository _profileRepository;
  final NotificationsDao _dao;
  final String _userPubkey;
  final NostrClient? _nostrClient;

  /// Optional callback to provide NIP-98 auth headers for a given URL+method.
  /// Injected from the app layer where Nip98AuthService is available.
  final Future<Map<String, String>> Function(String url, String method)?
      authHeadersProvider;

  String? _nextCursor;

  /// Fetch the next page of notifications.
  Future<NotificationPage> getNotifications({String? cursor}) async {
    final effectiveCursor = cursor ?? _nextCursor;

    // 1. Fetch raw notifications from REST API
    final authHeaders = await authHeadersProvider?.call(
      '${_apiClient.baseUrl}/api/users/$_userPubkey/notifications',
      'GET',
    );

    final response = await _apiClient.getNotifications(
      pubkey: _userPubkey,
      cursor: effectiveCursor,
      authHeaders: authHeaders,
    );

    _nextCursor = response.nextCursor;

    // 2. Consolidate follow duplicates (keep earliest per pubkey)
    final consolidated = _consolidateFollows(response.notifications);

    // 3. Enrich with profile data — AWAIT, don't fire-and-forget
    final pubkeys = consolidated
        .map((n) => n.sourcePubkey)
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();

    final profiles = pubkeys.isNotEmpty
        ? await _profileRepository.fetchBatchProfiles(pubkeys: pubkeys)
        : <String, UserProfile>{};

    // 4. Convert to domain models and group likes
    final items = _buildNotificationItems(consolidated, profiles);

    return NotificationPage(
      items: items,
      unreadCount: response.unreadCount,
      nextCursor: response.nextCursor,
      hasMore: response.hasMore,
    );
  }

  /// Fresh fetch from the beginning — used by pull-to-refresh and push nudge.
  Future<NotificationPage> refresh() {
    _nextCursor = null;
    return getNotifications();
  }

  /// Mark specific notifications as read.
  Future<void> markAsRead(List<String> ids) async {
    final authHeaders = await authHeadersProvider?.call(
      '${_apiClient.baseUrl}/api/users/$_userPubkey/notifications/read',
      'POST',
    );
    await _apiClient.markNotificationsRead(
      pubkey: _userPubkey,
      notificationIds: ids,
      authHeaders: authHeaders,
    );
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    final authHeaders = await authHeadersProvider?.call(
      '${_apiClient.baseUrl}/api/users/$_userPubkey/notifications/read',
      'POST',
    );
    await _apiClient.markNotificationsRead(
      pubkey: _userPubkey,
      authHeaders: authHeaders,
    );
  }

  /// Consolidate follow notifications — keep only the earliest per pubkey.
  /// Nostr Kind 3 is a replaceable event, so following/unfollowing republishes
  /// the entire contact list, creating duplicate follow notifications.
  List<RelayNotification> _consolidateFollows(
    List<RelayNotification> notifications,
  ) {
    final follows = <RelayNotification>[];
    final others = <RelayNotification>[];

    for (final n in notifications) {
      if (n.notificationType == 'follow' ||
          n.notificationType == 'followed' ||
          n.sourceKind == 3) {
        follows.add(n);
      } else {
        others.add(n);
      }
    }

    // Keep earliest follow per source pubkey
    final earliestByPubkey = <String, RelayNotification>{};
    for (final f in follows) {
      final existing = earliestByPubkey[f.sourcePubkey];
      if (existing == null || f.createdAt.isBefore(existing.createdAt)) {
        earliestByPubkey[f.sourcePubkey] = f;
      }
    }

    final result = [...others, ...earliestByPubkey.values];
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// Convert raw notifications to domain models, grouping likes by video.
  List<NotificationItem> _buildNotificationItems(
    List<RelayNotification> notifications,
    Map<String, UserProfile> profiles,
  ) {
    // Separate likes from everything else
    final likes = <RelayNotification>[];
    final others = <RelayNotification>[];

    for (final n in notifications) {
      final type = _mapType(n);
      if (type == NotificationType.like) {
        likes.add(n);
      } else {
        others.add(n);
      }
    }

    // Group likes by referenced video
    final likesByVideo = <String, List<RelayNotification>>{};
    final likesWithoutVideo = <RelayNotification>[];
    for (final like in likes) {
      final videoId = like.referencedEventId;
      if (videoId != null && videoId.isNotEmpty) {
        likesByVideo.putIfAbsent(videoId, () => []).add(like);
      } else {
        likesWithoutVideo.add(like);
      }
    }

    final items = <NotificationItem>[];

    // Build grouped or single likes
    for (final entry in likesByVideo.entries) {
      final videoLikes = entry.value;
      if (videoLikes.length >= 2) {
        // Group: 2+ likes on same video
        final actors = videoLikes
            .map((l) => _buildActorInfo(l.sourcePubkey, profiles))
            .take(3)
            .toList();
        items.add(GroupedNotification(
          id: 'group_${entry.key}',
          type: NotificationType.like,
          actors: actors,
          totalCount: videoLikes.length,
          timestamp: videoLikes.first.createdAt,
          isRead: videoLikes.every((l) => l.read),
          targetEventId: entry.key,
          // videoTitle: resolved later or via API enhancement
        ));
      } else {
        // Single like
        final l = videoLikes.first;
        items.add(SingleNotification(
          id: l.dedupeKey,
          type: NotificationType.like,
          actor: _buildActorInfo(l.sourcePubkey, profiles),
          timestamp: l.createdAt,
          isRead: l.read,
          targetEventId: l.referencedEventId,
        ));
      }
    }

    // Ungrouped likes (no video reference)
    for (final l in likesWithoutVideo) {
      items.add(SingleNotification(
        id: l.dedupeKey,
        type: NotificationType.like,
        actor: _buildActorInfo(l.sourcePubkey, profiles),
        timestamp: l.createdAt,
        isRead: l.read,
      ));
    }

    // Build non-like notifications
    for (final n in others) {
      final type = _mapType(n);
      items.add(SingleNotification(
        id: n.dedupeKey,
        type: type,
        actor: _buildActorInfo(n.sourcePubkey, profiles),
        timestamp: n.createdAt,
        isRead: n.read,
        targetEventId: n.referencedEventId,
        commentText: type == NotificationType.comment ||
                type == NotificationType.reply
            ? _truncateComment(n.content)
            : null,
      ));
    }

    // Sort by timestamp descending
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  ActorInfo _buildActorInfo(
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

  /// Map relay notification type string + source kind to domain enum.
  NotificationType _mapType(RelayNotification n) {
    return switch (n.notificationType.toLowerCase()) {
      'reaction' || 'like' || 'liked' || 'zap' || 'zapped' =>
        NotificationType.like,
      'reply' => NotificationType.reply,
      'comment' || 'commented' => NotificationType.comment,
      'repost' || 'reposted' => NotificationType.repost,
      'follow' || 'followed' => NotificationType.follow,
      'mention' || 'mentioned' => NotificationType.mention,
      _ => _mapFromKind(n.sourceKind),
    };
  }

  NotificationType _mapFromKind(int kind) {
    return switch (kind) {
      3 => NotificationType.follow,
      6 || 16 => NotificationType.repost,
      7 => NotificationType.like,
      1111 => NotificationType.comment,
      _ => NotificationType.system,
    };
  }

  String? _truncateComment(String? content) {
    if (content == null || content.isEmpty) return null;
    if (content.length <= 50) return content;
    return '${content.substring(0, 47)}...';
  }
}
```

- [ ] **Step 5: Run repository tests**

Run: `cd mobile && flutter test packages/notification_repository/test/src/notification_repository_test.dart`
Expected: PASS

- [ ] **Step 6: Add notification_repository to mobile/pubspec.yaml**

Add under `dependencies:`:

```yaml
notification_repository:
  path: packages/notification_repository
```

Then run: `cd mobile && flutter pub get`

- [ ] **Step 7: Commit**

```bash
git add packages/notification_repository/ mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "feat(notifications): create notification_repository package with enrichment and grouping"
```

---

## Chunk 4: BLoC Layer — NotificationFeedBloc

### Task 5: Create NotificationFeedBloc

**Files:**
- Create: `lib/notifications/bloc/notification_feed_bloc.dart`
- Create: `lib/notifications/bloc/notification_feed_event.dart`
- Create: `lib/notifications/bloc/notification_feed_state.dart`
- Test: `test/notifications/bloc/notification_feed_bloc_test.dart`

**Reference:** Follow the pattern from `lib/blocs/video_feed/video_feed_bloc.dart` for pagination and profile enrichment. Use `bloc_concurrency` transformers.

- [ ] **Step 1: Create event classes**

```dart
// lib/notifications/bloc/notification_feed_event.dart
part of 'notification_feed_bloc.dart';

sealed class NotificationFeedEvent extends Equatable {
  const NotificationFeedEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load — fetch first page from REST API.
class NotificationFeedStarted extends NotificationFeedEvent {
  const NotificationFeedStarted();
}

/// Scroll pagination — fetch next page.
class NotificationFeedLoadMore extends NotificationFeedEvent {
  const NotificationFeedLoadMore();
}

/// Pull-to-refresh or auto-refresh timer.
class NotificationFeedRefreshed extends NotificationFeedEvent {
  const NotificationFeedRefreshed();
}

/// Push notification received — re-fetch from relay.
class NotificationFeedPushReceived extends NotificationFeedEvent {
  const NotificationFeedPushReceived();
}

/// Real-time WebSocket notification arrived.
class NotificationFeedRealtimeReceived extends NotificationFeedEvent {
  const NotificationFeedRealtimeReceived({required this.notification});

  final NotificationItem notification;

  @override
  List<Object?> get props => [notification];
}

/// User tapped a notification — mark read.
class NotificationFeedItemTapped extends NotificationFeedEvent {
  const NotificationFeedItemTapped({required this.notificationId});

  final String notificationId;

  @override
  List<Object?> get props => [notificationId];
}

/// Mark all notifications as read.
class NotificationFeedMarkAllRead extends NotificationFeedEvent {
  const NotificationFeedMarkAllRead();
}

/// User tapped "Follow back" on a follow notification.
class NotificationFeedFollowBack extends NotificationFeedEvent {
  const NotificationFeedFollowBack({required this.pubkey});

  final String pubkey;

  @override
  List<Object?> get props => [pubkey];
}
```

- [ ] **Step 2: Create state class**

```dart
// lib/notifications/bloc/notification_feed_state.dart
part of 'notification_feed_bloc.dart';

enum NotificationFeedStatus { initial, loading, loaded, failure }

class NotificationFeedState extends Equatable {
  const NotificationFeedState({
    this.status = NotificationFeedStatus.initial,
    this.notifications = const [],
    this.unreadCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final NotificationFeedStatus status;
  final List<NotificationItem> notifications;
  final int unreadCount;
  final bool hasMore;
  final bool isLoadingMore;

  bool get hasUnread => unreadCount > 0;

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
```

- [ ] **Step 3: Create BLoC implementation**

```dart
// lib/notifications/bloc/notification_feed_bloc.dart
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';

part 'notification_feed_event.dart';
part 'notification_feed_state.dart';

class NotificationFeedBloc
    extends Bloc<NotificationFeedEvent, NotificationFeedState> {
  NotificationFeedBloc({
    required NotificationRepository notificationRepository,
  })  : _notificationRepository = notificationRepository,
        super(const NotificationFeedState()) {
    on<NotificationFeedStarted>(
      _onStarted,
      transformer: droppable(),
    );
    on<NotificationFeedLoadMore>(
      _onLoadMore,
      transformer: droppable(),
    );
    on<NotificationFeedRefreshed>(
      _onRefreshed,
      transformer: droppable(),
    );
    on<NotificationFeedPushReceived>(
      _onPushReceived,
      transformer: droppable(),
    );
    on<NotificationFeedRealtimeReceived>(
      _onRealtimeReceived,
    );
    on<NotificationFeedItemTapped>(
      _onItemTapped,
    );
    on<NotificationFeedMarkAllRead>(
      _onMarkAllRead,
    );
    on<NotificationFeedFollowBack>(
      _onFollowBack,
      transformer: sequential(),
    );
  }

  final NotificationRepository _notificationRepository;

  Future<void> _onStarted(
    NotificationFeedStarted event,
    Emitter<NotificationFeedState> emit,
  ) async {
    emit(state.copyWith(status: NotificationFeedStatus.loading));
    try {
      final page = await _notificationRepository.getNotifications();
      emit(state.copyWith(
        status: NotificationFeedStatus.loaded,
        notifications: page.items,
        unreadCount: page.unreadCount,
        hasMore: page.hasMore,
      ));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: NotificationFeedStatus.failure));
    }
  }

  Future<void> _onLoadMore(
    NotificationFeedLoadMore event,
    Emitter<NotificationFeedState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore) return;

    emit(state.copyWith(isLoadingMore: true));
    try {
      final page = await _notificationRepository.getNotifications();
      // Deduplicate by ID
      final existingIds = state.notifications.map((n) => n.id).toSet();
      final newItems =
          page.items.where((n) => !existingIds.contains(n.id)).toList();

      emit(state.copyWith(
        notifications: [...state.notifications, ...newItems],
        hasMore: page.hasMore,
        isLoadingMore: false,
      ));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onRefreshed(
    NotificationFeedRefreshed event,
    Emitter<NotificationFeedState> emit,
  ) async {
    try {
      final page = await _notificationRepository.refresh();
      emit(state.copyWith(
        status: NotificationFeedStatus.loaded,
        notifications: page.items,
        unreadCount: page.unreadCount,
        hasMore: page.hasMore,
      ));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }

  Future<void> _onPushReceived(
    NotificationFeedPushReceived event,
    Emitter<NotificationFeedState> emit,
  ) async {
    // Push is just a nudge — re-fetch from relay
    try {
      final page = await _notificationRepository.refresh();
      emit(state.copyWith(
        notifications: page.items,
        unreadCount: page.unreadCount,
        hasMore: page.hasMore,
      ));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }

  void _onRealtimeReceived(
    NotificationFeedRealtimeReceived event,
    Emitter<NotificationFeedState> emit,
  ) {
    // Insert at top, dedup by ID
    final existing = state.notifications.map((n) => n.id).toSet();
    if (existing.contains(event.notification.id)) return;

    emit(state.copyWith(
      notifications: [event.notification, ...state.notifications],
      unreadCount: state.unreadCount + 1,
    ));
  }

  Future<void> _onItemTapped(
    NotificationFeedItemTapped event,
    Emitter<NotificationFeedState> emit,
  ) async {
    // Mark as read locally
    final updated = state.notifications.map((n) {
      if (n.id != event.notificationId || n.isRead) return n;
      return switch (n) {
        SingleNotification() => n.copyWith(isRead: true),
        GroupedNotification() => n, // grouped items don't have copyWith yet
      };
    }).toList();

    final readCount = state.notifications
        .where((n) => n.id == event.notificationId && !n.isRead)
        .length;

    emit(state.copyWith(
      notifications: updated,
      unreadCount: (state.unreadCount - readCount).clamp(0, 999999),
    ));

    // Persist to server
    await _notificationRepository.markAsRead([event.notificationId]);
  }

  Future<void> _onMarkAllRead(
    NotificationFeedMarkAllRead event,
    Emitter<NotificationFeedState> emit,
  ) async {
    emit(state.copyWith(unreadCount: 0));
    await _notificationRepository.markAllAsRead();
  }

  Future<void> _onFollowBack(
    NotificationFeedFollowBack event,
    Emitter<NotificationFeedState> emit,
  ) async {
    // Update local state to show followed back
    final updated = state.notifications.map((n) {
      if (n is SingleNotification &&
          n.type == NotificationType.follow &&
          n.actor.pubkey == event.pubkey) {
        return n.copyWith(isFollowingBack: true);
      }
      return n;
    }).toList();

    emit(state.copyWith(notifications: updated));

    // TODO: Call follow repository when integrated
  }
}
```

- [ ] **Step 4: Write BLoC tests**

```dart
// test/notifications/bloc/notification_feed_bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:test/test.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  late _MockNotificationRepository mockRepository;

  const testActor = ActorInfo(
    pubkey: 'aabbccdd' * 8,
    displayName: 'alice_rebel',
    pictureUrl: 'https://example.com/alice.jpg',
  );

  final testNotification = SingleNotification(
    id: 'notif_1',
    type: NotificationType.like,
    actor: testActor,
    timestamp: DateTime(2026, 4, 6),
    isRead: false,
    targetEventId: '11223344' * 8,
    videoTitle: 'Best Post Ever',
  );

  setUp(() {
    mockRepository = _MockNotificationRepository();
  });

  group(NotificationFeedBloc, () {
    blocTest<NotificationFeedBloc, NotificationFeedState>(
      'emits [loading, loaded] when Started succeeds',
      setUp: () {
        when(() => mockRepository.getNotifications()).thenAnswer(
          (_) async => NotificationPage(
            items: [testNotification],
            unreadCount: 1,
            hasMore: false,
          ),
        );
      },
      build: () => NotificationFeedBloc(
        notificationRepository: mockRepository,
      ),
      act: (bloc) => bloc.add(const NotificationFeedStarted()),
      expect: () => [
        const NotificationFeedState(
          status: NotificationFeedStatus.loading,
        ),
        NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [testNotification],
          unreadCount: 1,
          hasMore: false,
        ),
      ],
    );

    blocTest<NotificationFeedBloc, NotificationFeedState>(
      'emits failure when Started throws',
      setUp: () {
        when(() => mockRepository.getNotifications())
            .thenThrow(Exception('Network error'));
      },
      build: () => NotificationFeedBloc(
        notificationRepository: mockRepository,
      ),
      act: (bloc) => bloc.add(const NotificationFeedStarted()),
      expect: () => [
        const NotificationFeedState(
          status: NotificationFeedStatus.loading,
        ),
        const NotificationFeedState(
          status: NotificationFeedStatus.failure,
        ),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<NotificationFeedBloc, NotificationFeedState>(
      'PushReceived triggers refresh',
      seed: () => NotificationFeedState(
        status: NotificationFeedStatus.loaded,
        notifications: [testNotification],
        unreadCount: 1,
      ),
      setUp: () {
        when(() => mockRepository.refresh()).thenAnswer(
          (_) async => NotificationPage(
            items: [testNotification],
            unreadCount: 3,
            hasMore: false,
          ),
        );
      },
      build: () => NotificationFeedBloc(
        notificationRepository: mockRepository,
      ),
      act: (bloc) => bloc.add(const NotificationFeedPushReceived()),
      verify: (_) {
        verify(() => mockRepository.refresh()).called(1);
      },
    );

    blocTest<NotificationFeedBloc, NotificationFeedState>(
      'MarkAllRead sets unreadCount to 0',
      seed: () => NotificationFeedState(
        status: NotificationFeedStatus.loaded,
        notifications: [testNotification],
        unreadCount: 5,
      ),
      setUp: () {
        when(() => mockRepository.markAllAsRead())
            .thenAnswer((_) async {});
      },
      build: () => NotificationFeedBloc(
        notificationRepository: mockRepository,
      ),
      act: (bloc) => bloc.add(const NotificationFeedMarkAllRead()),
      expect: () => [
        NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [testNotification],
          unreadCount: 0,
        ),
      ],
    );

    blocTest<NotificationFeedBloc, NotificationFeedState>(
      'RealtimeReceived inserts at top and increments unread',
      seed: () => NotificationFeedState(
        status: NotificationFeedStatus.loaded,
        notifications: [testNotification],
        unreadCount: 1,
      ),
      build: () => NotificationFeedBloc(
        notificationRepository: mockRepository,
      ),
      act: (bloc) {
        final newNotification = SingleNotification(
          id: 'notif_2',
          type: NotificationType.comment,
          actor: const ActorInfo(
            pubkey: '22222222' * 8,
            displayName: 'bob',
          ),
          timestamp: DateTime(2026, 4, 6, 12),
          isRead: false,
          commentText: 'Great video!',
        );
        bloc.add(NotificationFeedRealtimeReceived(
          notification: newNotification,
        ));
      },
      expect: () => [
        isA<NotificationFeedState>()
            .having((s) => s.notifications, 'notifications', hasLength(2))
            .having((s) => s.unreadCount, 'unreadCount', equals(2))
            .having(
              (s) => s.notifications.first.id,
              'first notification id',
              equals('notif_2'),
            ),
      ],
    );
  });
}
```

- [ ] **Step 5: Run BLoC tests**

Run: `cd mobile && flutter test test/notifications/bloc/notification_feed_bloc_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/notifications/bloc/ test/notifications/bloc/
git commit -m "feat(notifications): create NotificationFeedBloc with pagination, refresh, and push support"
```

---

## Chunk 5: UI Layer — Page/View and Widgets

### Task 6: Create notification widgets

**Files:**
- Create: `lib/notifications/widgets/notification_avatar_stack.dart`
- Create: `lib/notifications/widgets/notification_list_item.dart`
- Create: `lib/notifications/widgets/notification_empty_state.dart`
- Create: `lib/notifications/widgets/widgets.dart`
- Test: `test/notifications/widgets/notification_list_item_test.dart`
- Test: `test/notifications/widgets/notification_avatar_stack_test.dart`

These widgets implement the Figma design. Reference `lib/widgets/notification_list_item.dart` for the current implementation's colors and theme usage, then redesign per the spec.

**Important:** Read `packages/divine_ui/` to check for existing shared components (DivineIcon, VineTheme colors). Use `VineTheme` constants for colors — never hardcode. Check `lib/widgets/notification_list_item.dart` lines 294-309 for the current type-to-color mapping.

- [ ] **Step 1: Create NotificationAvatarStack widget**

Renders 1-3 overlapping circular avatars for grouped notifications. Read the Figma designs for spacing and overlap values.

- [ ] **Step 2: Write widget tests for NotificationAvatarStack**

Test: renders 1 avatar, renders 3 overlapping avatars, renders "+N" count circle.

- [ ] **Step 3: Create NotificationListItem widget**

Implements the Figma spec:
- `InkWell` → tap dispatches `ItemTapped` event
- Avatar (single or stacked) with type icon overlay
- Message: bold actor name + bold video title
- Comment text preview (for comment/reply types)
- Timestamp
- "Follow back" button (for follow type when `isFollowingBack` is false)
- Unread background color

Uses exhaustive `switch` on `NotificationItem`:
```dart
return switch (notification) {
  SingleNotification(:final actor, :final type) => _SingleRow(...),
  GroupedNotification(:final actors, :final totalCount) => _GroupedRow(...),
};
```

- [ ] **Step 4: Write widget tests for NotificationListItem**

Test: renders actor name, renders comment text, renders follow-back button, renders grouped avatars, bold video title, tap dispatches event.

- [ ] **Step 5: Create NotificationEmptyState widget**

Per Figma: "No activity yet — When people interact with your content, you'll see it here"

- [ ] **Step 6: Create barrel file**

```dart
// lib/notifications/widgets/widgets.dart
export 'notification_avatar_stack.dart';
export 'notification_empty_state.dart';
export 'notification_list_item.dart';
```

- [ ] **Step 7: Commit**

```bash
git add lib/notifications/widgets/ test/notifications/widgets/
git commit -m "feat(notifications): create notification widgets per Figma design"
```

---

### Task 7: Create NotificationsPage and NotificationsView

**Files:**
- Create: `lib/notifications/view/notifications_page.dart`
- Create: `lib/notifications/view/notifications_view.dart`
- Create: `lib/notifications/view/view.dart`
- Create: `lib/notifications/notifications.dart`
- Modify: `lib/router/app_router.dart` (swap screen reference)
- Test: `test/notifications/view/notifications_page_test.dart`
- Test: `test/notifications/view/notifications_view_test.dart`

**Important:** Read `lib/router/app_router.dart` lines 242-258 to understand the current routing setup. The `NotificationsScreen` uses a nested Navigator with `NavigatorKeys.notifications`. The new `NotificationsPage` must work within this same routing structure.

Also check how other BLoC-based pages provide dependencies — reference `lib/screens/feed/video_feed_page.dart` lines 29-95.

- [ ] **Step 1: Create NotificationsPage (provides BLoC)**

```dart
// lib/notifications/view/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/notifications/view/notifications_view.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  static const routeName = 'notifications';
  static const path = '/notifications';
  static const pathWithIndex = '/notifications/:index';

  static String pathForIndex([int? index]) =>
      index != null ? '/notifications/$index' : path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read dependencies from Riverpod (compatibility glue during migration)
    final notificationRepository = ref.watch(notificationRepositoryProvider);

    return BlocProvider(
      create: (_) => NotificationFeedBloc(
        notificationRepository: notificationRepository,
      )..add(const NotificationFeedStarted()),
      child: const NotificationsView(),
    );
  }
}
```

**Note:** You'll need to create a `notificationRepositoryProvider` Riverpod provider that constructs the `NotificationRepository` with its dependencies. This is the bridge between Riverpod (for dependency wiring) and BLoC (for state management).

- [ ] **Step 2: Create NotificationsView**

```dart
// lib/notifications/view/notifications_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/notifications/widgets/widgets.dart';

@visibleForTesting
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Mark all as read when screen opens
    context
        .read<NotificationFeedBloc>()
        .add(const NotificationFeedMarkAllRead());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isNearBottom) {
      context
          .read<NotificationFeedBloc>()
          .add(const NotificationFeedLoadMore());
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= maxScroll * 0.9;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<NotificationFeedBloc, NotificationFeedState>(
      listenWhen: (prev, curr) => prev.notifications != curr.notifications,
      listener: (context, state) {
        // Navigation side effects handled here
        // (e.g., when ItemTapped triggers navigation)
      },
      child: BlocBuilder<NotificationFeedBloc, NotificationFeedState>(
        builder: (context, state) {
          return switch (state.status) {
            NotificationFeedStatus.initial ||
            NotificationFeedStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            NotificationFeedStatus.failure =>
              _FailureView(onRetry: () {
                context
                    .read<NotificationFeedBloc>()
                    .add(const NotificationFeedStarted());
              }),
            NotificationFeedStatus.loaded when state.notifications.isEmpty =>
              const NotificationEmptyState(),
            NotificationFeedStatus.loaded => RefreshIndicator(
                onRefresh: () async {
                  context
                      .read<NotificationFeedBloc>()
                      .add(const NotificationFeedRefreshed());
                },
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: state.notifications.length +
                      (state.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.notifications.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final notification = state.notifications[index];
                    return NotificationListItem(
                      notification: notification,
                      onTap: () {
                        context.read<NotificationFeedBloc>().add(
                              NotificationFeedItemTapped(
                                notificationId: notification.id,
                              ),
                            );
                        _navigateToTarget(context, notification);
                      },
                      onProfileTap: () {
                        _navigateToProfile(context, notification);
                      },
                      onFollowBack: notification is SingleNotification &&
                              notification.type == NotificationType.follow &&
                              !notification.isFollowingBack
                          ? () {
                              context.read<NotificationFeedBloc>().add(
                                    NotificationFeedFollowBack(
                                      pubkey: (notification
                                              as SingleNotification)
                                          .actor
                                          .pubkey,
                                    ),
                                  );
                            }
                          : null,
                    );
                  },
                ),
              ),
          };
        },
      ),
    );
  }

  void _navigateToTarget(BuildContext context, NotificationItem notification) {
    // Navigation logic — reference current notifications_screen.dart
    // lines 422-563 for existing navigation patterns.
    // Implement: like → open video, comment → open comments overlay,
    // follow → open profile, repost → open video in feed
  }

  void _navigateToProfile(
    BuildContext context,
    NotificationItem notification,
  ) {
    // Navigate to actor's profile
    // Reference current notifications_screen.dart lines 565-574
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Failed to load notifications'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Create barrel files**

```dart
// lib/notifications/view/view.dart
export 'notifications_page.dart';
export 'notifications_view.dart';

// lib/notifications/notifications.dart
export 'bloc/notification_feed_bloc.dart';
export 'view/view.dart';
export 'widgets/widgets.dart';
```

- [ ] **Step 4: Update app router**

In `lib/router/app_router.dart`, replace the `NotificationsScreen` import and reference with `NotificationsPage`. The route path and name should remain the same for backward compatibility.

- [ ] **Step 5: Write Page/View widget tests**

Test NotificationsPage creates BlocProvider, NotificationsView renders list items when loaded, shows empty state when empty, shows loading indicator.

- [ ] **Step 6: Commit**

```bash
git add lib/notifications/ test/notifications/ lib/router/
git commit -m "feat(notifications): create NotificationsPage/View with BLoC integration"
```

---

## Chunk 6: Wiring and Cleanup

### Task 8: Create Riverpod → BLoC bridge provider

**Files:**
- Create: `lib/notifications/providers/notification_repository_provider.dart`
- Modify: `lib/notifications/notifications.dart` (add export)

Create a Riverpod provider that constructs `NotificationRepository` with all its dependencies. This is the bridge between the Riverpod DI system and the new BLoC architecture.

**Important:** Read how other repository providers are set up — search for `videosRepositoryProvider` or `profileRepositoryProvider` in `lib/providers/` to follow the existing pattern. The NIP-98 auth service is at `lib/services/nip98_auth_service.dart` — you'll need to inject it as the `authHeadersProvider` callback.

- [ ] **Step 1: Create the provider**
- [ ] **Step 2: Wire NIP-98 auth headers callback**
- [ ] **Step 3: Test provider construction**
- [ ] **Step 4: Commit**

---

### Task 9: Delete legacy notification files

**Files to delete** (only after all new code is working and tests pass):
- `lib/providers/relay_notifications_provider.dart`
- `lib/providers/notification_realtime_bridge_provider.dart`
- `lib/services/relay_notification_api_service.dart`
- `lib/services/notification_model_converter.dart`
- `lib/services/notification_helpers.dart`
- `lib/services/notification_event_parser.dart`
- `lib/services/notification_persistence.dart`
- `lib/services/notification_service_enhanced.dart`
- `lib/screens/notifications_screen.dart`
- `lib/widgets/notification_list_item.dart`

**Important:** Before deleting, grep for all imports of these files across the codebase. Some may be referenced from other screens or providers. Update or remove those imports first.

- [ ] **Step 1: Grep for all imports of legacy files**

Run: `cd mobile && grep -r "relay_notifications_provider\|notification_realtime_bridge\|relay_notification_api_service\|notification_model_converter\|notification_helpers\|notification_event_parser\|notification_persistence\|notification_service_enhanced\|notifications_screen\|notification_list_item" lib/ --include="*.dart" -l`

- [ ] **Step 2: Update all importing files to use new paths**
- [ ] **Step 3: Delete legacy files**
- [ ] **Step 4: Run full test suite**

Run: `cd mobile && flutter test`
Expected: PASS (no broken imports)

- [ ] **Step 5: Run flutter analyze**

Run: `cd mobile && flutter analyze lib test`
Expected: No issues

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(notifications): remove legacy Riverpod notification system"
```

---

### Task 10: Verify and clean up

- [ ] **Step 1: Run full test suite**

Run: `cd mobile && flutter test`

- [ ] **Step 2: Run flutter analyze**

Run: `cd mobile && flutter analyze lib test`

- [ ] **Step 3: Run dart format**

Run: `cd mobile && dart format --set-exit-if-changed lib test`

- [ ] **Step 4: Verify build**

Run: `cd mobile && flutter build apk --debug` (or `flutter build ios --no-codesign` on macOS)

- [ ] **Step 5: Check for old NotificationModel references**

Run: `cd mobile && grep -r "NotificationModel" lib/ --include="*.dart" -l`

Any remaining references should be updated to use `NotificationItem`.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "chore(notifications): final cleanup and verification"
```
