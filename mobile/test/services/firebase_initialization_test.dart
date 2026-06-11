// ABOUTME: Regression tests for idempotent Firebase default app initialization.
// ABOUTME: Covers Android native auto-init before Dart startup.

import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/firebase_initialization.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeFirebaseCore extends Fake
    with MockPlatformInterfaceMixin
    implements FirebasePlatform {
  _FakeFirebaseCore({required this.hasDefaultApp});

  final bool hasDefaultApp;
  int initializeAppCalls = 0;

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) =>
      _FakeFirebaseApp();

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    initializeAppCalls++;
    return _FakeFirebaseApp();
  }

  @override
  List<FirebaseAppPlatform> get apps =>
      hasDefaultApp ? [_FakeFirebaseApp()] : const [];
}

class _FakeFirebaseApp extends Fake
    with MockPlatformInterfaceMixin
    implements FirebaseAppPlatform {
  @override
  String get name => defaultFirebaseAppName;

  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-sender-id',
    projectId: 'test-project-id',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ensureDefaultFirebaseInitialized', () {
    test('initializes Firebase when no default app exists', () async {
      final fakeFirebase = _FakeFirebaseCore(hasDefaultApp: false);
      FirebasePlatform.instance = fakeFirebase;

      await ensureDefaultFirebaseInitialized(
        options: _FakeFirebaseApp().options,
      );

      expect(fakeFirebase.initializeAppCalls, 1);
    });

    test('reuses an existing default Firebase app', () async {
      final fakeFirebase = _FakeFirebaseCore(hasDefaultApp: true);
      FirebasePlatform.instance = fakeFirebase;

      await ensureDefaultFirebaseInitialized(
        options: _FakeFirebaseApp().options,
      );

      expect(fakeFirebase.initializeAppCalls, isZero);
    });
  });
}
