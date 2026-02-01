// ABOUTME: Widget tests for NostrConnectScreen
// ABOUTME: Tests route constants and basic structure

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';

void main() {
  group('NostrConnectScreen route constants', () {
    test('has correct path', () {
      expect(NostrConnectScreen.path, equals('/nostr-connect'));
    });

    test('has correct route name', () {
      expect(NostrConnectScreen.routeName, equals('nostr-connect'));
    });
  });

  // Note: Full widget tests require complex mocking of AuthService,
  // NostrConnectSession, timers, and clipboard. The core logic is tested
  // via unit tests in nostr_connect_session_test.dart.
  // Integration testing is recommended via manual smoke testing with
  // actual signer apps (Amber, nsecBunker).
}
