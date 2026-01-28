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
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('should start with wss:// or ws://'),
              ),
            ),
          );
        });

        test(
          'should throw when relay URL does not start with wss:// or ws://',
          () {
            expect(
              () => NostrRemoteSignerInfo.parseBunkerUrl(
                'bunker://pubkey?relay=bad',
              ),
              throwsA(
                isA<Exception>().having(
                  (e) => e.toString(),
                  'message',
                  contains('relay bad should start with wss:// or ws://'),
                ),
              ),
            );
          },
        );

        test('should throw when relay URL is http://', () {
          expect(
            () => NostrRemoteSignerInfo.parseBunkerUrl(
              'bunker://pubkey?relay=http://relay.com',
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('should start with wss:// or ws://'),
              ),
            ),
          );
        });

        test('should throw when relay URL is https://', () {
          expect(
            () => NostrRemoteSignerInfo.parseBunkerUrl(
              'bunker://pubkey?relay=https://relay.com',
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('should start with wss:// or ws://'),
              ),
            ),
          );
        });

        test('should throw when any relay in list is invalid', () {
          expect(
            () => NostrRemoteSignerInfo.parseBunkerUrl(
              'bunker://pubkey?relay=wss://good.com&relay=bad',
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('relay bad should start with wss:// or ws://'),
              ),
            ),
          );
        });
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
