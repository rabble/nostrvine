// ABOUTME: Tests Funnelcake REST URL resolution from configured relay URLs.
// ABOUTME: Keeps divine websocket relay host separate from the Fastly REST host.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/relay_url_utils.dart';

void main() {
  group('relayWsToHttpBase', () {
    test('keeps generic relay host conversion unchanged', () {
      expect(
        relayWsToHttpBase('wss://relay.divine.video'),
        'https://relay.divine.video',
      );
    });
  });

  group('resolveApiBaseUrlFromRelays', () {
    test('maps relay.divine.video to api.divine.video for REST', () {
      expect(
        resolveApiBaseUrlFromRelays(
          configuredRelays: const ['wss://relay.divine.video'],
          fallbackBaseUrl: 'https://api.divine.video',
        ),
        'https://api.divine.video',
      );
    });

    test('uses the first configured non-divine relay when needed', () {
      expect(
        resolveApiBaseUrlFromRelays(
          configuredRelays: const ['wss://relay.staging.dvines.org'],
          fallbackBaseUrl: 'https://relay.staging.dvines.org',
        ),
        'https://relay.staging.dvines.org',
      );
    });
  });
}
