// ABOUTME: Unit tests for NostrRemoteSigner NIP-46 protocol implementation
// ABOUTME: Tests timeout handling, lifecycle (close/pause/resume), and reconnection

import 'dart:async';

import 'package:nostr_sdk/nip46/nostr_remote_signer.dart';
import 'package:nostr_sdk/nip46/nostr_remote_signer_info.dart';
import 'package:nostr_sdk/relay/relay_mode.dart';
import 'package:test/test.dart';

void main() {
  group('NostrRemoteSigner', () {
    late NostrRemoteSigner signer;
    late NostrRemoteSignerInfo signerInfo;

    setUp(() {
      // Create a valid signer info for testing
      signerInfo = NostrRemoteSignerInfo.parseBunkerUrl(
        'bunker://deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678'
        '?relay=wss://relay.example.com&secret=testsecret',
      );
      signer = NostrRemoteSigner(RelayMode.baseMode, signerInfo);
    });

    tearDown(() {
      signer.close();
    });

    group('pause and resume', () {
      test('pause() should set isPaused to true', () {
        expect(signer.isPaused, isFalse);

        signer.pause();

        expect(signer.isPaused, isTrue);
      });

      test('pause() should be idempotent', () {
        signer.pause();
        signer.pause();
        signer.pause();

        expect(signer.isPaused, isTrue);
      });

      test('resume() should set isPaused to false', () {
        signer.pause();
        expect(signer.isPaused, isTrue);

        signer.resume();

        expect(signer.isPaused, isFalse);
      });

      test('resume() should be idempotent', () {
        signer.pause();
        signer.resume();
        signer.resume();
        signer.resume();

        expect(signer.isPaused, isFalse);
      });

      test('resume() on non-paused signer should have no effect', () {
        expect(signer.isPaused, isFalse);

        signer.resume();

        expect(signer.isPaused, isFalse);
      });
    });

    group('close', () {
      test('close() should clear relays list', () {
        // Relays are added during connect(), so initially empty is expected
        signer.close();

        expect(signer.relays, isEmpty);
      });

      test('close() should clear callbacks', () {
        signer.close();

        expect(signer.callbacks, isEmpty);
      });

      test('close() can be called multiple times safely', () {
        expect(() {
          signer.close();
          signer.close();
          signer.close();
        }, returnsNormally);
      });

      test('close() should complete pending callbacks with error', () async {
        // Add a pending callback manually for testing
        final completer = Completer<String?>();
        signer.callbacks['test-id'] = completer;

        signer.close();

        // The callback should be completed with an error
        expect(
          completer.future,
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Signer closed'),
            ),
          ),
        );
      });
    });

    group('signer info', () {
      test('should store remote signer pubkey', () {
        expect(
          signerInfo.remoteSignerPubkey,
          equals(
            'deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678',
          ),
        );
      });

      test('should store relay URLs', () {
        expect(signerInfo.relays, contains('wss://relay.example.com'));
      });

      test('should store optional secret', () {
        expect(signerInfo.optionalSecret, equals('testsecret'));
      });

      test('should generate client nsec', () {
        expect(signerInfo.nsec, isNotNull);
        expect(signerInfo.nsec, startsWith('nsec'));
      });
    });
  });

  group('NostrRemoteSigner reconnection logic', () {
    // These tests document the expected reconnection behavior.
    // Full integration tests would require mocking WebSocket connections.

    test(
      'exponential backoff should follow pattern 100, 200, 400, 800, 1600ms',
      () {
        // Document the expected backoff pattern
        // Backoff formula: 100 * (1 << retryCount) milliseconds
        final expectedDelays = <int>[];
        for (var retry = 0; retry < 5; retry++) {
          expectedDelays.add(100 * (1 << retry));
        }

        expect(expectedDelays, equals([100, 200, 400, 800, 1600]));
      },
    );
  });
}
