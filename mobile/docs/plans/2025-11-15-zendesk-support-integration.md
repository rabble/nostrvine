Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Zendesk Support SDK Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate Zendesk Support SDK into OpenVine to replace unreliable Cloudflare Worker bug reporting with native ticket creation UI and reliable backend.

**Architecture:** Minimal Flutter platform channel wrapper around official Zendesk iOS/Android SDKs. Native code handles all Zendesk interaction and UI presentation. Graceful fallback to email when credentials not configured. Reuses existing diagnostic collection from BugReportService.

**Tech Stack:** Flutter, Dart, Swift (iOS), Kotlin (Android), Zendesk Support SDK 5.x, MethodChannel

---

## Prerequisites

- [ ] Zendesk account credentials (appId, clientId, zendeskUrl) available
- [ ] Branch: `feature/zendesk-support-integration` checked out
- [ ] Working directory: `/Users/rabble/code/andotherstuff/openvine/mobile`

---

## Task 1: Configuration Setup

**Files:**
- Create: `lib/config/zendesk_config.dart`
- Create: `.env.example`
- Modify: `.gitignore`

**Step 1: Write failing test for ZendeskConfig**

Create: `test/config/zendesk_config_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/zendesk_config.dart';

void main() {
  group('ZendeskConfig', () {
    test('appId should be defined from environment', () {
      expect(ZendeskConfig.appId, isA<String>());
    });

    test('clientId should be defined from environment', () {
      expect(ZendeskConfig.clientId, isA<String>());
    });

    test('zendeskUrl should have default value', () {
      expect(ZendeskConfig.zendeskUrl, isNotEmpty);
      expect(ZendeskConfig.zendeskUrl, contains('zendesk.com'));
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/rabble/code/andotherstuff/openvine/mobile
flutter test test/config/zendesk_config_test.dart
```

Expected: FAIL with "Target of URI doesn't exist: 'package:openvine/config/zendesk_config.dart'"

**Step 3: Write minimal implementation**

Create: `lib/config/zendesk_config.dart`

```dart
// ABOUTME: Configuration for Zendesk Support SDK credentials
// ABOUTME: Loads from build-time environment variables to keep secrets out of source

/// Zendesk Support SDK configuration
class ZendeskConfig {
  /// Zendesk application ID
  /// Set via: --dart-define=ZENDESK_APP_ID=xxx
  static const String appId = String.fromEnvironment(
    'ZENDESK_APP_ID',
    defaultValue: '',
  );

  /// Zendesk client ID (OAuth)
  /// Set via: --dart-define=ZENDESK_CLIENT_ID=xxx
  static const String clientId = String.fromEnvironment(
    'ZENDESK_CLIENT_ID',
    defaultValue: '',
  );

  /// Zendesk instance URL
  /// Set via: --dart-define=ZENDESK_URL=xxx
  static const String zendeskUrl = String.fromEnvironment(
    'ZENDESK_URL',
    defaultValue: 'https://openvine.zendesk.com',
  );
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/config/zendesk_config_test.dart
```

Expected: PASS (all 3 tests passing)

**Step 5: Create .env.example template**

Create: `.env.example`

```bash
# Zendesk Support SDK Credentials
# Copy to .env and fill in actual values
ZENDESK_APP_ID=
ZENDESK_CLIENT_ID=
ZENDESK_URL=https://openvine.zendesk.com
```

**Step 6: Ensure .env is gitignored**

Modify: `.gitignore`

Add this line if not already present:

```
.env
```

**Step 7: Commit**

```bash
git add lib/config/zendesk_config.dart test/config/zendesk_config_test.dart .env.example .gitignore
git commit -m "feat: add Zendesk configuration with environment variables

- ZendeskConfig reads credentials from dart-define
- .env.example template for developers
- Tests verify config structure"
```

---

## Task 2: Flutter Service Layer - ZendeskSupportService

**Files:**
- Create: `lib/services/zendesk_support_service.dart`
- Create: `test/services/zendesk_support_service_test.dart`

**Step 1: Write failing test for initialize()**

Create: `test/services/zendesk_support_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:openvine/services/zendesk_support_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.openvine/zendesk_support');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('ZendeskSupportService.initialize', () {
    test('returns false when credentials empty', () async {
      final result = await ZendeskSupportService.initialize(
        appId: '',
        clientId: '',
        zendeskUrl: '',
      );

      expect(result, false);
      expect(ZendeskSupportService.isAvailable, false);
    });

    test('returns true when native initialization succeeds', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'initialize') {
          expect(call.arguments['appId'], 'test_app_id');
          expect(call.arguments['clientId'], 'test_client_id');
          expect(call.arguments['zendeskUrl'], 'https://test.zendesk.com');
          return true;
        }
        return null;
      });

      final result = await ZendeskSupportService.initialize(
        appId: 'test_app_id',
        clientId: 'test_client_id',
        zendeskUrl: 'https://test.zendesk.com',
      );

      expect(result, true);
      expect(ZendeskSupportService.isAvailable, true);
    });

    test('returns false when native initialization fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'initialize') {
          throw PlatformException(code: 'INIT_FAILED', message: 'Failed');
        }
        return null;
      });

      final result = await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      expect(result, false);
      expect(ZendeskSupportService.isAvailable, false);
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/services/zendesk_support_service_test.dart
```

Expected: FAIL with "Target of URI doesn't exist: 'package:openvine/services/zendesk_support_service.dart'"

**Step 3: Write minimal implementation for initialize()**

Create: `lib/services/zendesk_support_service.dart`

```dart
// ABOUTME: Flutter platform channel wrapper for Zendesk Support SDK
// ABOUTME: Provides ticket creation and support features via native iOS/Android SDKs

import 'package:flutter/services.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for interacting with Zendesk Support SDK
class ZendeskSupportService {
  static const MethodChannel _channel =
      MethodChannel('com.openvine/zendesk_support');

  static bool _initialized = false;

  /// Check if Zendesk is available (credentials configured and initialized)
  static bool get isAvailable => _initialized;

  /// Initialize Zendesk SDK
  ///
  /// Call once at app startup. Returns true if initialization successful.
  /// Returns false if credentials missing or initialization fails.
  /// App continues to work with email fallback when returns false.
  static Future<bool> initialize({
    required String appId,
    required String clientId,
    required String zendeskUrl,
  }) async {
    // Skip if credentials missing
    if (appId.isEmpty || clientId.isEmpty || zendeskUrl.isEmpty) {
      Log.info(
        'Zendesk credentials not configured - bug reports will use email fallback',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      final result = await _channel.invokeMethod('initialize', {
        'appId': appId,
        'clientId': clientId,
        'zendeskUrl': zendeskUrl,
      });

      _initialized = (result == true);

      if (_initialized) {
        Log.info('✅ Zendesk initialized successfully', category: LogCategory.system);
      } else {
        Log.warning(
          'Zendesk initialization failed - bug reports will use email fallback',
          category: LogCategory.system,
        );
      }

      return _initialized;
    } on PlatformException catch (e) {
      Log.error(
        'Zendesk initialization failed: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );
      _initialized = false;
      return false;
    } catch (e) {
      Log.error('Unexpected error initializing Zendesk: $e', category: LogCategory.system);
      _initialized = false;
      return false;
    }
  }
}
```

**Step 4: Run test to verify it passes**

```bash
flutter test test/services/zendesk_support_service_test.dart
```

Expected: PASS (3 tests passing)

**Step 5: Write failing test for showNewTicketScreen()**

Add to: `test/services/zendesk_support_service_test.dart`

```dart
  group('ZendeskSupportService.showNewTicketScreen', () {
    test('returns false when not initialized', () async {
      final result = await ZendeskSupportService.showNewTicketScreen();

      expect(result, false);
    });

    test('passes parameters correctly to native', () async {
      // Initialize first
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'showNewTicket') {
          expect(call.arguments['subject'], 'Test Subject');
          expect(call.arguments['description'], 'Test Description');
          expect(call.arguments['tags'], ['tag1', 'tag2']);
          return null;
        }
        return null;
      });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.showNewTicketScreen(
        subject: 'Test Subject',
        description: 'Test Description',
        tags: ['tag1', 'tag2'],
      );

      expect(result, true);
    });

    test('handles PlatformException gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'showNewTicket') {
          throw PlatformException(code: 'SHOW_FAILED', message: 'Failed');
        }
        return null;
      });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.showNewTicketScreen();

      expect(result, false);
    });
  });
```

**Step 6: Run test to verify it fails**

```bash
flutter test test/services/zendesk_support_service_test.dart
```

Expected: FAIL with "The method 'showNewTicketScreen' isn't defined"

**Step 7: Implement showNewTicketScreen()**

Add to: `lib/services/zendesk_support_service.dart`

```dart
  /// Show native Zendesk ticket creation screen
  ///
  /// Presents the native Zendesk UI for creating a support ticket.
  /// Returns true if screen shown, false if Zendesk not initialized.
  static Future<bool> showNewTicketScreen({
    String? subject,
    String? description,
    List<String>? tags,
  }) async {
    if (!_initialized) {
      Log.warning(
        'Zendesk not initialized - cannot show ticket screen',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      await _channel.invokeMethod('showNewTicket', {
        'subject': subject,
        'description': description,
        'tags': tags,
      });

      Log.info('Zendesk ticket screen shown', category: LogCategory.system);
      return true;
    } on PlatformException catch (e) {
      Log.error(
        'Failed to show Zendesk ticket screen: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );
      return false;
    } catch (e) {
      Log.error('Unexpected error showing Zendesk screen: $e', category: LogCategory.system);
      return false;
    }
  }
```

**Step 8: Run test to verify it passes**

```bash
flutter test test/services/zendesk_support_service_test.dart
```

Expected: PASS (6 tests passing)

**Step 9: Write failing test for showTicketListScreen()**

Add to: `test/services/zendesk_support_service_test.dart`

```dart
  group('ZendeskSupportService.showTicketListScreen', () {
    test('returns false when not initialized', () async {
      final result = await ZendeskSupportService.showTicketListScreen();

      expect(result, false);
    });

    test('calls native method when initialized', () async {
      var showTicketListCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'showTicketList') {
          showTicketListCalled = true;
          return null;
        }
        return null;
      });

      await ZendeskSupportService.initialize(
        appId: 'test',
        clientId: 'test',
        zendeskUrl: 'https://test.zendesk.com',
      );

      final result = await ZendeskSupportService.showTicketListScreen();

      expect(result, true);
      expect(showTicketListCalled, true);
    });
  });
```

**Step 10: Run test to verify it fails**

```bash
flutter test test/services/zendesk_support_service_test.dart
```

Expected: FAIL with "The method 'showTicketListScreen' isn't defined"

**Step 11: Implement showTicketListScreen()**

Add to: `lib/services/zendesk_support_service.dart`

```dart
  /// Show user's ticket list (support history)
  ///
  /// Presents the native Zendesk UI showing all tickets from this user.
  /// Returns true if screen shown, false if Zendesk not initialized.
  static Future<bool> showTicketListScreen() async {
    if (!_initialized) {
      Log.warning(
        'Zendesk not initialized - cannot show ticket list',
        category: LogCategory.system,
      );
      return false;
    }

    try {
      await _channel.invokeMethod('showTicketList');
      Log.info('Zendesk ticket list shown', category: LogCategory.system);
      return true;
    } on PlatformException catch (e) {
      Log.error(
        'Failed to show Zendesk ticket list: ${e.code} - ${e.message}',
        category: LogCategory.system,
      );
      return false;
    } catch (e) {
      Log.error('Unexpected error showing ticket list: $e', category: LogCategory.system);
      return false;
    }
  }
```

**Step 12: Run all tests to verify they pass**

```bash
flutter test test/services/zendesk_support_service_test.dart
```

Expected: PASS (8 tests passing)

**Step 13: Commit**

```bash
git add lib/services/zendesk_support_service.dart test/services/zendesk_support_service_test.dart
git commit -m "feat: add ZendeskSupportService with platform channel

- initialize() with credential validation and error handling
- showNewTicketScreen() with subject/description/tags
- showTicketListScreen() for support history
- Comprehensive unit tests with mocked MethodChannel
- Graceful degradation when not initialized"
```

---

## Task 3: iOS Platform Channel Implementation

**Files:**
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `ios/Podfile`

**Step 1: Add Zendesk SDK dependency to Podfile**

Modify: `ios/Podfile`

Add after existing pods (before `end` in the `target 'Runner'` block):

```ruby
  # Zendesk Support SDK
  pod 'ZendeskSupportSDK', '~> 5.3'
```

**Step 2: Install pods**

```bash
cd ios
pod install
cd ..
```

Expected: CocoaPods installs ZendeskSupportSDK and dependencies

**Step 3: Write iOS platform channel handler**

Modify: `ios/Runner/AppDelegate.swift`

Add these imports at the top:

```swift
import ZendeskCoreSDK
import SupportSDK
```

Add this method before the closing brace of `AppDelegate` class:

```swift
  private func setupZendeskChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      NSLog("❌ Zendesk: Could not get FlutterViewController")
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.openvine/zendesk_support",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self,
            let controller = self.window?.rootViewController as? FlutterViewController else {
        result(FlutterError(code: "NO_CONTROLLER", message: "FlutterViewController not available", details: nil))
        return
      }

      switch call.method {
      case "initialize":
        guard let args = call.arguments as? [String: Any],
              let appId = args["appId"] as? String,
              let clientId = args["clientId"] as? String,
              let zendeskUrl = args["zendeskUrl"] as? String else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "appId, clientId, and zendeskUrl are required",
            details: nil
          ))
          return
        }

        NSLog("🎫 Zendesk: Initializing with URL: \(zendeskUrl)")

        // Initialize Zendesk Core SDK
        Zendesk.initialize(appId: appId, clientId: clientId, zendeskUrl: zendeskUrl)

        // Initialize Support SDK
        Support.initialize(withZendesk: Zendesk.instance)

        // Set anonymous identity by default
        let identity = Identity.createAnonymous()
        Zendesk.instance?.setIdentity(identity)

        NSLog("✅ Zendesk: Initialized successfully")
        result(true)

      case "showNewTicket":
        let args = call.arguments as? [String: Any]
        let subject = args?["subject"] as? String ?? ""
        let description = args?["description"] as? String ?? ""
        let tags = args?["tags"] as? [String] ?? []

        NSLog("🎫 Zendesk: Showing new ticket screen")

        // Configure request UI
        let config = RequestUiConfiguration()
        config.subject = subject
        config.tags = tags

        // Build request screen
        let requestScreen = RequestUi.buildRequestUi(with: [config])

        // Present modally
        controller.present(requestScreen, animated: true) {
          NSLog("✅ Zendesk: Ticket screen presented")
        }

        result(true)

      case "showTicketList":
        NSLog("🎫 Zendesk: Showing ticket list screen")

        // Build request list screen
        let requestListScreen = RequestUi.buildRequestList()

        // Present modally
        controller.present(requestListScreen, animated: true) {
          NSLog("✅ Zendesk: Ticket list presented")
        }

        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("✅ Zendesk: Platform channel registered")
  }
```

**Step 4: Call setupZendeskChannel() in didFinishLaunchingWithOptions**

Modify: `ios/Runner/AppDelegate.swift`

In the `application(_:didFinishLaunchingWithOptions:)` method, add this line after `setupProofModeChannel()`:

```swift
    setupZendeskChannel()
```

**Step 5: Build iOS to verify compilation**

```bash
flutter build ios --no-codesign
```

Expected: Build succeeds without errors

**Step 6: Commit**

```bash
git add ios/Runner/AppDelegate.swift ios/Podfile ios/Podfile.lock
git commit -m "feat(ios): implement Zendesk platform channel

- Add ZendeskSupportSDK pod dependency
- Implement initialize, showNewTicket, showTicketList handlers
- Use native Zendesk UI via RequestUi builders
- Set anonymous identity by default"
```

---

## Task 4: Android Platform Channel Implementation

**Files:**
- Modify: `android/app/src/main/kotlin/co/openvine/app/MainActivity.kt`
- Modify: `android/app/build.gradle`

**Step 1: Add Zendesk SDK dependency to build.gradle**

Modify: `android/app/build.gradle`

In the `dependencies` block, add:

```gradle
    // Zendesk Support SDK
    implementation 'com.zendesk:support:5.1.2'
```

**Step 2: Sync Gradle**

```bash
cd android
./gradlew build
cd ..
```

Expected: Gradle syncs and downloads Zendesk SDK

**Step 3: Write Android platform channel handler**

Modify: `android/app/src/main/kotlin/co/openvine/app/MainActivity.kt`

Add these imports at the top:

```kotlin
import zendesk.core.AnonymousIdentity
import zendesk.core.Zendesk
import zendesk.support.Support
import zendesk.support.request.RequestActivity
import zendesk.support.requestlist.RequestListActivity
```

Add this method before the closing brace of `MainActivity` class:

```kotlin
    private fun setupZendeskChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.openvine/zendesk_support"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val appId = call.argument<String>("appId")
                    val clientId = call.argument<String>("clientId")
                    val zendeskUrl = call.argument<String>("zendeskUrl")

                    if (appId == null || clientId == null || zendeskUrl == null) {
                        result.error(
                            "INVALID_ARGUMENT",
                            "appId, clientId, and zendeskUrl are required",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        Log.d(TAG, "🎫 Initializing Zendesk with URL: $zendeskUrl")

                        // Initialize Zendesk Core SDK
                        Zendesk.INSTANCE.init(
                            this,
                            zendeskUrl,
                            appId,
                            clientId
                        )

                        // Initialize Support SDK
                        Support.INSTANCE.init(Zendesk.INSTANCE)

                        // Set anonymous identity by default
                        Zendesk.INSTANCE.setIdentity(AnonymousIdentity())

                        Log.d(TAG, "✅ Zendesk initialized successfully")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to initialize Zendesk", e)
                        result.error("INIT_FAILED", e.message, null)
                    }
                }

                "showNewTicket" -> {
                    try {
                        val subject = call.argument<String>("subject") ?: ""
                        val description = call.argument<String>("description") ?: ""
                        val tags = call.argument<List<String>>("tags") ?: emptyList()

                        Log.d(TAG, "🎫 Showing new ticket screen")

                        // Build and show request activity
                        RequestActivity.builder()
                            .withRequestSubject(subject)
                            .withTags(tags)
                            .show(this)

                        Log.d(TAG, "✅ Ticket screen shown")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to show ticket screen", e)
                        result.error("SHOW_TICKET_FAILED", e.message, null)
                    }
                }

                "showTicketList" -> {
                    try {
                        Log.d(TAG, "🎫 Showing ticket list screen")

                        RequestListActivity.builder().show(this)

                        Log.d(TAG, "✅ Ticket list shown")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to show ticket list", e)
                        result.error("SHOW_LIST_FAILED", e.message, null)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        Log.d(TAG, "✅ Zendesk platform channel registered")
    }
```

**Step 4: Call setupZendeskChannel() in configureFlutterEngine**

Modify: `android/app/src/main/kotlin/co/openvine/app/MainActivity.kt`

In the `configureFlutterEngine` method, add this line after the ProofMode channel setup:

```kotlin
        setupZendeskChannel(flutterEngine)
```

**Step 5: Build Android to verify compilation**

```bash
flutter build apk --debug
```

Expected: Build succeeds without errors

**Step 6: Commit**

```bash
git add android/app/src/main/kotlin/co/openvine/app/MainActivity.kt android/app/build.gradle
git commit -m "feat(android): implement Zendesk platform channel

- Add Zendesk Support SDK dependency
- Implement initialize, showNewTicket, showTicketList handlers
- Use native Zendesk Activities for UI
- Set anonymous identity by default"
```

---

## Task 5: App Initialization Integration

**Files:**
- Modify: `lib/main.dart`

**Step 1: Write integration test for Zendesk initialization at startup**

Create: `test/integration/zendesk_initialization_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/config/zendesk_config.dart';
import 'package:openvine/services/zendesk_support_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Zendesk Initialization', () {
    testWidgets('initialize at startup handles missing credentials gracefully',
        (tester) async {
      // This test verifies app doesn't crash when Zendesk credentials missing
      // Initialize with empty credentials (simulating no .env file)
      final result = await ZendeskSupportService.initialize(
        appId: '',
        clientId: '',
        zendeskUrl: '',
      );

      expect(result, false);
      expect(ZendeskSupportService.isAvailable, false);
      // App should continue normally
    });

    testWidgets('initialize with real credentials if configured',
        (tester) async {
      // Skip if credentials not configured
      if (ZendeskConfig.appId.isEmpty) {
        return;
      }

      final result = await ZendeskSupportService.initialize(
        appId: ZendeskConfig.appId,
        clientId: ZendeskConfig.clientId,
        zendeskUrl: ZendeskConfig.zendeskUrl,
      );

      expect(result, true);
      expect(ZendeskSupportService.isAvailable, true);
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
flutter test test/integration/zendesk_initialization_test.dart
```

Expected: Tests pass (integration test just verifies no crash)

**Step 3: Add Zendesk initialization to main.dart**

Modify: `lib/main.dart`

In the `main()` function, add this code after `WidgetsFlutterBinding.ensureInitialized()` and before any other async initialization:

```dart
  // Initialize Zendesk (graceful failure if no credentials)
  await ZendeskSupportService.initialize(
    appId: ZendeskConfig.appId,
    clientId: ZendeskConfig.clientId,
    zendeskUrl: ZendeskConfig.zendeskUrl,
  );
```

Add these imports at the top of `lib/main.dart`:

```dart
import 'package:openvine/config/zendesk_config.dart';
import 'package:openvine/services/zendesk_support_service.dart';
```

**Step 4: Test app startup without credentials**

```bash
flutter run --dart-define=ZENDESK_APP_ID= --dart-define=ZENDESK_CLIENT_ID= --dart-define=ZENDESK_URL=
```

Expected: App starts normally, logs show "Zendesk credentials not configured"

**Step 5: Commit**

```bash
git add lib/main.dart test/integration/zendesk_initialization_test.dart
git commit -m "feat: initialize Zendesk at app startup

- Call ZendeskSupportService.initialize() in main()
- Graceful handling when credentials not configured
- Integration test verifies no crash on missing credentials"
```

---

## Task 6: Settings Screen Integration

**Files:**
- Modify: `lib/screens/settings_screen.dart`

**Step 1: Write widget test for bug report button**

Create: `test/widgets/settings_screen_bug_report_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/settings_screen.dart';

void main() {
  testWidgets('Settings screen has Report Bug button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(),
      ),
    );

    expect(find.text('Report a Bug'), findsOneWidget);
    expect(find.byIcon(Icons.bug_report), findsOneWidget);
  });

  testWidgets('Tapping Report Bug shows loading then handles result',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(),
      ),
    );

    await tester.tap(find.text('Report a Bug'));
    await tester.pump();

    // Should show loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

**Step 2: Run test to baseline current behavior**

```bash
flutter test test/widgets/settings_screen_bug_report_test.dart
```

Expected: May pass or fail depending on current implementation

**Step 3: Add helper method to format diagnostics**

Add to: `lib/screens/settings_screen.dart`

At the bottom of the `_SettingsScreenState` class, add:

```dart
  String _formatDiagnosticsForZendesk(BugReportData data) {
    final buffer = StringBuffer();

    buffer.writeln('## Device Information');
    buffer.writeln('App Version: ${data.appVersion}');
    buffer.writeln('Platform: ${data.deviceInfo['platform'] ?? 'unknown'}');
    buffer.writeln('Model: ${data.deviceInfo['model'] ?? 'unknown'}');
    buffer.writeln('OS Version: ${data.deviceInfo['version'] ?? 'unknown'}');
    buffer.writeln();

    if (data.currentScreen != null) {
      buffer.writeln('Current Screen: ${data.currentScreen}');
      buffer.writeln();
    }

    if (data.errorCounts.isNotEmpty) {
      buffer.writeln('## Recent Errors');
      final sortedErrors = data.errorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sortedErrors.take(5)) {
        buffer.writeln('- ${entry.key}: ${entry.value}x');
      }
      buffer.writeln();
    }

    buffer.writeln('## Diagnostic Notes');
    buffer.writeln('Recent log entries: ${data.recentLogs.length}');
    buffer.writeln('Full logs available on request.');

    return buffer.toString();
  }

  Future<void> _showEmailFallback(BugReportData diagnostics) async {
    // Use existing email fallback from BugReportService
    final result = await BugReportService.instance.sendBugReportViaEmail(diagnostics);

    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bug report ready to send via email')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create bug report: ${result.error}')),
        );
      }
    }
  }
```

**Step 4: Replace bug report button handler**

Modify: `lib/screens/settings_screen.dart`

Find the "Report a Bug" ListTile and replace the `onTap` handler:

```dart
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text('Report a Bug'),
          subtitle: const Text('Get help from support'),
          onTap: () async {
            // Show loading indicator
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
            }

            try {
              // Collect diagnostics (reuse existing service)
              final diagnostics = await BugReportService.instance.collectDiagnostics(
                userDescription: '', // User fills this in Zendesk UI
                currentScreen: 'SettingsScreen',
              );

              // Dismiss loading
              if (mounted) Navigator.pop(context);

              // Check if Zendesk available
              if (ZendeskSupportService.isAvailable) {
                // Format diagnostics as ticket description
                final description = _formatDiagnosticsForZendesk(diagnostics);

                // Show Zendesk native UI
                final success = await ZendeskSupportService.showNewTicketScreen(
                  subject: 'Bug Report from OpenVine',
                  description: description,
                  tags: [
                    'mobile_app',
                    'version_${diagnostics.appVersion}',
                    Platform.isIOS ? 'ios' : 'android',
                  ],
                );

                if (!success && mounted) {
                  // Fallback to email if Zendesk call failed
                  await _showEmailFallback(diagnostics);
                }
              } else {
                // No Zendesk credentials - use email fallback
                if (mounted) {
                  await _showEmailFallback(diagnostics);
                }
              }
            } catch (e) {
              // Dismiss loading if still showing
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }

              Log.error('Bug report failed: $e', category: LogCategory.system);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Failed to create bug report. Please try again.')),
                );
              }
            }
          },
        ),
```

Add import at top of file:

```dart
import 'dart:io';
import 'package:openvine/services/zendesk_support_service.dart';
```

**Step 5: Test manually**

```bash
# Test WITHOUT credentials (email fallback)
flutter run

# Test WITH credentials (Zendesk UI)
flutter run --dart-define=ZENDESK_APP_ID=your_id --dart-define=ZENDESK_CLIENT_ID=your_client --dart-define=ZENDESK_URL=https://openvine.zendesk.com
```

Tap "Report a Bug" and verify:
- Without credentials: Email/share dialog appears
- With credentials: Zendesk native UI appears

**Step 6: Commit**

```bash
git add lib/screens/settings_screen.dart test/widgets/settings_screen_bug_report_test.dart
git commit -m "feat: integrate Zendesk into Settings bug report flow

- Check ZendeskSupportService.isAvailable before showing native UI
- Format diagnostics as Markdown for ticket description
- Include tags for filtering (mobile_app, platform, version)
- Graceful fallback to email when Zendesk unavailable
- Widget test for bug report button interaction"
```

---

## Task 7: Build Script Updates for Credentials

**Files:**
- Modify: `run_dev.sh`
- Modify: `build_native.sh`

**Step 1: Update run_dev.sh to load .env**

Modify: `run_dev.sh`

Add this code near the top (after shebang, before any flutter commands):

```bash
# Load .env file if it exists (for Zendesk credentials)
if [ -f .env ]; then
  export $(cat .env | xargs)
fi

# Default to empty strings if not set
ZENDESK_APP_ID="${ZENDESK_APP_ID:-}"
ZENDESK_CLIENT_ID="${ZENDESK_CLIENT_ID:-}"
ZENDESK_URL="${ZENDESK_URL:-https://openvine.zendesk.com}"
```

Update the flutter run command to include dart-defines:

```bash
flutter run \
  --dart-define=ZENDESK_APP_ID="$ZENDESK_APP_ID" \
  --dart-define=ZENDESK_CLIENT_ID="$ZENDESK_CLIENT_ID" \
  --dart-define=ZENDESK_URL="$ZENDESK_URL" \
  "$@"
```

**Step 2: Update build_native.sh similarly**

Modify: `build_native.sh`

Add the same .env loading logic at the top, and update build commands to include dart-defines:

```bash
# Load .env file if it exists
if [ -f .env ]; then
  export $(cat .env | xargs)
fi

ZENDESK_APP_ID="${ZENDESK_APP_ID:-}"
ZENDESK_CLIENT_ID="${ZENDESK_CLIENT_ID:-}"
ZENDESK_URL="${ZENDESK_URL:-https://openvine.zendesk.com}"
```

Update flutter build commands to include:

```bash
--dart-define=ZENDESK_APP_ID="$ZENDESK_APP_ID" \
--dart-define=ZENDESK_CLIENT_ID="$ZENDESK_CLIENT_ID" \
--dart-define=ZENDESK_URL="$ZENDESK_URL"
```

**Step 3: Test build scripts**

```bash
# Create dummy .env for testing
echo 'ZENDESK_APP_ID=test_id' > .env
echo 'ZENDESK_CLIENT_ID=test_client' >> .env
echo 'ZENDESK_URL=https://test.zendesk.com' >> .env

# Test run_dev.sh loads credentials
./run_dev.sh macos debug
```

Verify logs show "Zendesk initialized" or "Zendesk credentials not configured"

**Step 4: Clean up test .env**

```bash
rm .env
```

**Step 5: Commit**

```bash
git add run_dev.sh build_native.sh
git commit -m "feat: update build scripts to load Zendesk credentials from .env

- run_dev.sh and build_native.sh load .env if present
- Pass credentials via --dart-define flags
- Graceful defaults when .env missing"
```

---

## Task 8: Documentation and README Updates

**Files:**
- Create: `mobile/docs/ZENDESK_INTEGRATION.md`
- Modify: `mobile/README.md`

**Step 1: Write Zendesk integration documentation**

Create: `mobile/docs/ZENDESK_INTEGRATION.md`

```markdown
# Zendesk Support SDK Integration

This document describes how OpenVine integrates with Zendesk Support SDK for bug reporting.

## Architecture

- **Flutter service layer**: `lib/services/zendesk_support_service.dart`
- **iOS platform channel**: `ios/Runner/AppDelegate.swift`
- **Android platform channel**: `android/app/src/main/kotlin/co/openvine/app/MainActivity.kt`
- **Configuration**: `lib/config/zendesk_config.dart`

## Setup for Developers

### 1. Get Zendesk Credentials

Ask Rabble or check the team password manager for:
- `ZENDESK_APP_ID`
- `ZENDESK_CLIENT_ID`
- `ZENDESK_URL`

### 2. Create .env File

```bash
cp .env.example .env
```

Edit `.env` and fill in the credentials:

```bash
ZENDESK_APP_ID=your_app_id_here
ZENDESK_CLIENT_ID=your_client_id_here
ZENDESK_URL=https://openvine.zendesk.com
```

### 3. Build and Run

```bash
./run_dev.sh macos debug
```

The build scripts automatically load `.env` and pass credentials via `--dart-define`.

### Without Credentials

The app works without Zendesk credentials - bug reports fall back to email/share.

## Testing

### Unit Tests

```bash
flutter test test/services/zendesk_support_service_test.dart
flutter test test/config/zendesk_config_test.dart
```

### Integration Tests

```bash
flutter test test/integration/zendesk_initialization_test.dart
```

### Manual Testing

1. **With credentials**: Tap "Report a Bug" in Settings → Zendesk native UI should appear
2. **Without credentials**: Tap "Report a Bug" → Email/share dialog appears
3. **Submit test ticket**: Fill form in Zendesk UI, submit, verify ticket appears in dashboard

## How It Works

### Initialization

`main.dart` calls `ZendeskSupportService.initialize()` at startup:
- If credentials empty → logs warning, returns false, app continues normally
- If native initialization fails → logs error, returns false, email fallback active
- If successful → `isAvailable = true`, Zendesk UI available

### Bug Report Flow

Settings screen "Report a Bug" button:
1. Collect diagnostics via `BugReportService.collectDiagnostics()`
2. Check `ZendeskSupportService.isAvailable`
3. **If available**: Show native Zendesk ticket UI with pre-filled description
4. **If not available**: Fall back to email/share dialog

### Native UI

Zendesk provides native screens for:
- **Ticket creation**: `showNewTicketScreen()`
- **Ticket list**: `showTicketListScreen()`

All UI, form validation, network requests handled by Zendesk SDK.

## Troubleshooting

### App crashes on startup

Check logs for Zendesk initialization errors. Ensure credentials are valid.

### "Report Bug" does nothing

Check if `ZendeskSupportService.isAvailable` is true. Verify platform channel registration.

### Tickets not appearing in dashboard

- Verify credentials match your Zendesk account
- Check Zendesk dashboard ticket filters
- Ensure network connectivity

## Related Files

- Design doc: `docs/plans/2025-11-15-zendesk-support-integration-design.md`
- Implementation plan: `docs/plans/2025-11-15-zendesk-support-integration.md`
```

**Step 2: Update README with Zendesk setup instructions**

Modify: `mobile/README.md`

Add this section under "Setup" or "Development":

```markdown
### Zendesk Bug Reporting (Optional)

OpenVine uses Zendesk for bug reporting. To enable:

1. Get credentials from team password manager or Rabble
2. Copy `.env.example` to `.env` and fill in:
   ```bash
   ZENDESK_APP_ID=your_app_id
   ZENDESK_CLIENT_ID=your_client_id
   ZENDESK_URL=https://openvine.zendesk.com
   ```
3. Build/run normally - credentials loaded automatically

**Without credentials**: App works fine, bug reports use email fallback.

See [docs/ZENDESK_INTEGRATION.md](docs/ZENDESK_INTEGRATION.md) for details.
```

**Step 3: Commit**

```bash
git add mobile/docs/ZENDESK_INTEGRATION.md mobile/README.md
git commit -m "docs: add Zendesk integration documentation

- Setup instructions for developers
- Architecture overview
- Testing guide
- Troubleshooting section
- Update README with optional Zendesk setup"
```

---

## Task 9: Manual Testing and Verification

**Files:**
- None (manual testing only)

**Step 1: Test iOS with credentials**

```bash
# Create .env with real credentials (get from Rabble)
echo 'ZENDESK_APP_ID=real_app_id' > .env
echo 'ZENDESK_CLIENT_ID=real_client_id' >> .env
echo 'ZENDESK_URL=https://openvine.zendesk.com' >> .env

./run_dev.sh ios debug
```

Manual checklist:
- [ ] App launches without crash
- [ ] Logs show "✅ Zendesk initialized successfully"
- [ ] Navigate to Settings
- [ ] Tap "Report a Bug"
- [ ] Zendesk native UI appears
- [ ] Fill out ticket form
- [ ] Submit ticket
- [ ] Ticket appears in Zendesk dashboard

**Step 2: Test Android with credentials**

```bash
./run_dev.sh android debug
```

Same manual checklist as iOS.

**Step 3: Test iOS without credentials**

```bash
rm .env  # Remove credentials file
./run_dev.sh ios debug
```

Manual checklist:
- [ ] App launches without crash
- [ ] Logs show "Zendesk credentials not configured"
- [ ] Navigate to Settings
- [ ] Tap "Report a Bug"
- [ ] Email/share dialog appears (not Zendesk UI)
- [ ] Can share bug report file

**Step 4: Test Android without credentials**

```bash
./run_dev.sh android debug
```

Same manual checklist as iOS without credentials.

**Step 5: Test network failure**

Enable airplane mode, tap "Report a Bug" with Zendesk configured.

Expected:
- [ ] Zendesk UI appears (native UI handles network errors)
- [ ] Shows appropriate error message from Zendesk SDK
- [ ] OR falls back to email if platform channel fails

**Step 6: Document test results**

Create: `mobile/docs/ZENDESK_TEST_RESULTS.md`

```markdown
# Zendesk Integration Test Results

**Date**: [Current date]
**Tester**: [Your name]

## iOS Testing

### With Credentials
- [ ] Initialization successful
- [ ] Native UI appears
- [ ] Ticket submission works
- [ ] Ticket appears in dashboard

### Without Credentials
- [ ] App starts normally
- [ ] Email fallback works

## Android Testing

### With Credentials
- [ ] Initialization successful
- [ ] Native UI appears
- [ ] Ticket submission works
- [ ] Ticket appears in dashboard

### Without Credentials
- [ ] App starts normally
- [ ] Email fallback works

## Edge Cases

- [ ] Network failure handled gracefully
- [ ] Rapid button tapping doesn't crash
- [ ] Device rotation during ticket creation

## Issues Found

[List any issues discovered during testing]

## Sign-off

Tested by: [Name]
Date: [Date]
Status: [PASS/FAIL]
```

**Step 7: Commit test results**

```bash
git add mobile/docs/ZENDESK_TEST_RESULTS.md
git commit -m "test: manual testing results for Zendesk integration"
```

---

## Task 10: Cleanup and Final Commit

**Files:**
- Delete: Old bug reporting files (after verifying Zendesk works)

**Step 1: Verify Zendesk is working in production**

- [ ] TestFlight build deployed
- [ ] At least 3 test tickets submitted successfully
- [ ] No crashes or errors reported
- [ ] Email fallback tested and works

**Step 2: Remove old Cloudflare Worker integration**

**ONLY AFTER Zendesk proven stable (1-2 weeks):**

Delete these methods from `lib/services/bug_report_service.dart`:
- `sendBugReport()` (Cloudflare Worker)
- `sendBugReportToRecipient()` (NIP-17)
- Blossom upload integration (if only used for bug reports)

Keep:
- `collectDiagnostics()`
- `sendBugReportViaEmail()` (fallback)
- `sanitizeSensitiveData()`

**Step 3: Remove old UI**

Delete: `lib/widgets/bug_report_dialog.dart` (replaced by Zendesk native UI)

**Step 4: Update BugReportConfig**

Modify: `lib/config/bug_report_config.dart`

Remove: `bugReportApiUrl` constant (Cloudflare Worker)

**Step 5: Run tests to ensure nothing broken**

```bash
flutter test
flutter analyze
```

Expected: All tests pass, no analyzer warnings

**Step 6: Commit cleanup**

```bash
git add lib/services/bug_report_service.dart lib/widgets/ lib/config/bug_report_config.dart
git commit -m "refactor: remove old Cloudflare Worker bug reporting

- Delete sendBugReport() (unreliable Worker endpoint)
- Delete sendBugReportToRecipient() (complex NIP-17 fallback)
- Delete BugReportDialog widget (replaced by Zendesk native UI)
- Keep email fallback for no-credentials scenario
- Zendesk proven stable in production"
```

---

## Final Checklist

Before marking complete:

- [ ] All tests pass: `flutter test`
- [ ] No analyzer warnings: `flutter analyze`
- [ ] iOS builds: `flutter build ios --no-codesign`
- [ ] Android builds: `flutter build apk --debug`
- [ ] Manual testing completed on both platforms
- [ ] Documentation written and accurate
- [ ] Design doc updated with any deviations
- [ ] Zendesk dashboard shows test tickets
- [ ] Email fallback tested without credentials
- [ ] All commits follow conventional commit format
- [ ] Branch ready for PR

---

## Execution Options

**Plan complete and saved to `docs/plans/2025-11-15-zendesk-support-integration.md`.**

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration with quality gates

**2. Parallel Session (separate)** - Open new session with executing-plans skill, batch execution with checkpoints

**Which approach would you like?**
