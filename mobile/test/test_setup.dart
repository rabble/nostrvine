// ABOUTME: Test setup configuration for handling platform channels and mock services
// ABOUTME: Provides mock implementations for plugins that aren't available in test environment

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_path_provider_platform.dart';

/// Handler shape for [TestDefaultBinaryMessenger.setMockMethodCallHandler].
typedef SharedChannelHandler = Future<Object?>? Function(MethodCall call);

const String _secureStorageChannelName =
    'plugins.it_nomads.com/flutter_secure_storage';
const String _capabilityChannelName = 'openvine.secure_storage';
const String _deviceInfoChannelName = 'plugins.flutter.io/device_info';
const String _pathProviderChannelName = 'plugins.flutter.io/path_provider';
const String _imagePickerChannelName = 'plugins.flutter.io/image_picker';

/// The process-global MethodChannels that [setupTestEnvironment] owns. Under
/// `very_good test --optimization` the whole unit suite shares one isolate and
/// flutter_test auto-restores nothing (#5738), so any test that replaces one of
/// these handlers without restoring degrades every later suite. The
/// heal-and-blame tearDown in `flutter_test_config.dart` guards exactly this
/// set; sanctioned per-test overrides go through
/// `overrideSharedChannel(...)` in `helpers/shared_channel_override.dart`.
const Set<String> sharedChannelNames = <String>{
  _secureStorageChannelName,
  _capabilityChannelName,
  _deviceInfoChannelName,
  _pathProviderChannelName,
  _imagePickerChannelName,
};

/// Channel name → the exact handler closure whose identity is canonical.
/// Populated every time an installer runs; read by `checkMockMessageHandler`
/// in the heal-and-blame tearDown and by `restoreSharedChannel`.
final Map<String, SharedChannelHandler> canonicalSharedHandlers =
    <String, SharedChannelHandler>{};

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

/// Reinstall every canonical shared-channel handler and refresh the registry.
///
/// Scoped equivalent of rerunning [setupTestEnvironment] for just the shared
/// MethodChannels: use from a `setUp`/`tearDown`/`addTearDown` that needs to
/// undo a raw shared-channel install (the auth harness `remove()` does this).
/// Prefer [overrideSharedChannel] for per-test overrides — it auto-restores.
void restoreSharedChannelDefaults() {
  _setupSecureStorageMock();
  _setupPlatformChannelMocks();
  _setupImagePickerMock();
}

/// Reinstall the canonical handler for a single shared [channel] (identity
/// then matches the registry again). Used by the heal path and by
/// [overrideSharedChannel]'s auto-restore.
void restoreSharedChannel(MethodChannel channel) {
  final handler = canonicalSharedHandlers[channel.name];
  assert(
    handler != null,
    '${channel.name} is not a registered shared channel; '
    'setupTestEnvironment() must run before restoreSharedChannel().',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, handler);
}

void _installShared(MethodChannel channel, SharedChannelHandler handler) {
  canonicalSharedHandlers[channel.name] = handler;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, handler);
}

/// Root of the directories `path_provider` resolves to in tests, unique per
/// process.
///
/// `very_good test --optimization` does not run one process: it runs the merged
/// bundle plus each VGV-skip-tagged file as its own process, concurrently
/// (`--concurrency=4` in CI). These paths were the fixed `/tmp/documents` and
/// `/tmp/support`, so every one of those processes resolved to the same
/// directories — and therefore to the same Hive boxes and database files on
/// disk. A suite that deleted a box could pull it out from under a suite in
/// another process, failing on state it never mutated. Keying the root on the
/// process id removes the shared resource.
final Directory _processRoot = Directory.systemTemp.createTempSync(
  'divine_test_${pid}_',
);

Directory _processDirectory(String name) =>
    Directory('${_processRoot.path}/$name')..createSync();

final Directory _temporaryDirectory = _processDirectory('temporary');
final Directory _documentsDirectory = _processDirectory('documents');
final Directory _supportDirectory = _processDirectory('support');

final MockPathProviderPlatform _mockPathProviderPlatform =
    MockPathProviderPlatform()
      ..setTemporaryPath(_temporaryDirectory.path)
      ..setApplicationDocumentsPath(_documentsDirectory.path)
      ..setApplicationSupportPath(_supportDirectory.path);

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

// Named canonical handlers. Each is a top-level function so its identity is
// stable across setup/restore calls — that identity is what
// `checkMockMessageHandler` compares against.

/// In-memory backing store for the mocked flutter_secure_storage channel.
/// Cleared on each full [setupTestEnvironment]/[restoreSharedChannelDefaults]
/// so a fresh setup starts empty (the historical local-variable behavior),
/// while the handler identity stays stable.
final Map<String, String> _secureStorageStore = <String, String>{};

Future<Object?>? _secureStorageHandler(MethodCall methodCall) async {
  switch (methodCall.method) {
    case 'read':
      final key = methodCall.arguments['key'] as String?;
      return _secureStorageStore[key];
    case 'write':
      final key = methodCall.arguments['key'] as String?;
      final value = methodCall.arguments['value'] as String?;
      if (key != null && value != null) {
        _secureStorageStore[key] = value;
      }
      return null;
    case 'delete':
      final key = methodCall.arguments['key'] as String?;
      _secureStorageStore.remove(key);
      return null;
    case 'deleteAll':
      _secureStorageStore.clear();
      return null;
    case 'readAll':
      return _secureStorageStore;
    case 'containsKey':
      final key = methodCall.arguments['key'] as String?;
      return _secureStorageStore.containsKey(key);
    case 'getCapabilities':
      return {'basicSecureStorage': true};
    default:
      return null;
  }
}

Future<Object?>? _secureStorageCapabilityHandler(MethodCall methodCall) async {
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
}

Future<Object?>? _deviceInfoHandler(MethodCall methodCall) async {
  if (methodCall.method == 'getDeviceInfo') {
    return {
      'model': 'Test Device',
      'manufacturer': 'Test Manufacturer',
      'brand': 'Test Brand',
      'version': {'release': '11', 'sdkInt': 30},
    };
  }
  return null;
}

/// Mirrors [_mockPathProviderPlatform]. The app-facing `path_provider` API
/// resolves through `PathProviderPlatform.instance`, so this channel handler
/// only serves a caller that invokes the raw MethodChannel — keep the two in
/// step so such a caller cannot land on a different directory.
Future<Object?>? _pathProviderHandler(MethodCall methodCall) async {
  switch (methodCall.method) {
    case 'getTemporaryDirectory':
      return _temporaryDirectory.path;
    case 'getApplicationDocumentsDirectory':
      return _documentsDirectory.path;
    case 'getApplicationSupportDirectory':
      return _supportDirectory.path;
    default:
      return null;
  }
}

Future<Object?>? _imagePickerHandler(MethodCall methodCall) async {
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
}

void _setupSecureStorageMock() {
  _secureStorageStore.clear();
  _installShared(
    const MethodChannel(_secureStorageChannelName),
    _secureStorageHandler,
  );
  _installShared(
    const MethodChannel(_capabilityChannelName),
    _secureStorageCapabilityHandler,
  );
}

void _setupPlatformChannelMocks() {
  PathProviderPlatform.instance = _mockPathProviderPlatform;

  _installShared(
    const MethodChannel(_deviceInfoChannelName),
    _deviceInfoHandler,
  );
  _installShared(
    const MethodChannel(_pathProviderChannelName),
    _pathProviderHandler,
  );
}

void _setupImagePickerMock() {
  // image_picker plugin: return a synthetic file path so widget tests that
  // exercise the picker entry point can proceed without a real platform
  // implementation. The path is never written, so a flow that stats or reads
  // the pick (e.g. the profile image-selection boundary) sees it as invalid.
  // Tests needing a pick to survive that check must point the channel at a
  // real file — see `stubPickedImageFile` in helpers/image_picker_stub.dart.
  _installShared(
    const MethodChannel(_imagePickerChannelName),
    _imagePickerHandler,
  );
}
