// ABOUTME: Helper utilities for real integration tests without over-mocking
// ABOUTME: Provides real Nostr relay connections and minimal platform channel mocking

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/nostr_service_factory.dart';

import '../test_setup.dart' as app_harness;

/// Setup real integration test environment with minimal mocking
/// Only mocks platform channels that can't be tested, uses real Nostr connections
class RealIntegrationTestHelper {
  static bool _isSetup = false;

  /// Setup test environment with platform channel mocks and real Nostr
  ///
  /// Must be called from a running test, `setUp`, or `setUpAll` (it registers
  /// an [addTearDown] restore). From a `setUpAll` the restore becomes a
  /// group-scoped `tearDownAll`.
  static Future<void> setupTestEnvironment() async {
    if (_isSetup) return;

    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock platform channels that can't run in test environment
    _setupPlatformChannelMocks();

    // The handlers above overwrite shared channels owned by the app-wide
    // harness (test_setup.dart) with degraded ones (secure-storage reads
    // return null). Under very_good --optimization every suite shares one
    // isolate, so leaving them installed strands later suites — the
    // #5713→#5725 failure class (#5738).
    addTearDown(_restoreSharedChannelDefaults);

    _isSetup = true;
  }

  static void _restoreSharedChannelDefaults() {
    app_harness.setupTestEnvironment();
    // Helper-local channels the app harness does not own: clear outright.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        null,
      )
      ..setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        null,
      );
    _isSetup = false;
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
    // Mock SharedPreferences
    const MethodChannel prefsChannel = MethodChannel(
      'plugins.flutter.io/shared_preferences',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(prefsChannel, (MethodCall methodCall) async {
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

    // Mock connectivity
    const MethodChannel connectivityChannel = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'check') {
            return ['wifi']; // Always online for tests
          }
          return null;
        });

    // Mock secure storage
    const MethodChannel secureStorageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (
          MethodCall methodCall,
        ) async {
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

    // Mock path_provider
    const MethodChannel pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (
          MethodCall methodCall,
        ) async {
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
