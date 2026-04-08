# Push Notification Integration — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up FCM push notifications so users receive likes, comments, follows, mentions, and reposts when the app is closed, using the deployed divine-push-service via NIP-44 encrypted registration events.

**Architecture:** Plain Dart `PushNotificationService` with constructor DI, bridged to auth via a thin Riverpod provider. FCM token registration uses NIP-44 encrypted kind 3079/3080 events published to the relay. iOS Notification Service Extension handles background delivery of data-only payloads.

**Tech Stack:** `firebase_messaging`, `flutter_local_notifications` (existing), NIP-44 v2 (existing in `packages/nostr_sdk`), Riverpod (auth glue only), Hive (preference caching)

**Spec:** `docs/superpowers/specs/2026-04-07-push-notifications-design.md`
**Issue:** #2835

---

## Chunk 1: Foundation — Environment Config, Dependency, and Core Service

### Task 1: Add `firebase_messaging` dependency and environment config

**Files:**
- Modify: `pubspec.yaml:177-189` (firebase deps section)
- Modify: `lib/models/environment_config.dart:54-125` (per-env getters)

- [ ] **Step 1: Add firebase_messaging to pubspec.yaml**

In `pubspec.yaml`, add after the existing firebase deps (around line 189, after `firebase_performance`):

```yaml
  firebase_messaging: ^16.1.1
```

- [ ] **Step 2: Run flutter pub get**

```bash
cd mobile && flutter pub get
```

Expected: Resolves successfully, `firebase_messaging` appears in `pubspec.lock`.

- [ ] **Step 3: Add pushServicePubkey to EnvironmentConfig**

In `lib/models/environment_config.dart`, add a new getter following the same switch pattern as `relayUrl` (line 54):

```dart
/// Public key of the divine-push-service for this environment.
/// Used for NIP-44 encryption of FCM token registration events.
/// Obtain from GET /health on the push service.
String get pushServicePubkey {
  switch (environment) {
    case AppEnvironment.poc:
      return 'TODO_POC_PUBKEY';
    case AppEnvironment.staging:
      return 'TODO_STAGING_PUBKEY';
    case AppEnvironment.test:
      return 'TODO_TEST_PUBKEY';
    case AppEnvironment.local:
      return 'TODO_LOCAL_PUBKEY';
    case AppEnvironment.production:
      return 'TODO_PRODUCTION_PUBKEY';
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/models/environment_config.dart
git commit -m "feat(push): add firebase_messaging dep and push service pubkey config"
```

---

### Task 2: Create NotificationPreferences model

**Files:**
- Create: `lib/models/notification_preferences.dart`
- Create: `test/models/notification_preferences_test.dart`

- [ ] **Step 1: Write the test**

```dart
// test/models/notification_preferences_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/notification_preferences.dart';

void main() {
  group(NotificationPreferences, () {
    test('defaults all preferences to true', () {
      const prefs = NotificationPreferences();
      expect(prefs.likesEnabled, isTrue);
      expect(prefs.commentsEnabled, isTrue);
      expect(prefs.followsEnabled, isTrue);
      expect(prefs.mentionsEnabled, isTrue);
      expect(prefs.repostsEnabled, isTrue);
    });

    group('toKindsList', () {
      test('returns all kinds when all enabled', () {
        const prefs = NotificationPreferences();
        expect(prefs.toKindsList(), equals([7, 1, 3, 16]));
      });

      test('excludes kind 7 when likes disabled', () {
        const prefs = NotificationPreferences(likesEnabled: false);
        expect(prefs.toKindsList(), isNot(contains(7)));
      });

      test('returns empty when all disabled', () {
        const prefs = NotificationPreferences(
          likesEnabled: false,
          commentsEnabled: false,
          followsEnabled: false,
          mentionsEnabled: false,
          repostsEnabled: false,
        );
        expect(prefs.toKindsList(), isEmpty);
      });
    });

    group('fromKindsList', () {
      test('creates preferences from kinds list', () {
        final prefs = NotificationPreferences.fromKindsList([7, 3]);
        expect(prefs.likesEnabled, isTrue);
        expect(prefs.commentsEnabled, isFalse);
        expect(prefs.followsEnabled, isTrue);
        expect(prefs.mentionsEnabled, isFalse);
        expect(prefs.repostsEnabled, isFalse);
      });

      test('creates all-enabled from full kinds list', () {
        final prefs = NotificationPreferences.fromKindsList([1, 3, 7, 16]);
        expect(prefs.likesEnabled, isTrue);
        expect(prefs.commentsEnabled, isTrue);
        expect(prefs.followsEnabled, isTrue);
        expect(prefs.mentionsEnabled, isTrue);
        expect(prefs.repostsEnabled, isTrue);
      });
    });

    group('toJson / fromJson', () {
      test('round-trips correctly', () {
        const original = NotificationPreferences(
          likesEnabled: true,
          commentsEnabled: false,
          followsEnabled: true,
          mentionsEnabled: false,
          repostsEnabled: true,
        );
        final json = original.toJson();
        final restored = NotificationPreferences.fromJson(json);
        expect(restored, equals(original));
      });
    });

    test('equality works via Equatable', () {
      const a = NotificationPreferences(likesEnabled: false);
      const b = NotificationPreferences(likesEnabled: false);
      const c = NotificationPreferences();
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd mobile && flutter test test/models/notification_preferences_test.dart
```

Expected: FAIL — `notification_preferences.dart` does not exist.

- [ ] **Step 3: Implement NotificationPreferences**

```dart
// lib/models/notification_preferences.dart
import 'package:equatable/equatable.dart';

/// User preferences for push notification types.
///
/// Maps to kind 3083 events per the NIP-XX push notification draft.
/// The push service uses the kinds list to filter which notification
/// types to deliver via FCM.
class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.likesEnabled = true,
    this.commentsEnabled = true,
    this.followsEnabled = true,
    this.mentionsEnabled = true,
    this.repostsEnabled = true,
  });

  /// Create preferences from a list of enabled Nostr event kinds.
  ///
  /// Kind mapping:
  /// - 7: reactions (likes)
  /// - 1: text notes (comments and mentions)
  /// - 3: contact list (follows)
  /// - 16: reposts
  ///
  /// Comments and mentions both use kind 1. When kind 1 is present,
  /// both are enabled. When absent, both are disabled.
  /// Known limitation: the push service filters by kind number only,
  /// so comments and mentions cannot be toggled independently.
  factory NotificationPreferences.fromKindsList(List<int> kinds) {
    return NotificationPreferences(
      likesEnabled: kinds.contains(7),
      commentsEnabled: kinds.contains(1),
      followsEnabled: kinds.contains(3),
      mentionsEnabled: kinds.contains(1),
      repostsEnabled: kinds.contains(16),
    );
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      likesEnabled: json['likesEnabled'] as bool? ?? true,
      commentsEnabled: json['commentsEnabled'] as bool? ?? true,
      followsEnabled: json['followsEnabled'] as bool? ?? true,
      mentionsEnabled: json['mentionsEnabled'] as bool? ?? true,
      repostsEnabled: json['repostsEnabled'] as bool? ?? true,
    );
  }

  final bool likesEnabled;
  final bool commentsEnabled;
  final bool followsEnabled;
  final bool mentionsEnabled;
  final bool repostsEnabled;

  /// Convert to the kinds list format expected by the push service.
  ///
  /// Returns deduplicated list of Nostr event kinds.
  List<int> toKindsList() {
    final kinds = <int>{};
    if (likesEnabled) kinds.add(7);
    if (commentsEnabled || mentionsEnabled) kinds.add(1);
    if (followsEnabled) kinds.add(3);
    if (repostsEnabled) kinds.add(16);
    return kinds.toList()..sort();
  }

  Map<String, dynamic> toJson() {
    return {
      'likesEnabled': likesEnabled,
      'commentsEnabled': commentsEnabled,
      'followsEnabled': followsEnabled,
      'mentionsEnabled': mentionsEnabled,
      'repostsEnabled': repostsEnabled,
    };
  }

  NotificationPreferences copyWith({
    bool? likesEnabled,
    bool? commentsEnabled,
    bool? followsEnabled,
    bool? mentionsEnabled,
    bool? repostsEnabled,
  }) {
    return NotificationPreferences(
      likesEnabled: likesEnabled ?? this.likesEnabled,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      followsEnabled: followsEnabled ?? this.followsEnabled,
      mentionsEnabled: mentionsEnabled ?? this.mentionsEnabled,
      repostsEnabled: repostsEnabled ?? this.repostsEnabled,
    );
  }

  @override
  List<Object?> get props => [
        likesEnabled,
        commentsEnabled,
        followsEnabled,
        mentionsEnabled,
        repostsEnabled,
      ];
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd mobile && flutter test test/models/notification_preferences_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/notification_preferences.dart test/models/notification_preferences_test.dart
git commit -m "feat(push): add NotificationPreferences model with kind mapping"
```

---

### Task 3: Create PushNotificationService — registration and deregistration

This is the core service. It's a plain Dart class with constructor-injected dependencies. It does NOT depend on Riverpod or BLoC — those are wired in separately.

**Files:**
- Create: `lib/services/push_notification_service.dart`
- Create: `test/services/push_notification_service_test.dart`

**Key references:**
- NIP-44 encryption: `lib/services/auth_service_signer.dart:133-170` — `nip44Encrypt(pubkey, plaintext)` method on AuthService's signer
- Event creation/signing: `lib/services/auth_service.dart:2681-2743` — `createAndSignEvent(kind:, content:, tags:)` method
- Event publishing: `lib/services/video_event_publisher.dart:84-237` — `nostrService.publishEvent(event)` pattern
- NostrService provider: `lib/providers/nostr_client_provider.dart:1-120` — `nostrServiceProvider`

**Dependencies the service needs:**
- `AuthService` — for `createAndSignEvent()` (event signing)
- `NostrClient` — for `publishEvent()` and `signer.nip44Encrypt()` (NIP-44 encryption lives on `NostrClient.signer`, which is an `AuthServiceSigner` implementing `NostrSigner`)
- `NotificationService` — singleton for displaying foreground notifications
- `EnvironmentConfig` — for `pushServicePubkey` and `relayUrl`
- `FirebaseMessaging` — for FCM token (abstracted via a function parameter for testability)

**Key API note:** `nip44Encrypt(pubkey, plaintext)` is on `NostrClient.signer` (type `NostrSigner`), NOT on `AuthService`. See `lib/services/auth_service_signer.dart:133`.

- [ ] **Step 1: Write tests for registration**

```dart
// test/services/push_notification_service_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/push_notification_service.dart';

@GenerateNiceMocks([
  MockSpec<AuthService>(),
  MockSpec<NostrClient>(),
  MockSpec<NotificationService>(),
])
import 'push_notification_service_test.mocks.dart';

void main() {
  late PushNotificationService service;
  late MockAuthService mockAuthService;
  late MockNostrClient mockNostrClient;
  late MockNotificationService mockNotificationService;
  late EnvironmentConfig envConfig;

  setUp(() {
    mockAuthService = MockAuthService();
    mockNostrClient = MockNostrClient();
    mockNotificationService = MockNotificationService();
    envConfig = EnvironmentConfig(environment: AppEnvironment.poc);

    service = PushNotificationService(
      authService: mockAuthService,
      nostrClient: mockNostrClient,
      notificationService: mockNotificationService,
      environmentConfig: envConfig,
      getToken: () async => 'test-fcm-token-123',
      onTokenRefresh: Stream<String>.empty(),
    );
  });

  group('register', () {
    test('publishes kind 3079 event with NIP-44 encrypted token', () async {
      final mockEvent = Event(
        'test-pubkey-hex',
        3079,
        [
          ['p', envConfig.pushServicePubkey],
          ['app', 'co.openvine.app'],
        ],
        'encrypted-content',
      );

      when(mockNostrClient.signer.nip44Encrypt(any, any))
          .thenAnswer((_) async => 'nip44-encrypted-token-json');
      when(mockAuthService.createAndSignEvent(
        kind: anyNamed('kind'),
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async => mockEvent);
      when(mockNostrClient.publishEvent(any))
          .thenAnswer((_) async => mockEvent);

      await service.register('test-pubkey-hex');

      // Verify NIP-44 encryption was called with push service pubkey
      verify(mockNostrClient.signer.nip44Encrypt(
        envConfig.pushServicePubkey,
        argThat(contains('"token"')),
      )).called(1);

      // Verify event was created with correct kind and tags
      verify(mockAuthService.createAndSignEvent(
        kind: 3079,
        content: 'nip44-encrypted-token-json',
        tags: argThat(
          allOf(
            contains(['p', envConfig.pushServicePubkey]),
            contains(['app', 'co.openvine.app']),
          ),
          named: 'tags',
        ),
      )).called(1);

      // Verify event was published
      verify(mockNostrClient.publishEvent(mockEvent)).called(1);
    });

    test('skips registration when FCM token is null', () async {
      service = PushNotificationService(
        authService: mockAuthService,
        nostrClient: mockNostrClient,
        notificationService: mockNotificationService,
        environmentConfig: envConfig,
        getToken: () async => null,
        onTokenRefresh: Stream<String>.empty(),
      );

      await service.register('test-pubkey-hex');

      verifyNever(mockAuthService.nip44Encrypt(any, any));
      verifyNever(mockAuthService.createAndSignEvent(
        kind: anyNamed('kind'),
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      ));
    });

    test('skips registration when NIP-44 encryption fails', () async {
      when(mockNostrClient.signer.nip44Encrypt(any, any))
          .thenAnswer((_) async => null);

      await service.register('test-pubkey-hex');

      verifyNever(mockAuthService.createAndSignEvent(
        kind: anyNamed('kind'),
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      ));
    });
  });

  group('deregister', () {
    test('publishes kind 3080 event', () async {
      final mockEvent = Event(
        'test-pubkey-hex',
        3080,
        [
          ['p', envConfig.pushServicePubkey],
          ['app', 'co.openvine.app'],
        ],
        'encrypted-content',
      );

      when(mockNostrClient.signer.nip44Encrypt(any, any))
          .thenAnswer((_) async => 'nip44-encrypted-deregister');
      when(mockAuthService.createAndSignEvent(
        kind: anyNamed('kind'),
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async => mockEvent);
      when(mockNostrClient.publishEvent(any))
          .thenAnswer((_) async => mockEvent);

      // Must register first to have a token cached
      await service.register('test-pubkey-hex');

      await service.deregister('test-pubkey-hex');

      verify(mockAuthService.createAndSignEvent(
        kind: 3080,
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).called(1);
    });
  });

  group('token refresh', () {
    test('re-registers when token refreshes and user is authenticated',
        () async {
      final tokenController = StreamController<String>();

      when(mockNostrClient.signer.nip44Encrypt(any, any))
          .thenAnswer((_) async => 'encrypted');
      when(mockAuthService.createAndSignEvent(
        kind: anyNamed('kind'),
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((_) async {
        final event = Event('pub', 3079, [], 'encrypted');
        return event;
      });
      when(mockNostrClient.publishEvent(any))
          .thenAnswer((_) async => Event('pub', 3079, [], ''));
      when(mockAuthService.currentPublicKeyHex).thenReturn('test-pubkey-hex');

      service = PushNotificationService(
        authService: mockAuthService,
        nostrClient: mockNostrClient,
        notificationService: mockNotificationService,
        environmentConfig: envConfig,
        getToken: () async => 'initial-token',
        onTokenRefresh: tokenController.stream,
      );

      // Initial registration
      await service.register('test-pubkey-hex');

      // Simulate token refresh
      tokenController.add('new-token-456');
      await Future<void>.delayed(Duration.zero);

      // Should have registered twice (initial + refresh)
      verify(mockAuthService.createAndSignEvent(
        kind: 3079,
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).called(2);

      await tokenController.close();
    });
  });
}
```

- [ ] **Step 2: Run build_runner to generate mocks**

```bash
cd mobile && dart run build_runner build --delete-conflicting-outputs
```

Expected: Generates `push_notification_service_test.mocks.dart`.

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd mobile && flutter test test/services/push_notification_service_test.dart
```

Expected: FAIL — `push_notification_service.dart` does not exist.

- [ ] **Step 4: Implement PushNotificationService**

```dart
// lib/services/push_notification_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/utils/log.dart';

/// Nostr event kind for push token registration (NIP-XX draft).
const int pushRegistrationKind = 3079;

/// Nostr event kind for push token deregistration (NIP-XX draft).
const int pushDeregistrationKind = 3080;

/// Nostr event kind for notification preferences (NIP-XX draft).
const int pushPreferencesKind = 3083;

/// App identifier used in push registration events.
const String pushAppIdentifier = 'co.openvine.app';

/// Token expiration window in days.
const int pushTokenExpirationDays = 90;

/// Manages FCM push notification lifecycle: token registration,
/// deregistration, foreground message display, and preferences.
///
/// This is a plain Dart class with no framework dependencies.
/// Dependencies are constructor-injected for testability.
class PushNotificationService {
  PushNotificationService({
    required AuthService authService,
    required NostrClient nostrClient,
    required NotificationService notificationService,
    required EnvironmentConfig environmentConfig,
    required Future<String?> Function() getToken,
    required Stream<String> onTokenRefresh,
  })  : _authService = authService,
        _nostrClient = nostrClient,
        _notificationService = notificationService,
        _environmentConfig = environmentConfig,
        _getToken = getToken,
        _onTokenRefresh = onTokenRefresh {
    _tokenRefreshSubscription = _onTokenRefresh.listen(_onTokenRefreshed);
  }

  final AuthService _authService;
  final NostrClient _nostrClient;
  final NotificationService _notificationService;
  final EnvironmentConfig _environmentConfig;
  final Future<String?> Function() _getToken;
  final Stream<String> _onTokenRefresh;

  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentToken;
  String? _registeredPubkey;

  /// Register the device's FCM token with the push service.
  ///
  /// Creates a kind 3079 event with the FCM token NIP-44 encrypted
  /// to the push service's pubkey, and publishes it to the relay.
  Future<void> register(String userPubkey) async {
    if (kIsWeb) {
      Log.info(
        'Push notifications not supported on web, skipping registration',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    final token = _currentToken ?? await _getToken();
    if (token == null) {
      Log.warning(
        'No FCM token available, skipping push registration',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }
    _currentToken = token;
    _registeredPubkey = userPubkey;

    await _publishTokenEvent(
      kind: pushRegistrationKind,
      token: token,
    );
  }

  /// Deregister the device's FCM token from the push service.
  ///
  /// Creates a kind 3080 event and publishes it to the relay.
  Future<void> deregister(String userPubkey) async {
    if (kIsWeb) return;

    final token = _currentToken;
    if (token == null) {
      Log.warning(
        'No FCM token cached, skipping push deregistration',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    await _publishTokenEvent(
      kind: pushDeregistrationKind,
      token: token,
    );

    _registeredPubkey = null;
  }

  /// Publish notification preferences as a kind 3083 event.
  Future<void> updatePreferences(NotificationPreferences prefs) async {
    if (kIsWeb) return;

    final pushServicePubkey = _environmentConfig.pushServicePubkey;
    final kindsJson = jsonEncode({'kinds': prefs.toKindsList()});

    final encrypted = await _nostrClient.signer.nip44Encrypt(
      pushServicePubkey,
      kindsJson,
    );
    if (encrypted == null) {
      Log.error(
        'Failed to encrypt notification preferences',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    final event = await _authService.createAndSignEvent(
      kind: pushPreferencesKind,
      content: encrypted,
      tags: [
        ['p', pushServicePubkey],
      ],
    );
    if (event == null) {
      Log.error(
        'Failed to sign preferences event',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    await _nostrClient.publishEvent(event);

    Log.info(
      'Published notification preferences (kinds: ${prefs.toKindsList()})',
      name: 'PushNotificationService',
      category: LogCategory.system,
    );
  }

  /// Handle a foreground FCM data message by displaying a local notification.
  ///
  /// Parses the data-only payload from divine-push-service and delegates
  /// to NotificationService for display.
  Future<void> handleForegroundMessage(Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? 'diVine';
    final body = data['body'] as String? ?? '';
    final referencedEventId = data['referencedEventId'] as String?;

    await _notificationService.sendLocal(
      title: title,
      body: body,
    );

    Log.info(
      'Displayed foreground push notification: $title '
      '(ref: ${referencedEventId ?? "none"})',
      name: 'PushNotificationService',
      category: LogCategory.system,
    );
  }

  /// Cancel subscriptions and clean up.
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  Future<void> _publishTokenEvent({
    required int kind,
    required String token,
  }) async {
    final pushServicePubkey = _environmentConfig.pushServicePubkey;
    final tokenJson = jsonEncode({'token': token});

    final encrypted = await _nostrClient.signer.nip44Encrypt(
      pushServicePubkey,
      tokenJson,
    );
    if (encrypted == null) {
      Log.error(
        'Failed to NIP-44 encrypt FCM token for kind $kind',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    final expirationTimestamp =
        DateTime.now().add(const Duration(days: pushTokenExpirationDays));
    final expirationSecs =
        (expirationTimestamp.millisecondsSinceEpoch ~/ 1000).toString();

    final event = await _authService.createAndSignEvent(
      kind: kind,
      content: encrypted,
      tags: [
        ['p', pushServicePubkey],
        ['app', pushAppIdentifier],
        ['expiration', expirationSecs],
      ],
    );

    if (event == null) {
      Log.error(
        'Failed to create/sign kind $kind event',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      return;
    }

    await _nostrClient.publishEvent(event);

    final label = kind == pushRegistrationKind ? 'registered' : 'deregistered';
    Log.info(
      'Push token $label successfully (event: ${event.id})',
      name: 'PushNotificationService',
      category: LogCategory.system,
    );
  }

  Future<void> _onTokenRefreshed(String newToken) async {
    _currentToken = newToken;
    final pubkey = _registeredPubkey;
    if (pubkey != null) {
      Log.info(
        'FCM token refreshed, re-registering',
        name: 'PushNotificationService',
        category: LogCategory.system,
      );
      try {
        await register(pubkey);
      } on Exception catch (e) {
        Log.error(
          'Failed to re-register after token refresh: $e',
          name: 'PushNotificationService',
          category: LogCategory.system,
        );
      }
    }
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd mobile && flutter test test/services/push_notification_service_test.dart
```

Expected: All tests PASS.

Note: `nip44Encrypt` lives on `NostrClient.signer` (type `NostrSigner`, implemented by `AuthServiceSigner`). The `MockNostrClient` needs to return a mock signer — either mock `NostrSigner` separately or use `MockSpec<NostrClient>()` which will auto-mock the getter. If Mockito doesn't auto-mock the `signer` getter, add `MockSpec<NostrSigner>()` to the `@GenerateNiceMocks` annotation and set up `when(mockNostrClient.signer).thenReturn(mockSigner)`.

- [ ] **Step 6: Commit**

```bash
git add lib/services/push_notification_service.dart test/services/push_notification_service_test.dart test/services/push_notification_service_test.mocks.dart
git commit -m "feat(push): implement PushNotificationService with registration and deregistration"
```

---

### Task 4: Add foreground message handling tests

**Files:**
- Modify: `test/services/push_notification_service_test.dart`

- [ ] **Step 1: Add foreground message tests**

Append to the test file's `main()`:

```dart
group('handleForegroundMessage', () {
  test('displays local notification with title and body from data', () async {
    when(mockNotificationService.sendLocal(
      title: anyNamed('title'),
      body: anyNamed('body'),
    )).thenAnswer((_) async {});

    await service.handleForegroundMessage({
      'type': 'Like',
      'title': 'New like',
      'body': 'Alice liked your post',
      'senderPubkey': 'abc123',
      'senderName': 'Alice',
      'eventKind': '7',
      'referencedEventId': 'event123',
    });

    verify(mockNotificationService.sendLocal(
      title: 'New like',
      body: 'Alice liked your post',
    )).called(1);
  });

  test('uses default title when data has no title', () async {
    when(mockNotificationService.sendLocal(
      title: anyNamed('title'),
      body: anyNamed('body'),
    )).thenAnswer((_) async {});

    await service.handleForegroundMessage({
      'type': 'Follow',
      'body': 'Bob followed you',
    });

    verify(mockNotificationService.sendLocal(
      title: 'diVine',
      body: 'Bob followed you',
    )).called(1);
  });
});

group('updatePreferences', () {
  test('publishes kind 3083 event with encrypted kinds list', () async {
    const prefs = NotificationPreferences(
      likesEnabled: true,
      commentsEnabled: true,
      followsEnabled: false,
      mentionsEnabled: true,
      repostsEnabled: false,
    );

    when(mockNostrClient.signer.nip44Encrypt(any, any))
        .thenAnswer((_) async => 'encrypted-prefs');
    when(mockAuthService.createAndSignEvent(
      kind: anyNamed('kind'),
      content: anyNamed('content'),
      tags: anyNamed('tags'),
    )).thenAnswer((_) async {
      final event = Event('pub', pushPreferencesKind, [], 'encrypted-prefs');
      return event;
    });
    when(mockNostrClient.publishEvent(any))
        .thenAnswer((_) async => Event('pub', 3083, [], ''));

    await service.updatePreferences(prefs);

    verify(mockNostrClient.signer.nip44Encrypt(
      envConfig.pushServicePubkey,
      argThat(contains('"kinds"')),
    )).called(1);

    verify(mockAuthService.createAndSignEvent(
      kind: pushPreferencesKind,
      content: 'encrypted-prefs',
      tags: argThat(
        contains(['p', envConfig.pushServicePubkey]),
        named: 'tags',
      ),
    )).called(1);
  });
});
```

- [ ] **Step 2: Run tests**

```bash
cd mobile && flutter test test/services/push_notification_service_test.dart
```

Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add test/services/push_notification_service_test.dart
git commit -m "test(push): add foreground message and preferences tests"
```

---

## Chunk 2: App Integration — Startup, Auth Bridge, and Background Handler

### Task 5: Wire PushNotificationService into app startup

**Files:**
- Modify: `lib/main.dart:102-270` (StartupCoordinator)
- Modify: `lib/providers/app_providers.dart:1039-1073` (add push auth bridge)

- [ ] **Step 1: Add push service registration to StartupCoordinator**

In `lib/main.dart`, add a new deferred service registration after the ZendeskSupport registration (around line 267). First add the import at the top:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:openvine/services/push_notification_service.dart';
```

Add the top-level background handler function OUTSIDE any class (Firebase requires this):

```dart
/// Top-level background message handler required by Firebase.
///
/// Must be a top-level function, not a class method.
/// Receives data-only FCM payloads when app is in background/terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialized before using any Firebase services.
  await Firebase.initializeApp();

  final data = message.data;
  final title = data['title'] as String? ?? 'diVine';
  final body = data['body'] as String? ?? '';

  if (body.isEmpty) return;

  // Use flutter_local_notifications directly since we can't access
  // the full service graph from a background isolate.
  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: darwinInit,
    macOS: darwinInit,
  );
  await plugin.initialize(initSettings);

  final androidDetails = AndroidNotificationDetails(
    'openvine_push',
    'Push Notifications',
    channelDescription: 'Notifications from diVine',
    importance: Importance.high,
    priority: Priority.high,
  );
  final details = NotificationDetails(
    android: androidDetails,
    iOS: const DarwinNotificationDetails(),
  );

  await plugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
    payload: data['referencedEventId'],
  );
}
```

Add the service registration inside `_createStartupCoordinator`:

```dart
coordinator.registerService(
  name: 'PushNotifications',
  phase: StartupPhase.deferred,
  initialize: () async {
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );
    // The auth-reactive provider in app_providers.dart handles
    // registration/deregistration. We just need to set the
    // background handler here.
  },
  optional: true,
);
```

- [ ] **Step 2: Add auth-reactive push provider in app_providers.dart**

In `lib/providers/app_providers.dart`, add after the `zendeskIdentitySync` provider (around line 1073):

```dart
/// Bridges auth state changes to push notification registration.
///
/// Registers FCM token on login, deregisters on logout.
/// Same pattern as [zendeskIdentitySync].
@Riverpod(keepAlive: true)
void pushNotificationSync(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final nostrClient = ref.watch(nostrServiceProvider);
  final notificationService = NotificationService();
  final envConfig = ref.watch(currentEnvironmentProvider);

  final pushService = PushNotificationService(
    authService: authService,
    nostrClient: nostrClient,
    notificationService: notificationService,
    environmentConfig: envConfig,
    getToken: () => FirebaseMessaging.instance.getToken(),
    onTokenRefresh: FirebaseMessaging.instance.onTokenRefresh,
  );

  // Register immediately if already authenticated
  final pubkey = authService.currentPublicKeyHex;
  if (pubkey != null &&
      authService.authState == AuthState.authenticated) {
    pushService.register(pubkey);
  }

  // React to auth state changes
  final subscription =
      authService.authStateStream.listen((authState) async {
    final currentPubkey = authService.currentPublicKeyHex;
    if (authState == AuthState.authenticated && currentPubkey != null) {
      await pushService.register(currentPubkey);
    } else if (authState == AuthState.unauthenticated &&
        currentPubkey != null) {
      await pushService.deregister(currentPubkey);
    }
  });

  // Set up foreground message handler
  FirebaseMessaging.instance.onMessage.listen((message) {
    pushService.handleForegroundMessage(message.data);
  });

  ref.onDispose(() {
    subscription.cancel();
    pushService.dispose();
  });
}
```

Add the necessary imports at the top of `app_providers.dart`:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:openvine/services/push_notification_service.dart';
```

- [ ] **Step 3: Initialize the push provider on app start**

In `lib/main.dart`, find where `zendeskIdentitySyncProvider` is initialized (search for it). Add the push provider initialization nearby:

```dart
container.read(pushNotificationSyncProvider);
```

- [ ] **Step 4: Run build_runner to generate the provider**

```bash
cd mobile && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5: Run the analyzer**

```bash
cd mobile && flutter analyze lib/main.dart lib/providers/app_providers.dart lib/services/push_notification_service.dart
```

Expected: No errors in our files (pre-existing errors in test golden files are separate).

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart lib/providers/app_providers.dart lib/providers/app_providers.g.dart
git commit -m "feat(push): wire push service into app startup and auth state"
```

---

### Task 6: Handle cold-start notification taps

When the app is launched by tapping a push notification, route to the referenced content.

**Files:**
- Modify: `lib/main.dart` (check initial message on startup)

- [ ] **Step 1: Add initial message check after app startup**

In `lib/main.dart`, find the deferred startup phase initialization (where services run after `runApp`). After the push service initialization, add:

```dart
// Check if app was launched from a push notification tap
final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
if (initialMessage != null) {
  final referencedEventId =
      initialMessage.data['referencedEventId'] as String?;
  if (referencedEventId != null) {
    Log.info(
      'App launched from push notification, target: $referencedEventId',
      name: 'main',
      category: LogCategory.system,
    );
    // Navigation will be handled by the router once the app
    // is fully initialized. Store the target for the router to pick up.
    // TODO: Wire to NotificationTargetResolver and router
  }
}
```

Also add the `onMessageOpenedApp` handler for taps while app is in background:

```dart
FirebaseMessaging.onMessageOpenedApp.listen((message) {
  final referencedEventId =
      message.data['referencedEventId'] as String?;
  if (referencedEventId != null) {
    Log.info(
      'Push notification tapped (background), target: $referencedEventId',
      name: 'main',
      category: LogCategory.system,
    );
    // TODO: Navigate to the referenced event via router
  }
});
```

- [ ] **Step 2: Commit**

```bash
git add lib/main.dart
git commit -m "feat(push): handle cold-start and background notification taps"
```

---

## Chunk 3: Notification Settings and Kind 3083 Preferences

### Task 7: Wire notification settings screen to Kind 3083

**Files:**
- Modify: `lib/screens/notification_settings_screen.dart:26-58` (toggle state)
- Create: `test/screens/notification_settings_screen_test.dart` (or modify if exists)

- [ ] **Step 1: Refactor notification settings to use PushNotificationService**

The current screen uses local `setState` variables. We need to:
1. Load preferences from Hive cache on init
2. On toggle change, update Hive cache and publish kind 3083

In `lib/screens/notification_settings_screen.dart`, update the state class:

Add imports:

```dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/push_notification_service.dart';
```

Change the state class to use `ConsumerStatefulWidget` pattern (or add Riverpod access):

Replace the toggle state variables (lines 26-34) and add persistence:

```dart
// Replace the individual bool fields with:
NotificationPreferences _preferences = const NotificationPreferences();
bool _pushNotificationsEnabled = true;
bool _soundEnabled = true;
bool _vibrationEnabled = true;

@override
void initState() {
  super.initState();
  _loadPreferences();
}

Future<void> _loadPreferences() async {
  final box = await Hive.openBox<dynamic>('notifications');
  final stored = box.get('push_preferences') as String?;
  if (stored != null) {
    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      setState(() {
        _preferences = NotificationPreferences.fromJson(json);
      });
    } on FormatException {
      // Corrupted cache, use defaults
    }
  }
}

Future<void> _updatePreference(NotificationPreferences newPrefs) async {
  setState(() {
    _preferences = newPrefs;
  });

  // Persist to Hive cache
  final box = await Hive.openBox<dynamic>('notifications');
  await box.put('push_preferences', jsonEncode(newPrefs.toJson()));

  // Publish kind 3083 to relay
  // Access PushNotificationService via the provider
  // This will be wired through the widget's context
}
```

Update each toggle's `onChanged` to use the preferences model:

```dart
// Instead of: setState(() => _likesEnabled = value)
// Use:
_updatePreference(_preferences.copyWith(likesEnabled: value));
```

Update the reset action:

```dart
Future<void> _resetPreferences() async {
  await _updatePreference(const NotificationPreferences());
}
```

- [ ] **Step 2: Write tests for the preference persistence**

```dart
// test/screens/notification_settings_screen_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/notification_preferences.dart';

void main() {
  group('NotificationPreferences persistence', () {
    test('toJson/fromJson round-trips', () {
      const prefs = NotificationPreferences(
        likesEnabled: true,
        commentsEnabled: false,
        followsEnabled: true,
        mentionsEnabled: false,
        repostsEnabled: true,
      );
      final json = prefs.toJson();
      final restored = NotificationPreferences.fromJson(json);
      expect(restored, equals(prefs));
    });

    test('toKindsList maps preferences to NIP-XX kinds', () {
      const prefs = NotificationPreferences(
        likesEnabled: true,
        commentsEnabled: false,
        followsEnabled: true,
        mentionsEnabled: false,
        repostsEnabled: false,
      );
      expect(prefs.toKindsList(), equals([3, 7]));
    });
  });
}
```

- [ ] **Step 3: Run tests**

```bash
cd mobile && flutter test test/screens/notification_settings_screen_test.dart test/models/notification_preferences_test.dart
```

Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/notification_settings_screen.dart test/screens/notification_settings_screen_test.dart
git commit -m "feat(push): wire notification settings to Kind 3083 preferences"
```

---

## Chunk 4: iOS Notification Service Extension

### Task 8: Create iOS Notification Service Extension

The NSE is required for reliable delivery of data-only FCM messages on iOS when the app is suspended or killed.

**Files:**
- Create: `ios/NotificationServiceExtension/NotificationService.swift`
- Create: `ios/NotificationServiceExtension/Info.plist`
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (add NSE target)

**Important:** This task involves Xcode project modification which is complex to do purely via text editing. The recommended approach is to use Xcode to add the target, then commit the generated files.

- [ ] **Step 1: Create the NSE Swift source file**

```swift
// ios/NotificationServiceExtension/NotificationService.swift
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // Parse data-only FCM payload from divine-push-service
        let userInfo = request.content.userInfo

        // FCM wraps data in different keys depending on payload structure
        let data: [String: Any]
        if let fcmData = userInfo["data"] as? [String: Any] {
            data = fcmData
        } else {
            data = userInfo as? [String: Any] ?? [:]
        }

        // Set notification content from data payload
        if let title = data["title"] as? String {
            bestAttemptContent.title = title
        }
        if let body = data["body"] as? String {
            bestAttemptContent.body = body
        }

        // Preserve referenced event ID for tap routing
        if let referencedEventId = data["referencedEventId"] as? String {
            bestAttemptContent.userInfo["referencedEventId"] = referencedEventId
        }

        // Set category for notification actions (future use)
        if let type = data["type"] as? String {
            bestAttemptContent.categoryIdentifier = "divine_\(type.lowercased())"
        }

        // Set thread identifier for grouping
        bestAttemptContent.threadIdentifier = "divine_notifications"

        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Deliver the best attempt at modified content.
        if let contentHandler = contentHandler,
           let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
```

- [ ] **Step 2: Create the NSE Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.usernotifications.service</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).NotificationService</string>
    </dict>
    <key>MinimumOSVersion</key>
    <string>16.0</string>
</dict>
</plist>
```

- [ ] **Step 3: Add NSE target to Xcode project**

This is best done in Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode
2. File > New > Target > Notification Service Extension
3. Product Name: `NotificationServiceExtension`
4. Bundle Identifier: `co.openvine.app.NotificationServiceExtension`
5. Language: Swift
6. Replace the generated `NotificationService.swift` with our version from Step 1
7. Replace the generated `Info.plist` with our version from Step 2

Alternatively, if doing via CLI, the `project.pbxproj` changes are extensive. The safer approach is Xcode.

- [ ] **Step 4: Add push notification entitlement**

Create `ios/NotificationServiceExtension/NotificationServiceExtension.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.co.openvine.app</string>
    </array>
</dict>
</plist>
```

Also update the main app's `ios/Runner/Runner.entitlements` to add the same app group:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.co.openvine.app</string>
</array>
<key>aps-environment</key>
<string>development</string>
```

- [ ] **Step 5: Add push notification background mode to main app Info.plist**

In `ios/Runner/Info.plist`, add:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

- [ ] **Step 6: Verify iOS build**

```bash
cd mobile && flutter build ios --no-codesign --debug
```

Expected: Build succeeds. (Codesign will fail without provisioning profiles, but the build itself should work.)

- [ ] **Step 7: Commit**

```bash
git add ios/
git commit -m "feat(push): add iOS Notification Service Extension for background delivery"
```

---

## Chunk 5: Android Configuration

### Task 9: Configure Android for FCM

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add notification permission for Android 13+**

In `android/app/src/main/AndroidManifest.xml`, add the POST_NOTIFICATIONS permission (if not already present):

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

- [ ] **Step 2: Add default notification channel metadata**

Inside the `<application>` tag in `AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="openvine_push" />
```

- [ ] **Step 3: Verify Android build**

```bash
cd mobile && flutter build apk --debug
```

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add android/
git commit -m "feat(push): configure Android for FCM notifications"
```

---

## Chunk 6: Final Integration and Verification

### Task 10: Request notification permissions on first login

**Files:**
- Modify: `lib/providers/app_providers.dart` (push provider)

- [ ] **Step 1: Add permission request to push provider**

In the `pushNotificationSync` provider, before registering, request permissions:

```dart
// Request notification permissions (iOS will show a dialog,
// Android 13+ will show a runtime permission dialog)
final settings = await FirebaseMessaging.instance.requestPermission();
if (settings.authorizationStatus == AuthorizationStatus.denied) {
  Log.info(
    'Push notification permission denied by user',
    name: 'pushNotificationSync',
    category: LogCategory.system,
  );
  return;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/app_providers.dart
git commit -m "feat(push): request notification permissions before registration"
```

---

### Task 11: End-to-end verification checklist

- [ ] **Step 1: Run all push-related tests**

```bash
cd mobile && flutter test test/models/notification_preferences_test.dart test/services/push_notification_service_test.dart
```

Expected: All tests PASS.

- [ ] **Step 2: Run the analyzer on changed files**

```bash
cd mobile && flutter analyze lib/services/push_notification_service.dart lib/models/notification_preferences.dart lib/models/environment_config.dart lib/providers/app_providers.dart lib/main.dart lib/screens/notification_settings_screen.dart
```

Expected: No errors.

- [ ] **Step 3: Verify format**

```bash
cd mobile && dart format --output=none --set-exit-if-changed lib/services/push_notification_service.dart lib/models/notification_preferences.dart lib/models/environment_config.dart lib/screens/notification_settings_screen.dart
```

Expected: No formatting issues.

- [ ] **Step 4: Manual verification plan**

Test against POC environment:
1. Build and run on physical iOS device with `--dart-define=DEFAULT_ENV=POC`
2. Login — verify in logs: "Push token registered successfully"
3. Have another account react/comment on a video — verify notification appears
4. Kill the app — verify background notification arrives (iOS NSE)
5. Tap notification — verify app opens (navigation routing is TODO for now)
6. Go to notification settings, toggle likes off — verify kind 3083 event in logs
7. Logout — verify in logs: "Push token deregistered"
8. Login again — verify re-registration

- [ ] **Step 5: Create PR**

```bash
git push -u origin feat/push-notifications
gh pr create --title "feat: add FCM push notification support" --body "$(cat <<'EOF'
## Summary
- Adds FCM push notification registration via NIP-44 encrypted kind 3079/3080 events
- Handles foreground, background, and cold-start notification delivery
- Wires notification settings UI to kind 3083 preference events
- Adds iOS Notification Service Extension for reliable background delivery
- Per-environment push service pubkey configuration (pubkeys TBD from Daniel)

Closes #2835

## Test plan
- [ ] Unit tests for PushNotificationService (registration, deregistration, foreground handling, preferences)
- [ ] Unit tests for NotificationPreferences model
- [ ] Manual test on iOS physical device against POC environment
- [ ] Manual test on Android physical device against POC environment
- [ ] Verify background notification delivery (kill app, send notification)
- [ ] Verify notification settings toggles persist and publish kind 3083
- [ ] Coordinate with Daniel to verify push service receives registration events

## Dependencies
- divine-push-service must be running on target environment
- Push service pubkeys need to be filled in for each environment
- Production allowlist must include tester pubkeys

## Notes
- Notification tap-to-navigate routing is scaffolded but needs full router integration
- iOS NSE requires provisioning profile setup in Apple Developer account
EOF
)"
```
