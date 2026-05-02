// ABOUTME: Unit tests for NostrRemoteSignerInfo bunker URL parsing
// ABOUTME: Tests validation of relay parameters and URL schemes

import 'package:nostr_sdk/nip46/nostr_remote_signer_info.dart';
import 'package:test/test.dart';

void main() {
  group('NostrRemoteSignerInfo', () {
    group('isBunkerUrl', () {
      test('should return true for bunker:// URLs', () {
        expect(NostrRemoteSignerInfo.isBunkerUrl('bunker://pubkey'), isTrue);
        expect(
          NostrRemoteSignerInfo.isBunkerUrl(
            'bunker://abc123?relay=wss://relay.com',
          ),
          isTrue,
        );
      });

      test('should return false for non-bunker URLs', () {
        expect(
          NostrRemoteSignerInfo.isBunkerUrl('https://example.com'),
          isFalse,
        );
        expect(NostrRemoteSignerInfo.isBunkerUrl('wss://relay.com'), isFalse);
        expect(NostrRemoteSignerInfo.isBunkerUrl('nsec1abc'), isFalse);
        expect(NostrRemoteSignerInfo.isBunkerUrl(''), isFalse);
      });

      test('should return false for null', () {
        expect(NostrRemoteSignerInfo.isBunkerUrl(null), isFalse);
      });
    });

    group('parseBunkerUrl', () {
      group('relay parameter validation', () {
        test('should throw when relay parameter is missing', () {
          expect(
            () => NostrRemoteSignerInfo.parseBunkerUrl('bunker://pubkey123'),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('relay parameter missing'),
              ),
            ),
          );
        });

        test('should throw when relay parameter is empty', () {
          expect(
            () =>
                NostrRemoteSignerInfo.parseBunkerUrl('bunker://pubkey?relay='),
            throwsA(
              isA<InvalidBunkerRelayException>().having(
                (e) => e.relayUrl,
                'relayUrl',
                isEmpty,
              ),
            ),
          );
        });

        test('should throw when relay URL has no scheme', () {
          expect(
            () => NostrRemoteSignerInfo.parseBunkerUrl(
              'bunker://pubkey?relay=bad',
            ),
            throwsA(
              isA<InvalidBunkerRelayException>().having(
                (e) => e.relayUrl,
                'relayUrl',
                'bad',
              ),
            ),
          );
        });

        test('should throw when relay URL is http://', () {
          expect(
            () => NostrRemoteSignerInfo.parseBunkerUrl(
              'bunker://pubkey?relay=http://relay.com',
            ),
            throwsA(isA<InvalidBunkerRelayException>()),
          );
        });

        test('should throw when relay URL is https://', () {
          expect(
            () => NostrRemoteSignerInfo.parseBunkerUrl(
              'bunker://pubkey?relay=https://relay.com',
            ),
            throwsA(isA<InvalidBunkerRelayException>()),
          );
        });

        test('should throw when any relay in list is invalid', () {
          expect(
            () => NostrRemoteSignerInfo.parseBunkerUrl(
              'bunker://pubkey?relay=wss://good.com&relay=bad',
            ),
            throwsA(
              isA<InvalidBunkerRelayException>().having(
                (e) => e.relayUrl,
                'relayUrl',
                'bad',
              ),
            ),
          );
        });
      });

      group('insecure relay rejection (#3362)', () {
        test('rejects ws:// to non-loopback host', () {
          expect(
            () => NostrRemoteSignerInfo.parseBunkerUrl(
              'bunker://pubkey?relay=ws://attacker.example.com',
            ),
            throwsA(isA<InvalidBunkerRelayException>()),
          );
        });

        test('rejects ws:// suffix-match attack on localhost', () {
          expect(
            () => NostrRemoteSignerInfo.parseBunkerUrl(
              'bunker://pubkey?relay=ws://localhost.attacker.com',
            ),
            throwsA(isA<InvalidBunkerRelayException>()),
          );
        });

        test('rejects mixed list when any relay is insecure', () {
          expect(
            () => NostrRemoteSignerInfo.parseBunkerUrl(
              'bunker://pubkey?relay=wss://good.com'
              '&relay=ws://attacker.example.com',
            ),
            throwsA(isA<InvalidBunkerRelayException>()),
          );
        });

        test('toString() does not embed the rejected URL', () {
          try {
            NostrRemoteSignerInfo.parseBunkerUrl(
              'bunker://pubkey?relay=ws://attacker.example.com',
            );
            fail('Expected InvalidBunkerRelayException');
          } on InvalidBunkerRelayException catch (e) {
            expect(e.toString(), isNot(contains('attacker.example.com')));
            expect(e.relayUrl, equals('ws://attacker.example.com'));
          }
        });

        test('toString() never embeds relayUrl for any reject reason', () {
          // PII / log-hygiene contract: the rejected URL must only appear on
          // the typed `relayUrl` field, never in `toString()`. Pinned over
          // multiple rejection reasons so a future copy edit can't silently
          // re-introduce the URL into log lines.
          const insecureRelays = [
            'ws://attacker.example.com',
            'http://192.168.1.1',
            'ws://localhost.attacker.com',
            'http://relay.example.com:8080',
            'gibberish',
          ];
          for (final relay in insecureRelays) {
            try {
              NostrRemoteSignerInfo.parseBunkerUrl(
                'bunker://pubkey?relay=${Uri.encodeQueryComponent(relay)}',
              );
              fail('Expected InvalidBunkerRelayException for $relay');
            } on InvalidBunkerRelayException catch (e) {
              expect(
                e.toString(),
                isNot(contains(e.relayUrl)),
                reason: 'toString must not embed relayUrl=${e.relayUrl}',
              );
            }
          }
        });

        test('canonical loopback set (#3362 drift sentinel)', () {
          // Mirrored in:
          //  - mobile/test/utils/relay_url_utils_test.dart
          //  - mobile/packages/nostr_client/test/src/relay_manager_test.dart
          // and `mobile/android/app/src/main/res/xml/network_security_config.xml`.
          // Diverging this set without updating the others is a security
          // regression.
          const loopbackHosts = ['localhost', '127.0.0.1', '10.0.2.2', '[::1]'];
          for (final host in loopbackHosts) {
            final info = NostrRemoteSignerInfo.parseBunkerUrl(
              'bunker://pubkey?relay=ws://$host:8080',
            );
            expect(
              info.relays,
              contains('ws://$host:8080'),
              reason: 'ws://$host should be accepted as loopback',
            );
          }
        });

        test('accepts ws://localhost', () {
          final info = NostrRemoteSignerInfo.parseBunkerUrl(
            'bunker://pubkey?relay=ws://localhost:8080',
          );
          expect(info.relays, contains('ws://localhost:8080'));
        });

        test('accepts ws://127.0.0.1', () {
          final info = NostrRemoteSignerInfo.parseBunkerUrl(
            'bunker://pubkey?relay=ws://127.0.0.1:8080',
          );
          expect(info.relays, contains('ws://127.0.0.1:8080'));
        });

        test('accepts ws://10.0.2.2 (Android emulator host)', () {
          final info = NostrRemoteSignerInfo.parseBunkerUrl(
            'bunker://pubkey?relay=ws://10.0.2.2:47777',
          );
          expect(info.relays, contains('ws://10.0.2.2:47777'));
        });

        test('accepts nostrconnect:// with ws://localhost relay', () {
          final info = NostrRemoteSignerInfo.parseBunkerUrl(
            'nostrconnect://clientpubkey?relay=ws://localhost:8080'
            '&secret=abc',
          );
          expect(info.relays, contains('ws://localhost:8080'));
        });

        test('rejects nostrconnect:// with ws:// non-loopback relay', () {
          expect(
            () => NostrRemoteSignerInfo.parseBunkerUrl(
              'nostrconnect://clientpubkey'
              '?relay=ws://attacker.example.com&secret=abc',
            ),
            throwsA(isA<InvalidBunkerRelayException>()),
          );
        });

        test(
          'rejects mis-nested wss://http:// relay (#3362 review follow-up)',
          () {
            // `wss://http://attacker` parses as host=`http` and
            // path=`//attacker…`. Without the `path.startsWith('//')` guard
            // in `_isAllowedBunkerRelayUrl`, this URL would pass the
            // allowlist (scheme=wss) and the bunker session would point at
            // host `http`. The query parameter is URL-encoded so the parser
            // delivers the raw mis-nested form back to the predicate.
            expect(
              () => NostrRemoteSignerInfo.parseBunkerUrl(
                'bunker://pubkey?relay='
                '${Uri.encodeQueryComponent('wss://http://attacker.example.com')}',
              ),
              throwsA(isA<InvalidBunkerRelayException>()),
            );
          },
        );

        test(
          'rejects mis-nested wss://wss:// relay (smuggled double scheme)',
          () {
            expect(
              () => NostrRemoteSignerInfo.parseBunkerUrl(
                'bunker://pubkey?relay='
                '${Uri.encodeQueryComponent('wss://wss://relay.example.com')}',
              ),
              throwsA(isA<InvalidBunkerRelayException>()),
            );
          },
        );
      });

      group('successful parsing', () {
        test('should accept wss:// relay URL', () {
          final info = NostrRemoteSignerInfo.parseBunkerUrl(
            'bunker://pubkey123?relay=wss://relay.example.com',
          );

          expect(info.remoteSignerPubkey, equals('pubkey123'));
          expect(info.relays, contains('wss://relay.example.com'));
        });

        test('should accept ws:// relay URL', () {
          final info = NostrRemoteSignerInfo.parseBunkerUrl(
            'bunker://pubkey123?relay=ws://localhost:8080',
          );

          expect(info.remoteSignerPubkey, equals('pubkey123'));
          expect(info.relays, contains('ws://localhost:8080'));
        });

        test('should accept multiple valid relay URLs', () {
          final info = NostrRemoteSignerInfo.parseBunkerUrl(
            'bunker://pubkey?relay=wss://relay1.com&relay=wss://relay2.com',
          );

          expect(info.relays, hasLength(2));
          expect(info.relays, contains('wss://relay1.com'));
          expect(info.relays, contains('wss://relay2.com'));
        });

        test('should parse secret parameter', () {
          final info = NostrRemoteSignerInfo.parseBunkerUrl(
            'bunker://pubkey?relay=wss://relay.com&secret=mysecret123',
          );

          expect(info.optionalSecret, equals('mysecret123'));
        });

        test('should handle missing secret parameter', () {
          final info = NostrRemoteSignerInfo.parseBunkerUrl(
            'bunker://pubkey?relay=wss://relay.com',
          );

          expect(info.optionalSecret, isNull);
        });

        test('should generate nsec when not provided', () {
          final info = NostrRemoteSignerInfo.parseBunkerUrl(
            'bunker://pubkey?relay=wss://relay.com',
          );

          expect(info.nsec, isNotNull);
          expect(info.nsec, startsWith('nsec'));
        });

        test('should use provided nsec parameter', () {
          const testNsec = 'nsec1test123';
          final info = NostrRemoteSignerInfo.parseBunkerUrl(
            'bunker://pubkey?relay=wss://relay.com',
            nsec: testNsec,
          );

          expect(info.nsec, equals(testNsec));
        });
      });
    });
  });
}
