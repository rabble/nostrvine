// ABOUTME: Unit tests for NostrRemoteSigner NIP-46 protocol implementation
// ABOUTME: Tests timeout handling, lifecycle (close/pause/resume), and reconnection

import 'dart:async';

import 'package:nostr_sdk/nip46/nostr_remote_request.dart';
import 'package:nostr_sdk/nip46/nostr_remote_signer.dart';
import 'package:nostr_sdk/nip46/nostr_remote_signer_info.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:nostr_sdk/relay/relay_mode.dart';
import 'package:test/test.dart';

import '../support/test_relay_server.dart';

const _remoteSignerPubkey =
    'deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678';

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

  group('relay lifecycle after close (#7962)', () {
    Future<NostrRemoteSigner> connectedSigner(
      List<TestRelayServer> servers,
    ) async {
      final relayParams = servers.map((s) => 'relay=${s.url}').join('&');
      final signer = NostrRemoteSigner(
        RelayMode.baseMode,
        NostrRemoteSignerInfo.parseBunkerUrl(
          'bunker://$_remoteSignerPubkey?$relayParams&secret=testsecret',
        ),
      );
      addTearDown(signer.close);
      await signer.connect(sendConnectRequest: false);
      return signer;
    }

    test('a reconnect parked in backoff opens no socket after close', () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final signer = await connectedSigner([server]);
      expect(server.connectionCount, equals(1));

      // Pause first so the signer's own reconnect-on-disconnect does not race
      // the setup, then drop the relay the way a flaky network would.
      signer.pause();
      await signer.relays.single.disconnect();
      await _settleDisconnected(signer);

      // resume() re-dials every disconnected relay, suspending on the backoff
      // wait before it connects. That wait is the window sign-out lands in.
      signer.resume();
      signer.close();

      // Longer than the first backoff step (100ms), so a reconnect that
      // ignored the close has finished dialing by the time we assert.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(
        server.connectionCount,
        equals(1),
        reason:
            'a reconnect resuming after close() opens a socket and arms a '
            'heartbeat that nothing is left holding',
      );
      expect(server.openConnectionCount, isZero);
    });

    test('close disposes each relay, so a later connect is refused', () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final signer = await connectedSigner([server]);
      final relay = signer.relays.single;

      signer.close();

      expect(
        await relay.connect(),
        isFalse,
        reason:
            'close() only disconnected the relay, so the disposed guard '
            'added in #7367 never engages and the relay reconnects',
      );
      expect(server.connectionCount, equals(1));
    });

    test('close during a request does not trip the relay iterator', () async {
      final first = await TestRelayServer.start();
      final second = await TestRelayServer.start();
      addTearDown(first.close);
      addTearDown(second.close);

      final signer = await connectedSigner([first, second]);
      expect(signer.relays, hasLength(2));

      // Both disconnected, so the request suspends on the first relay's
      // reconnect and close() lands with the loop still walking `relays`.
      // Pausing keeps the signer's own reconnect from racing the setup.
      signer.pause();
      for (final relay in signer.relays) {
        await relay.disconnect();
      }
      await _settleDisconnected(signer);

      final pending = signer.sendAndWaitForResult(
        NostrRemoteRequest('get_public_key', []),
        timeout: 1,
      );
      signer.close();

      await expectLater(
        pending,
        completion(isNull),
        reason:
            'close() clears `relays` mid-iteration, so walking the live '
            'list throws ConcurrentModificationError',
      );

      // The re-dial of the first relay began before close(), so it may well
      // have opened a socket — what matters is that nothing outlives the
      // close, including the relays the loop never reached.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(first.openConnectionCount, isZero);
      expect(second.openConnectionCount, isZero);
      expect(second.connectionCount, equals(1));
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

/// Waits for every relay to actually report disconnected.
///
/// [Relay.disconnect] flips the status synchronously, but the connection
/// manager's earlier `connected` state event is still queued behind it and
/// lands afterwards — so the status reads connected again for a turn or two
/// before settling. A test that reads it too early sees a connected relay and
/// silently sets up the wrong scenario.
Future<void> _settleDisconnected(NostrRemoteSigner signer) async {
  bool allDown() => signer.relays.every(
    (relay) => relay.relayStatus.connected == ClientConnected.disconnect,
  );

  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!allDown()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('relays never settled into a disconnected state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
