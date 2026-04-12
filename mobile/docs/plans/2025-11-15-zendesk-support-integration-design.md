Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Zendesk Support SDK Integration Design

**Date:** 2025-11-15
**Author:** Architecture Design
**Status:** Approved for Implementation
**Approach:** Minimal Platform Channel with Native UI

## Executive Summary

Replace OpenVine's unreliable custom bug reporting system (Cloudflare Worker endpoint) with Zendesk Support SDK integration using a minimal Flutter platform channel wrapper. This design leverages Zendesk's official native iOS/Android SDKs to provide reliable ticket creation with graceful fallback to email when Zendesk credentials are not configured.

**Key Benefits:**
- Reliable ticket submission to Zendesk dashboard
- Minimal code to maintain (~400 lines total)
- Native polished UI from Zendesk
- Graceful degradation without credentials (email fallback)
- Follows established ProofMode platform channel patterns
- Fast implementation (~10-12 hours)

---

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Architecture Overview](#architecture-overview)
3. [Component Design](#component-design)
4. [Integration Points](#integration-points)
5. [Credential Management](#credential-management)
6. [Testing Strategy](#testing-strategy)
7. [Migration Plan](#migration-plan)
8. [Future Enhancements](#future-enhancements)

---

## Problem Statement

### Current System Issues

OpenVine has a comprehensive custom bug reporting system with multiple fallback paths:
1. **Primary**: Cloudflare Worker API (`bug-reports.protestnet.workers.dev`) - **UNRELIABLE**
2. **Fallback 1**: NIP-17 encrypted Nostr messages - overcomplicated
3. **Fallback 2**: Blossom server upload + DM - unnecessary complexity
4. **Fallback 3**: Email via share dialog - works but manual

**Problems:**
- Cloudflare Worker endpoint is unreliable (Rabble's primary complaint)
- Multiple fallback paths suggest primary method doesn't work
- Complex NIP-17 encryption for bug reports is overkill
- High maintenance burden for custom system

### Requirements

**Must Have:**
- Reliable ticket submission to Zendesk support dashboard
- Include comprehensive diagnostics (logs, device info, error counts)
- Work on iOS and Android (macOS not needed - dev platform only)
- Graceful fallback when Zendesk credentials not configured
- TDD implementation approach

**Nice to Have:**
- View user's ticket history
- Attach screenshots/files
- Customize ticket fields

---

## Architecture Overview

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Layer (Dart)                     │
├─────────────────────────────────────────────────────────────┤
│  ZendeskSupportService (MethodChannel wrapper)              │
│  - initialize(appId, clientId, url)                          │
│  - isAvailable (bool flag)                                   │
│  - showNewTicketScreen(subject, description, tags)          │
│  - showTicketListScreen()                                    │
└──────────────────────┬──────────────────────────────────────┘
                       │ MethodChannel
                       │ 'com.openvine/zendesk_support'
                       │
        ┌──────────────┴──────────────┐
        │                             │
┌───────▼─────────────┐      ┌────────▼────────────┐
│   iOS (Swift)       │      │  Android (Kotlin)   │
├─────────────────────┤      ├─────────────────────┤
│ AppDelegate.swift   │      │ MainActivity.kt     │
│ setupZendesk()      │      │ setupZendesk()      │
│ - Init SDK          │      │ - Init SDK          │
│ - Present VCs       │      │ - Launch Activities │
│ - Handle callbacks  │      │ - Handle callbacks  │
└─────────────────────┘      └─────────────────────┘
        │                             │
        │    Zendesk Native SDKs      │
        └──────────────┬──────────────┘
                       │
            ┌──────────▼──────────┐
            │  Zendesk Backend    │
            │  (Tickets, Support) │
            └─────────────────────┘
```

### User Journey

1. User taps "Report Bug" in Settings
2. Flutter checks `ZendeskSupportService.isAvailable`
3. **IF Zendesk available:**
   - Collect diagnostics via existing `BugReportService.collectDiagnostics()`
   - Format diagnostics as ticket description
   - Call `showNewTicketScreen()` → native UI appears
   - User fills additional details, submits
   - Ticket created in Zendesk dashboard
   - Confirmation shown to user
4. **IF Zendesk NOT available (no credentials):**
   - Fall back to email/share flow (existing `sendBugReportViaEmail`)
   - User shares bug report file via system share dialog

### Design Principles

- **Thin wrapper**: Flutter code is minimal, delegates to native SDKs
- **Native UI**: Zendesk provides polished, tested ticket creation screens
- **Graceful degradation**: App works without Zendesk credentials
- **Reuse diagnostics**: Keep comprehensive data collection from existing system
- **Follow patterns**: Match ProofMode's platform channel architecture

---

## Component Design

### 1. Flutter Service Layer

**File:** `mobile/lib/services/zendesk_support_service.dart`

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
}
```

**Key Design Decisions:**
- Stateless service (matches ProofMode pattern)
- `isAvailable` flag prevents calls when not initialized
- All methods return `bool` for simple success/failure handling
- Comprehensive logging for debugging
- No exception thrown to caller - graceful degradation

---

### 2. Configuration

**File:** `mobile/lib/config/zendesk_config.dart`

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

**Environment File (gitignored):**

```bash
# mobile/.env (NOT committed)
ZENDESK_APP_ID=your_actual_app_id_here
ZENDESK_CLIENT_ID=your_actual_client_id_here
ZENDESK_URL=https://openvine.zendesk.com
```

**Environment File Template (committed):**

```bash
# mobile/.env.example (committed as template)
ZENDESK_APP_ID=
ZENDESK_CLIENT_ID=
ZENDESK_URL=https://openvine.zendesk.com
```

---

### 3. iOS Implementation

**File:** `mobile/ios/Runner/AppDelegate.swift` (additions)

```swift
import ZendeskCoreSDK
import SupportSDK

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    setupProofModeChannel()
    setupZendeskChannel() // NEW

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

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
}
```

**iOS Dependencies:**

Add to `mobile/ios/Podfile`:

```ruby
target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  # Zendesk Support SDK
  pod 'ZendeskSupportSDK', '~> 5.3'
end
```

---

### 4. Android Implementation

**File:** `mobile/android/app/src/main/kotlin/co/openvine/app/MainActivity.kt` (additions)

```kotlin
package co.openvine.app

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import zendesk.core.AnonymousIdentity
import zendesk.core.Zendesk
import zendesk.support.Support
import zendesk.support.request.RequestActivity
import zendesk.support.requestlist.RequestListActivity

class MainActivity : FlutterActivity() {
    private val ZENDESK_CHANNEL = "com.openvine/zendesk_support"
    private val TAG = "OpenVineZendesk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        try {
            super.configureFlutterEngine(flutterEngine)
        } catch (e: Exception) {
            Log.e(TAG, "Exception during FlutterEngine configuration", e)
            // Handle FFmpegKit initialization failure (not needed on Android)
            if (e.message?.contains("FFmpegKit") == true || e.cause?.message?.contains("ffmpegkit") == true) {
                Log.w(TAG, "FFmpegKit plugin failed to initialize (expected on Android)", e)
            } else {
                throw e
            }
        }

        // Existing ProofMode channel...

        setupZendeskChannel(flutterEngine)
    }

    private fun setupZendeskChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ZENDESK_CHANNEL
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
}
```

**Android Dependencies:**

Add to `mobile/android/app/build.gradle`:

```gradle
dependencies {
    // Existing dependencies...

    // Zendesk Support SDK
    implementation 'com.zendesk:support:5.1.2'
}
```

---

## Integration Points

### 1. App Initialization

**File:** `mobile/lib/main.dart`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ... existing initialization ...

  // Initialize Zendesk (graceful failure if no credentials)
  await ZendeskSupportService.initialize(
    appId: ZendeskConfig.appId,
    clientId: ZendeskConfig.clientId,
    zendeskUrl: ZendeskConfig.zendeskUrl,
  );

  // ... rest of startup ...

  runApp(const MyApp());
}
```

---

### 2. Settings Screen Integration

**File:** `mobile/lib/screens/settings_screen.dart`

```dart
// Replace existing bug report button handler

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
          _showEmailFallback(diagnostics);
        }
      } else {
        // No Zendesk credentials - use email fallback
        if (mounted) {
          _showEmailFallback(diagnostics);
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
          const SnackBar(content: Text('Failed to create bug report. Please try again.')),
        );
      }
    }
  },
),

String _formatDiagnosticsForZendesk(BugReportData data) {
  final buffer = StringBuffer();

  buffer.writeln('## Device Information');
  buffer.writeln('App Version: ${data.appVersion}');
  buffer.writeln('Platform: ${data.deviceInfo['platform']}');
  buffer.writeln('Model: ${data.deviceInfo['model']}');
  buffer.writeln('OS Version: ${data.deviceInfo['version']}');
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

**Key Points:**
- Reuse existing `BugReportService.collectDiagnostics()`
- Check `ZendeskSupportService.isAvailable` before calling
- Format diagnostics into Markdown for Zendesk description
- Tags for filtering/categorization in Zendesk dashboard
- Email fallback preserved for no-credentials scenario

---

## Credential Management

### Build Configuration

**Update:** `mobile/run_dev.sh`

```bash
#!/bin/bash

# Load .env file if it exists (for Zendesk credentials)
if [ -f .env ]; then
  export $(cat .env | xargs)
fi

# Default to empty strings if not set
ZENDESK_APP_ID="${ZENDESK_APP_ID:-}"
ZENDESK_CLIENT_ID="${ZENDESK_CLIENT_ID:-}"
ZENDESK_URL="${ZENDESK_URL:-https://openvine.zendesk.com}"

flutter run \
  --dart-define=ZENDESK_APP_ID="$ZENDESK_APP_ID" \
  --dart-define=ZENDESK_CLIENT_ID="$ZENDESK_CLIENT_ID" \
  --dart-define=ZENDESK_URL="$ZENDESK_URL" \
  "$@"
```

**Update:** `mobile/build_native.sh`

```bash
#!/bin/bash

# Load .env file if it exists
if [ -f .env ]; then
  export $(cat .env | xargs)
fi

ZENDESK_APP_ID="${ZENDESK_APP_ID:-}"
ZENDESK_CLIENT_ID="${ZENDESK_CLIENT_ID:-}"
ZENDESK_URL="${ZENDESK_URL:-https://openvine.zendesk.com}"

flutter build ios \
  --dart-define=ZENDESK_APP_ID="$ZENDESK_APP_ID" \
  --dart-define=ZENDESK_CLIENT_ID="$ZENDESK_CLIENT_ID" \
  --dart-define=ZENDESK_URL="$ZENDESK_URL" \
  --release
```

### .gitignore

Ensure `.env` is ignored:

```
# mobile/.gitignore
.env
```

### Credential Setup Instructions

**For developers:**

1. Copy template: `cp .env.example .env`
2. Fill in credentials (get from Rabble or Zendesk dashboard)
3. Build/run normally - credentials loaded automatically

**For CI/CD:**

Set environment variables in CI platform:
- `ZENDESK_APP_ID`
- `ZENDESK_CLIENT_ID`
- `ZENDESK_URL`

**Without credentials:**

App builds and runs normally, uses email fallback for bug reports.

---

## Testing Strategy

### Unit Tests

**File:** `mobile/test/services/zendesk_support_service_test.dart`

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

  group('ZendeskSupportService', () {
    test('initialize returns false when credentials empty', () async {
      final result = await ZendeskSupportService.initialize(
        appId: '',
        clientId: '',
        zendeskUrl: '',
      );

      expect(result, false);
      expect(ZendeskSupportService.isAvailable, false);
    });

    test('initialize returns true when successful', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'initialize') {
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

    test('showNewTicketScreen returns false when not initialized', () async {
      final result = await ZendeskSupportService.showNewTicketScreen();

      expect(result, false);
    });

    test('showNewTicketScreen passes parameters correctly', () async {
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
  });
}
```

### Integration Tests

**File:** `mobile/test/integration/zendesk_integration_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/config/zendesk_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Zendesk Integration', () {
    testWidgets('Initialize Zendesk with real credentials', (tester) async {
      // Skip if credentials not configured
      if (ZendeskConfig.appId.isEmpty) {
        return;
      }

      final initialized = await ZendeskSupportService.initialize(
        appId: ZendeskConfig.appId,
        clientId: ZendeskConfig.clientId,
        zendeskUrl: ZendeskConfig.zendeskUrl,
      );

      expect(initialized, true);
      expect(ZendeskSupportService.isAvailable, true);
    });

    // Manual test: Verify native UI appears
    // Run this test and manually verify Zendesk screen appears
    testWidgets('Show new ticket screen (manual verification)', (tester) async {
      if (!ZendeskSupportService.isAvailable) {
        await ZendeskSupportService.initialize(
          appId: ZendeskConfig.appId,
          clientId: ZendeskConfig.clientId,
          zendeskUrl: ZendeskConfig.zendeskUrl,
        );
      }

      final shown = await ZendeskSupportService.showNewTicketScreen(
        subject: 'Integration Test Ticket',
        description: 'This is a test from integration tests',
        tags: ['test', 'automated'],
      );

      expect(shown, true);

      // Wait for manual verification
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
```

### Manual Testing Checklist

**iOS Testing:**
- [ ] Build app with Zendesk credentials
- [ ] Tap "Report Bug" in Settings
- [ ] Verify Zendesk native UI appears
- [ ] Fill ticket form, submit
- [ ] Verify ticket appears in Zendesk dashboard
- [ ] Build app WITHOUT credentials
- [ ] Tap "Report Bug" → verify email fallback works
- [ ] Test on physical device (not just simulator)

**Android Testing:**
- [ ] Build app with Zendesk credentials
- [ ] Tap "Report Bug" in Settings
- [ ] Verify Zendesk native UI appears
- [ ] Fill ticket form, submit
- [ ] Verify ticket appears in Zendesk dashboard
- [ ] Build app WITHOUT credentials
- [ ] Tap "Report Bug" → verify email fallback works
- [ ] Test on physical device (not just emulator)

**Edge Cases:**
- [ ] Test with no network connection
- [ ] Test with invalid credentials (should log error, fall back to email)
- [ ] Test rapid tapping "Report Bug" button
- [ ] Test device rotation during ticket creation

---

## Migration Plan

### Phase 1: Implementation (Week 1)

**Day 1-2: Platform Channels**
- [ ] Write `ZendeskSupportService` (Dart)
- [ ] Write `ZendeskConfig` (Dart)
- [ ] Write unit tests for service
- [ ] iOS: Add SDK dependency, implement channel handler
- [ ] Android: Add SDK dependency, implement channel handler

**Day 3: Integration**
- [ ] Update `main.dart` to initialize Zendesk
- [ ] Update Settings screen with new flow
- [ ] Create `.env.example` template
- [ ] Update build scripts to load credentials
- [ ] Test on iOS simulator
- [ ] Test on Android emulator

**Day 4: Testing**
- [ ] Run unit tests
- [ ] Run integration tests
- [ ] Manual testing on physical devices
- [ ] Fix any issues found

**Day 5: Documentation & Deploy**
- [ ] Update README with setup instructions
- [ ] Create ticket in Zendesk to verify end-to-end
- [ ] Deploy to TestFlight (iOS) for beta testing
- [ ] Deploy to internal track (Android) for beta testing

### Phase 2: Beta Testing (Week 2-3)

- Monitor Zendesk dashboard for incoming tickets
- Verify diagnostic data is useful
- Gather feedback from beta testers
- Fix any issues discovered

### Phase 3: Cleanup (Week 4)

**Remove old system once Zendesk proven stable:**

Files to DELETE:
- `lib/widgets/bug_report_dialog.dart` (replaced by Zendesk native UI)
- Cloudflare Worker code (if separate repo)
- NIP-17 message integration for bug reports (if not used elsewhere)

Files to MODIFY (keep diagnostic parts):
- `lib/services/bug_report_service.dart`:
  - Keep `collectDiagnostics()`
  - Keep `sendBugReportViaEmail()` (fallback)
  - Remove `sendBugReport()` (Cloudflare Worker)
  - Remove `sendBugReportToRecipient()` (NIP-17)
  - Remove Blossom upload integration

Files to KEEP:
- `lib/services/log_capture_service.dart` (still useful)
- `lib/services/error_analytics_tracker.dart` (analytics)
- `lib/services/crash_reporting_service.dart` (Firebase Crashlytics for crashes)
- Email fallback logic (for no-credentials scenario)

**Git cleanup:**
```bash
git rm mobile/lib/widgets/bug_report_dialog.dart
git commit -m "Remove old bug report UI (replaced by Zendesk native)"
```

---

## Future Enhancements

### Phase 4: Rich Diagnostics (Optional)

**Attachment Support:**
- Attach log files to tickets
- Attach screenshots
- Requires file upload via Zendesk SDK

**Custom Fields:**
- Add custom ticket fields for structured data
- Error frequency
- Video ID if crash related to specific content
- User's relay configuration

### Phase 5: User Identity (Optional)

**Authenticated Users:**
- Set Zendesk identity when user logs into OpenVine
- Link tickets to specific Nostr pubkeys
- View support history in app

```dart
// When user logs in
await ZendeskSupportService.setUserIdentity(
  name: userProfile.displayName,
  email: userProfile.email ?? 'anon@openvine.com',
);
```

### Phase 6: Help Center (Optional)

**Browse Support Articles:**
- Show Zendesk help center in app
- Self-service before creating tickets
- Reduces support burden

```dart
await ZendeskSupportService.showHelpCenter();
```

---

## Success Criteria

**Must achieve before removing old system:**
- ✅ 90%+ of bug reports successfully create Zendesk tickets
- ✅ Diagnostic data appears in ticket descriptions
- ✅ Zero crashes related to Zendesk integration
- ✅ Email fallback works when credentials missing
- ✅ Beta testers report bug submission is easier/faster

**Metrics to track:**
- Ticket creation success rate (via Zendesk dashboard)
- Time to first response (Zendesk analytics)
- User satisfaction (post-ticket survey in Zendesk)
- Crash rate (Firebase Crashlytics - should not increase)

---

## Appendix

### Dependencies

**iOS (Podfile):**
```ruby
pod 'ZendeskSupportSDK', '~> 5.3'
```

**Android (build.gradle):**
```gradle
implementation 'com.zendesk:support:5.1.2'
```

**Flutter (pubspec.yaml):**
No new dependencies - uses built-in `MethodChannel`

### Zendesk Dashboard Configuration

**Required setup in Zendesk:**
1. Create mobile app credentials (Admin → Channels → API)
2. Copy `appId`, `clientId`, `zendeskUrl`
3. Configure ticket fields (optional custom fields)
4. Set up tags for filtering (mobile_app, ios, android, etc.)

### Estimated Effort

- **Design & Planning:** 2 hours ✅ (complete)
- **Implementation:** 10-12 hours
  - Flutter service: 2 hours
  - iOS platform channel: 4 hours
  - Android platform channel: 4 hours
  - Integration: 2 hours
- **Testing:** 4 hours
- **Documentation:** 1 hour
- **Total:** ~17-19 hours

### Related Documentation

- Zendesk Support SDK for iOS: https://developer.zendesk.com/documentation/classic-web-widget-sdks/support-sdk/ios/
- Zendesk Support SDK for Android: https://developer.zendesk.com/documentation/classic-web-widget-sdks/support-sdk/android/
- Flutter Platform Channels: https://docs.flutter.dev/platform-integration/platform-channels
- OpenVine Bug Report Architecture (old): `mobile/docs/BUG_REPORT_SYSTEM_ARCHITECTURE.md`

---

**END OF DESIGN DOCUMENT**
