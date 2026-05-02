// ABOUTME: Tests REST URL resolution from configured relay URLs.
// ABOUTME: Covers both Funnelcake (api.divine.video) and notification (relay.divine.video) paths.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/relay_url_utils.dart';

void main() {
  group('isLoopbackHost', () {
    test('accepts canonical loopback names and addresses', () {
      expect(isLoopbackHost('localhost'), isTrue);
      expect(isLoopbackHost('127.0.0.1'), isTrue);
      expect(isLoopbackHost('10.0.2.2'), isTrue);
      expect(isLoopbackHost('::1'), isTrue);
    });

    test('is case-insensitive', () {
      expect(isLoopbackHost('LOCALHOST'), isTrue);
      expect(isLoopbackHost('LocalHost'), isTrue);
    });

    test('rejects non-loopback hosts', () {
      expect(isLoopbackHost('relay.example.com'), isFalse);
      expect(isLoopbackHost('attacker.example.com'), isFalse);
      expect(isLoopbackHost(''), isFalse);
    });

    test('rejects suffix-match attacks on loopback hostname', () {
      expect(isLoopbackHost('localhost.attacker.example.com'), isFalse);
      expect(isLoopbackHost('mylocalhost'), isFalse);
    });
  });

  group('isRelayUrlAllowed', () {
    test('accepts wss:// for any host', () {
      expect(isRelayUrlAllowed('wss://relay.divine.video'), isTrue);
      expect(isRelayUrlAllowed('wss://relay.example.com:8443'), isTrue);
      expect(isRelayUrlAllowed('wss://relay.divine.video/path'), isTrue);
    });

    test('accepts ws:// for loopback hosts only', () {
      expect(isRelayUrlAllowed('ws://localhost:47777'), isTrue);
      expect(isRelayUrlAllowed('ws://127.0.0.1:8080'), isTrue);
      expect(isRelayUrlAllowed('ws://10.0.2.2:47777'), isTrue);
      expect(isRelayUrlAllowed('ws://[::1]:8080'), isTrue);
    });

    test('rejects https:// (relays are WebSocket-only)', () {
      // NIP-65 only ever advertises WS endpoints, and `RelayManager.
      // _normalizeUrl` only accepts WS — so an https:// URL is not a
      // usable relay regardless of host. The capability service derives
      // its NIP-11 fetch URL from the WS form internally.
      expect(isRelayUrlAllowed('https://relay.divine.video'), isFalse);
      expect(isRelayUrlAllowed('https://relay.example.com'), isFalse);
      expect(isRelayUrlAllowed('https://localhost:47777'), isFalse);
    });

    test('rejects http:// (relays are WebSocket-only)', () {
      expect(isRelayUrlAllowed('http://attacker.example.com'), isFalse);
      expect(isRelayUrlAllowed('http://relay.example.com'), isFalse);
      // Loopback http:// is also rejected — relays speak WS, not HTTP.
      expect(isRelayUrlAllowed('http://localhost:47777'), isFalse);
      expect(isRelayUrlAllowed('http://10.0.2.2:8787'), isFalse);
    });

    test('rejects ws:// to non-loopback hosts', () {
      expect(isRelayUrlAllowed('ws://attacker.example.com'), isFalse);
      expect(isRelayUrlAllowed('ws://relay.example.com:8443'), isFalse);
      // Suffix-match attack: must check exact host equality.
      expect(isRelayUrlAllowed('ws://localhost.attacker.com'), isFalse);
    });

    test('is case-insensitive on scheme and host', () {
      expect(isRelayUrlAllowed('WSS://relay.example.com'), isTrue);
      expect(isRelayUrlAllowed('WS://Localhost:8080'), isTrue);
    });

    test('trims surrounding whitespace', () {
      expect(isRelayUrlAllowed('  wss://relay.example.com  '), isTrue);
      expect(isRelayUrlAllowed('\tws://attacker.example.com\n'), isFalse);
    });

    test('rejects unsupported and missing schemes', () {
      expect(isRelayUrlAllowed('ftp://relay.example.com'), isFalse);
      expect(isRelayUrlAllowed('relay.example.com'), isFalse);
      expect(isRelayUrlAllowed('bunker://pubkey'), isFalse);
    });

    test('rejects malformed and empty input', () {
      expect(isRelayUrlAllowed(''), isFalse);
      expect(isRelayUrlAllowed('wss://'), isFalse);
      expect(isRelayUrlAllowed('not a url'), isFalse);
    });

    test('rejects mis-nested scheme prefixes (#3362 review follow-up)', () {
      // `wss://http://x` parses with host=`http` and path=`//x`; without
      // the path-starts-with-`//` guard, the predicate would accept it
      // (scheme=wss) and the URL would route to the wrong host
      // downstream. The guard also covers `wss://wss://x` (smuggled
      // double-prefix) and `wss://https://x` (cleartext under wss
      // wrapper).
      expect(isRelayUrlAllowed('wss://http://attacker.example.com'), isFalse);
      expect(isRelayUrlAllowed('wss://https://attacker.example.com'), isFalse);
      expect(isRelayUrlAllowed('wss://wss://relay.example.com'), isFalse);
      expect(isRelayUrlAllowed('wss://WSS://relay.example.com'), isFalse);
      expect(isRelayUrlAllowed('ws://http://attacker.example.com'), isFalse);
    });

    test('canonical loopback set (#3362 drift sentinel)', () {
      // Mirrored in:
      //  - mobile/packages/nostr_sdk/test/unit/nostr_remote_signer_info_test.dart
      //  - mobile/packages/nostr_client/test/src/relay_manager_test.dart
      // and `mobile/android/app/src/main/res/xml/network_security_config.xml`.
      // Diverging this set without updating the others is a security
      // regression.
      expect(isRelayUrlAllowed('ws://localhost:1'), isTrue);
      expect(isRelayUrlAllowed('ws://127.0.0.1:1'), isTrue);
      expect(isRelayUrlAllowed('ws://10.0.2.2:1'), isTrue);
      expect(isRelayUrlAllowed('ws://[::1]:1'), isTrue);
      expect(isRelayUrlAllowed('ws://example.com'), isFalse);
    });
  });

  group('relayWsToHttpBase', () {
    test('keeps generic relay host conversion unchanged', () {
      expect(
        relayWsToHttpBase('wss://relay.divine.video'),
        'https://relay.divine.video',
      );
    });
  });

  group('resolvePinnedApiBaseUrlFromRelays', () {
    test('resolves relay.divine.video to its HTTP base for notifications', () {
      expect(
        resolvePinnedApiBaseUrlFromRelays(
          configuredRelays: const ['wss://relay.divine.video'],
          fallbackBaseUrl: 'https://fallback.example.com',
        ),
        'https://relay.divine.video',
      );
    });

    test('returns fallback when divine relay is absent', () {
      expect(
        resolvePinnedApiBaseUrlFromRelays(
          configuredRelays: const ['wss://relay.damus.io'],
          fallbackBaseUrl: 'https://relay.staging.dvines.org',
        ),
        'https://relay.staging.dvines.org',
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
