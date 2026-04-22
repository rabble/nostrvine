// ABOUTME: Tests for createPolicyEngineFilter factory in blocklist_content_filter.dart
// ABOUTME: Verifies engine-backed filter correctly delegates to ContentPolicyEngine.

import 'package:content_policy/content_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/blocklist_content_filter.dart';

void main() {
  group('createPolicyEngineFilter', () {
    test('returns true when engine.evaluate emits Block', () {
      final engine = ContentPolicyEngine.defaultRules();
      ContentPolicyState state() => const ContentPolicyState(
        currentUserPubkey: 'me',
        mutedPubkeys: {},
        blockedPubkeys: {'blocked-hex'},
        pubkeysBlockingUs: {},
        pubkeysMutingUs: {},
      );

      final filter = createPolicyEngineFilter(engine, state);
      expect(filter('blocked-hex'), isTrue);
      expect(filter('allowed-hex'), isFalse);
    });

    test('reads state through the stateProvider callback on every call', () {
      final engine = ContentPolicyEngine.defaultRules();
      var currentState = ContentPolicyState.empty();
      final filter = createPolicyEngineFilter(engine, () => currentState);

      expect(filter('some-hex'), isFalse);

      currentState = const ContentPolicyState(
        currentUserPubkey: 'me',
        mutedPubkeys: {},
        blockedPubkeys: {'some-hex'},
        pubkeysBlockingUs: {},
        pubkeysMutingUs: {},
      );

      expect(filter('some-hex'), isTrue);
    });
  });
}
