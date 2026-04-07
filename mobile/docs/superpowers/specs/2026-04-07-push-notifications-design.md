# Push Notification Integration Design

**Issue:** [#2835](https://github.com/divinevideo/divine-mobile/issues/2835)
**Predecessor:** [PR #1806](https://github.com/divinevideo/divine-mobile/pull/1806) (closed, merge conflicts)
**Date:** 2026-04-07

## Context

The divine-push-service is live on all GKE environments (poc, staging, production). It subscribes to the relay, watches for Nostr events that should trigger notifications, and delivers them via FCM. Production currently has a pubkey allowlist (6 pubkeys) as a feature flag.

The mobile app needs to:
1. Register FCM tokens with the push service via NIP-44 encrypted kind 3079 events
2. Handle incoming FCM messages (foreground, background, cold-start tap)
3. Publish notification preferences via kind 3083 events
4. Support iOS Notification Service Extension for reliable background delivery

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ App Startup (StartupCoordinator, deferred phase)        │
│   └─ Initialize PushNotificationService                 │
│       ├─ Request FCM token from firebase_messaging      │
│       ├─ Set foreground message handler                 │
│       └─ Set background message handler (top-level fn)  │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Riverpod Provider (auth-reactive glue, app_providers)   │
│   watches authStateStream                               │
│   ├─ authenticated → service.register(pubkey, fcmToken) │
│   └─ unauthenticated → service.deregister(pubkey)      │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│ PushNotificationService (pure Dart, constructor DI)     │
│   ├─ register(): NIP-44 encrypt FCM token to push       │
│   │   service pubkey, publish kind 3079 to relay        │
│   ├─ deregister(): publish kind 3080 to relay           │
│   ├─ updatePreferences(): publish kind 3083 to relay    │
│   ├─ handleForegroundMessage(): parse data payload,     │
│   │   display via NotificationService.sendLocal()       │
│   └─ handleBackgroundMessage(): top-level function,     │
│       parse data payload, show local notification       │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Relay (wss://relay.divine.video per env)                │
│   ← kind 3079/3080/3083 events published here          │
│   → divine-push-service subscribes, decrypts tokens     │
│   → divine-push-service sends FCM data-only messages    │
└─────────────────────────────────────────────────────────┘
```

### Design Decisions

- **PushNotificationService is a plain Dart class** — no BLoC, no Riverpod. Dependencies injected via constructor. Fully unit-testable.
- **Thin Riverpod provider bridges auth state** — same pattern as Zendesk identity sync in `app_providers.dart`. Watches `authStateStream`, delegates to the service.
- **Background message handler is a top-level function** — Firebase requirement. Creates a minimal local notification from the data payload.
- **BLoC is not used** — this service has no UI state to manage. The BLoC-first rule applies to UI features; infrastructure services are plain Dart classes with DI.

## Components

### 1. PushNotificationService

**File:** `lib/services/push_notification_service.dart`

Core service handling all push notification logic.

**Dependencies (constructor-injected):**
- `AuthService` — for signing Nostr events
- `NostrService` — for publishing events to relay
- `NotificationService` — for displaying local notifications
- `EnvironmentConfig` — for push service pubkey and relay URL

**Methods:**
- `initialize()` — request FCM token, set up `onTokenRefresh` listener, set foreground handler
- `register(String userPubkey)` — NIP-44 encrypt `{"token": "<fcm_token>"}` to push service pubkey, publish kind 3079 with tags: `p` (push service pubkey), `app` (`co.openvine.app`), `expiration` (90 days from now)
- `deregister(String userPubkey)` — publish kind 3080 (same structure, encrypted deregistration)
- `updatePreferences(NotificationPreferences prefs)` — publish kind 3083 with NIP-44 encrypted preferences JSON
- `loadPreferences(String userPubkey)` — fetch kind 3083 from relay, decrypt, return preferences
- `dispose()` — cancel token refresh subscription

**Token refresh:** Listens to `FirebaseMessaging.instance.onTokenRefresh`. On refresh, re-registers with new token if user is authenticated.

### 2. Environment Config Updates

**File:** `lib/models/environment_config.dart`

Add per-environment:
```dart
String get pushServicePubkey {
  switch (environment) {
    case AppEnvironment.poc:
      return 'TODO_POC_PUBKEY';
    case AppEnvironment.staging:
      return 'TODO_STAGING_PUBKEY';
    case AppEnvironment.production:
      return 'TODO_PRODUCTION_PUBKEY';
    case AppEnvironment.test:
      return 'TODO_TEST_PUBKEY';
    case AppEnvironment.local:
      return 'TODO_LOCAL_PUBKEY';
  }
}
```

Pubkeys are obtained from each environment's push service `/health` endpoint. Daniel to provide these values.

### 3. Auth-Reactive Provider

**File:** `lib/providers/app_providers.dart`

Thin provider that watches `authService.authStateStream`:
- On `AuthState.authenticated`: calls `pushService.register(pubkey)`
- On `AuthState.unauthenticated`: calls `pushService.deregister(pubkey)` before cleanup

Same pattern as the existing Zendesk identity sync provider (~15 lines).

### 4. Startup Integration

**File:** `lib/main.dart`

- Register `PushNotificationService` in `StartupCoordinator` at `StartupPhase.deferred`
- Set `FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler)` as top-level function
- On cold-start from notification tap: check `FirebaseMessaging.instance.getInitialMessage()` in app startup, route via `NotificationTargetResolver`

### 5. Notification Display & Tap Routing

**File:** `lib/services/notification_service.dart`

Minor updates:
- Add `showPushNotification(Map<String, dynamic> data)` method that parses FCM data payload fields (`type`, `title`, `body`, `senderName`, `referencedEventId`) and creates a local notification
- On tap: use `NotificationTargetResolver.resolveVideoEventIdFromNotificationTarget(referencedEventId)` to navigate to the correct video

### 6. Kind 3083 Notification Preferences

**File:** `lib/services/push_notification_service.dart` (same service)
**File:** `lib/screens/notification_settings_screen.dart` (UI wiring)

**Preference model:**
```dart
class NotificationPreferences {
  final bool likesEnabled;      // kind 7
  final bool commentsEnabled;   // kind 1 (with e-tag)
  final bool followsEnabled;    // kind 3
  final bool mentionsEnabled;   // kind 1 (p-tag only)
  final bool repostsEnabled;    // kind 16
}
```

**Flow:**
1. On login, `loadPreferences()` fetches the latest kind 3083 event from the relay, decrypts it, returns `NotificationPreferences`
2. Settings screen reads preferences from local cache (Hive `notifications` box)
3. On toggle change, publishes kind 3083 event with updated preferences and updates Hive cache
4. Push service server reads kind 3083 to filter which notification types to send

**Kind 3083 event format** (per NIP-XX draft):
```json
{
  "kind": 3083,
  "content": "<NIP-44 encrypted JSON>",
  "tags": [["p", "<push_service_pubkey>"]],
  "created_at": 1712345678
}
```

Decrypted content maps to the push service's expected format:
```json
{"kinds": [1, 3, 7, 16]}
```

### 7. iOS Notification Service Extension (NSE)

**Directory:** `ios/NotificationServiceExtension/`

Required for reliable delivery of data-only FCM messages on iOS when the app is suspended or killed. Without an NSE, iOS may silently drop data-only messages.

**Files:**
- `ios/NotificationServiceExtension/NotificationService.swift` — parses FCM data payload, constructs `UNNotificationContent`, displays notification
- `ios/NotificationServiceExtension/Info.plist` — NSE configuration
- `ios/NotificationServiceExtension/NotificationServiceExtension.entitlements` — push notification capability

**Configuration:**
- Bundle ID: `co.openvine.app.NotificationServiceExtension`
- Minimum iOS: 16.0 (matches main app)
- Needs its own provisioning profile with push capability
- App Groups entitlement (`group.co.openvine.app`) shared with main app for data access if needed

**NSE behavior:**
1. iOS wakes the NSE when a data-only push arrives
2. NSE reads `data.title`, `data.body`, `data.type`, `data.referencedEventId`
3. NSE constructs a `UNMutableNotificationContent` with the parsed fields
4. NSE sets `userInfo` with `referencedEventId` for tap routing
5. iOS displays the notification

**Important:** The FCM payload must include `"content_available": true` and `"mutable_content": true` in the APNS config for the NSE to be invoked. This is a server-side (divine-push-service) configuration.

### 8. Production Allowlist

The production push service has a pubkey allowlist as a feature flag. Options:

1. **Coordinate with Daniel** to add test pubkeys during development, then remove the allowlist once verified
2. **App handles rejection gracefully** — if the kind 3079 event is published but the push service ignores it (pubkey not in allowlist), the app doesn't error. Registration is fire-and-forget from the client's perspective since it's a relay publish.
3. **Use POC/staging for development** — test against poc environment where there's no allowlist restriction

Recommendation: develop against POC, coordinate with Daniel to add tester pubkeys to production allowlist, then remove allowlist once mobile integration is verified.

## FCM Payload Format

Data-only messages from divine-push-service (all values are strings):

```json
{
  "data": {
    "type": "Like|Comment|Follow|Mention|Repost",
    "eventId": "<hex event id>",
    "title": "New like",
    "body": "Alice liked your post",
    "senderPubkey": "<hex pubkey>",
    "senderName": "Alice",
    "receiverPubkey": "<hex pubkey>",
    "receiverNpub": "npub1...",
    "eventKind": "7",
    "timestamp": "1712345678",
    "referencedEventId": "<hex event id>"
  }
}
```

## Dependencies

**New:**
- `firebase_messaging: ^16.1.1` — FCM token management, message handlers

**Existing (already in pubspec):**
- `firebase_core` — Firebase initialization
- `flutter_local_notifications` — local notification display
- NIP-44 encryption — `packages/nostr_sdk/lib/nip44/`

## Testing Strategy

**Unit tests** (`test/services/push_notification_service_test.dart`):
- Registration publishes kind 3079 with correct NIP-44 encrypted content and tags
- Deregistration publishes kind 3080
- Token refresh triggers re-registration
- Foreground message parsing extracts correct fields from data payload
- Preferences update publishes kind 3083
- Preferences load decrypts kind 3083 correctly
- Service skips registration on web platform
- Service handles missing FCM token gracefully

**Widget tests** (`test/screens/notification_settings_screen_test.dart`):
- Toggle changes trigger preference publish
- Preferences load on screen open
- Reset restores defaults and publishes

**Integration consideration:**
- Test against POC environment with real relay
- Verify FCM token delivery end-to-end with divine-push-service logs

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `lib/services/push_notification_service.dart` | Create | Core push service |
| `lib/models/environment_config.dart` | Modify | Add pushServicePubkey per env |
| `lib/providers/app_providers.dart` | Modify | Add auth-reactive push provider |
| `lib/main.dart` | Modify | Startup registration, background handler |
| `lib/services/notification_service.dart` | Modify | Add push notification display method |
| `lib/screens/notification_settings_screen.dart` | Modify | Wire toggles to kind 3083 |
| `pubspec.yaml` | Modify | Add firebase_messaging |
| `ios/NotificationServiceExtension/` | Create | iOS NSE target |
| `ios/Runner.xcodeproj/project.pbxproj` | Modify | Add NSE target |
| `ios/Podfile` | Modify | Add NSE target if needed |
| `test/services/push_notification_service_test.dart` | Create | Unit tests |
| `test/screens/notification_settings_screen_test.dart` | Modify | Preference toggle tests |
