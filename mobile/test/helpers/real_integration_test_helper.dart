// ABOUTME: Helper utilities for real integration tests without over-mocking
// ABOUTME: Provides real Nostr relay connections and minimal platform channel mocking

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/nostr_service_factory.dart';

import 'shared_channel_override.dart';

/// Setup real integration test environment with minimal mocking
/// Only mocks platform channels that can't be tested, uses real Nostr connections
class RealIntegrationTestHelper {
  static bool _isSetup = false;

  static const MethodChannel _prefsChannel = MethodChannel(
    'plugins.flutter.io/shared_preferences',
  );
  static const MethodChannel _connectivityChannel = MethodChannel(
    'dev.fluttercommunity.plus/connectivity',
  );
  static const MethodChannel _secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  static const MethodChannel _pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  /// Setup test environment with platform channel mocks and real Nostr
  ///
  /// Must be called from a running test, `setUp`, or `setUpAll` (it registers
  /// an [addTearDown] restore). From a `setUpAll` the restore becomes a
  /// group-scoped `tearDownAll`.
  static Future<void> setupTestEnvironment() async {
    if (_isSetup) return;

    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock platform channels that can't run in test environment.
    _setupPlatformChannelMocks();

    // shared_preferences + connectivity are helper-local (the app harness does
    // not own them): clear them on teardown. The shared secure_storage /
    // path_provider channels are installed via overrideSharedChannel above,
    // which auto-restores their canonical handlers — so the #5713→#5725 /
    // #5738 strand-the-next-suite class cannot recur.
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(_prefsChannel, null)
        ..setMockMethodCallHandler(_connectivityChannel, null);
      _isSetup = false;
    });

    _isSetup = true;
  }

  /// Create a real NostrService with embedded relay
  static Future<NostrClient> createRealNostrService() async {
    await setupTestEnvironment();

    // Generate a test key container
    final keyContainer = await SecureKeyContainer.generate();

    final nostrService = NostrServiceFactory.create(
      signer: LocalNostrIdentity(keyContainer: keyContainer),
    );
    await nostrService.initialize();

    // NostrClient handles relay connections internally

    return nostrService;
  }

  /// Setup minimal platform channel mocks (only what's needed, not business logic)
  static void _setupPlatformChannelMocks() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // Mock SharedPreferences (helper-local channel).
    messenger.setMockMethodCallHandler(_prefsChannel, (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      if (methodCall.method == 'setString' ||
          methodCall.method == 'setStringList') {
        return true;
      }
      if (methodCall.method == 'setBool') {
        return true;
      }
      if (methodCall.method == 'setInt') {
        return true;
      }
      if (methodCall.method == 'setDouble') {
        return true;
      }
      if (methodCall.method == 'remove') {
        return true;
      }
      if (methodCall.method == 'clear') {
        return true;
      }
      return null;
    });

    // Mock connectivity (helper-local channel).
    messenger.setMockMethodCallHandler(_connectivityChannel, (
      MethodCall methodCall,
    ) async {
      if (methodCall.method == 'check') {
        return ['wifi']; // Always online for tests
      }
      return null;
    });

    // Shared channels: install via the sanctioned override so the heal-and-blame
    // tearDown leaves these degraded handlers in place for the calling group and
    // auto-restores the canonical handlers afterwards (#5738).
    overrideSharedChannel(_secureStorageChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'write') {
        return null;
      }
      if (methodCall.method == 'read') {
        return null;
      }
      if (methodCall.method == 'readAll') {
        return <String, String>{};
      }
      return null;
    });

    overrideSharedChannel(_pathProviderChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '/tmp/test_documents';
      }
      if (methodCall.method == 'getTemporaryDirectory') {
        return '/tmp';
      }
      if (methodCall.method == 'getApplicationSupportDirectory') {
        return '/tmp/test_support';
      }
      return null;
    });
  }
}
