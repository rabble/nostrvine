// ABOUTME: Test setup configuration for handling platform channels and mock services
// ABOUTME: Provides mock implementations for plugins that aren't available in test environment

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_path_provider_platform.dart';

/// Set up test environment with necessary mocks and platform channel handlers
void setupTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Disable Google Fonts runtime fetching to prevent network calls in tests
  GoogleFonts.config.allowRuntimeFetching = false;

  // Mock SharedPreferences
  SharedPreferences.setMockInitialValues({});

  // Set up mock method channels for plugins that aren't available in tests
  _setupSecureStorageMock();
  _setupPlatformChannelMocks();
  _setupImagePickerMock();
  _registerMocktailFallbacks();
}

final MockPathProviderPlatform _mockPathProviderPlatform =
    MockPathProviderPlatform()
      ..setTemporaryPath('/tmp')
      ..setApplicationDocumentsPath('/tmp/documents')
      ..setApplicationSupportPath('/tmp/support');

/// Process-global mocktail fallback values for sealed event types whose
/// concrete subclasses are constructed at call time (so [any]/[captureAny]
/// against the sealed parent needs a default instance to fall back on).
void _registerMocktailFallbacks() {
  // Cast through the sealed parent so mocktail registers the fallback
  // under `ProfileEditorEvent`, not the concrete `ProfileSaved` subtype.
  // Without the cast, T is inferred from the value's static type and
  // `captureAny(that: isA<ProfileSaved>())` against `add(ProfileEditorEvent)`
  // fails with "no fallback for ProfileEditorEvent".
  const ProfileEditorEvent fallback = ProfileSaved(pubkey: '', displayName: '');
  registerFallbackValue(fallback);
}

void _setupSecureStorageMock() {
  // Mock flutter_secure_storage
  const MethodChannel secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  // Simple in-memory storage for testing
  final Map<String, String> testStorage = {};

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (
        MethodCall methodCall,
      ) async {
        switch (methodCall.method) {
          case 'read':
            final String? key = methodCall.arguments['key'];
            return testStorage[key];
          case 'write':
            final String? key = methodCall.arguments['key'];
            final String? value = methodCall.arguments['value'];
            if (key != null && value != null) {
              testStorage[key] = value;
            }
            return null;
          case 'delete':
            final String? key = methodCall.arguments['key'];
            testStorage.remove(key);
            return null;
          case 'deleteAll':
            testStorage.clear();
            return null;
          case 'readAll':
            return testStorage;
          case 'containsKey':
            final String? key = methodCall.arguments['key'];
            return testStorage.containsKey(key);
          case 'getCapabilities':
            // Return basic capabilities for testing
            return {'basicSecureStorage': true};
          default:
            return null;
        }
      });

  // Mock the secure storage capability check channel
  const MethodChannel capabilityChannel = MethodChannel(
    'openvine.secure_storage',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(capabilityChannel, (
        MethodCall methodCall,
      ) async {
        switch (methodCall.method) {
          case 'getCapabilities':
            return {
              'hasHardwareSecurity': false,
              'hasBiometrics': false,
              'hasKeychain': true,
            };
          default:
            return null;
        }
      });
}

void _setupPlatformChannelMocks() {
  PathProviderPlatform.instance = _mockPathProviderPlatform;

  // Mock other platform channels that might be needed

  // Mock device info
  const MethodChannel deviceInfoChannel = MethodChannel(
    'plugins.flutter.io/device_info',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(deviceInfoChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'getDeviceInfo') {
          return {
            'model': 'Test Device',
            'manufacturer': 'Test Manufacturer',
            'brand': 'Test Brand',
            'version': {'release': '11', 'sdkInt': 30},
          };
        }
        return null;
      });

  // Mock path provider
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (
        MethodCall methodCall,
      ) async {
        switch (methodCall.method) {
          case 'getTemporaryDirectory':
            return '/tmp';
          case 'getApplicationDocumentsDirectory':
            return '/tmp/documents';
          case 'getApplicationSupportDirectory':
            return '/tmp/support';
          default:
            return null;
        }
      });
}

void _setupImagePickerMock() {
  // image_picker plugin: return a synthetic file path so widget tests that
  // exercise the picker entry point can proceed without a real platform
  // implementation. The path does not need to point at a real file because
  // upload-service mocks intercept the bytes before any I/O happens.
  const MethodChannel imagePickerChannel = MethodChannel(
    'plugins.flutter.io/image_picker',
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(imagePickerChannel, (
        MethodCall methodCall,
      ) async {
        switch (methodCall.method) {
          case 'pickImage':
            return '/tmp/test_picker_image.jpg';
          case 'pickMultiImage':
            return <String>['/tmp/test_picker_image.jpg'];
          case 'pickVideo':
            return '/tmp/test_picker_video.mp4';
          case 'pickMedia':
            return <String>['/tmp/test_picker_image.jpg'];
          default:
            return null;
        }
      });
}
