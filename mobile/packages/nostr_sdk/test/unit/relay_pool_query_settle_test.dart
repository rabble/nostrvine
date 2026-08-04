// ABOUTME: Regression tests for one-shot query completion accounting.
// ABOUTME: A relay that can no longer answer must not hold a query open.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// Relay that records what it was sent and only answers when the test says so.
class _SilentRelay extends Relay {
  _SilentRelay(String url, {bool connectSucceeds = true})
    : _connectSucceeds = connectSucceeds,
      super(url, RelayStatus(url));

  final bool _connectSucceeds;

  String? capturedSubId;
  String? capturedAuthEventId;
  final List<List<dynamic>> sentMessages = [];

  /// When false, [send] reports failure the way a dead socket does.
  bool sendSucceeds = true;

  @override
  Future<bool> doConnect() async {
    if (!_connectSucceeds) return false;
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool? forceSend,
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    sentMessages.add(message);
    if (message.isNotEmpty && message[0] == 'REQ' && message.length > 1) {
      capturedSubId = message[1] as String;
    } else if (message.isNotEmpty &&
        message[0] == 'AUTH' &&
        message.length > 1 &&
        message[1] is Map) {
      capturedAuthEventId = (message[1] as Map)['id'] as String?;
    }
    return sendSucceeds;
  }

  Future<void> deliver(List<dynamic> json) async {
    final handler = onMessage;
    expect(handler, isNotNull, reason: 'RelayPool did not wire onMessage');
    final dynamic result = handler!(this, json);
    if (result is Future) await result;
  }

  Future<String> awaitPendingQuery() async {
    for (var i = 0; i < 1000; i++) {
      final subId = capturedSubId;
      if (subId != null && checkQuery(subId)) return subId;
      await Future<void>.delayed(Duration.zero);
    }
    fail('RelayPool never registered a pending query for the REQ');
  }
}

/// A query timeout long enough that reaching it means the pool stalled rather
/// than that the test was slow.
const _timeout = Duration(seconds: 4);

Nostr _newNostr() => Nostr(
  LocalNostrSigner(
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
  ),
  [],
  (url) => RelayBase(url, RelayStatus(url)),
);

void main() {
  group('RelayPool one-shot query settling', () {
    test('an auth-gated relay with no handshake outstanding does not hold the '
        'query open', () async {
      final nostr = _newNostr();
      final relay = _SilentRelay('wss://auth-gated.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      // The relay challenged us at some earlier point in the session, so
      // alwaysAuth is latched on. Nothing ever completed NIP-42 — signing was
      // unavailable, or the challenge was never answered — so no AUTH event is
      // in flight and the gate will never open on its own.
      relay.relayStatus.alwaysAuth = true;

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      final subId = await relay.awaitPendingQuery();
      await relay.deliver(['CLOSED', subId, 'auth-required: sign in']);

      final result = await pending;
      stopwatch.stop();

      expect(
        result.timedOut,
        isFalse,
        reason: 'nothing was going to release this query but the timeout',
      );
      expect(
        stopwatch.elapsed,
        lessThan(_timeout),
        reason: 'the caller must not pay the full query timeout',
      );
    });

    test(
      'a rejected AUTH releases queries parked for post-AUTH replay',
      () async {
        final nostr = _newNostr();
        final relay = _SilentRelay('wss://auth-rejects.example');
        expect(await nostr.relayPool.add(relay), isTrue);

        final stopwatch = Stopwatch()..start();
        final pending = nostr.queryEventsDetailed([
          {
            'kinds': [1],
          },
        ], timeout: _timeout);

        final subId = await relay.awaitPendingQuery();
        await relay.deliver(['AUTH', 'test-challenge']);
        await relay.deliver(['CLOSED', subId, 'auth-required: sign in']);

        // The handshake is outstanding here, so the query is legitimately parked
        // waiting for the replay (pinned by relay_pool_closed_frame_test).
        final authEventId = relay.capturedAuthEventId;
        expect(authEventId, isNotNull);

        // The relay refuses our AUTH: the replay is never going to happen.
        await relay.deliver([
          'OK',
          authEventId,
          false,
          'invalid: bad signature',
        ]);

        final result = await pending;
        stopwatch.stop();

        expect(result.timedOut, isFalse);
        expect(
          stopwatch.elapsed,
          lessThan(_timeout),
          reason: 'a refused AUTH must release the parked query immediately',
        );
      },
    );

    test('a relay that drops its socket does not hold the query open', () async {
      final nostr = _newNostr();
      final dropping = _SilentRelay('wss://drops.example');
      expect(await nostr.relayPool.add(dropping), isTrue);

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      await dropping.awaitPendingQuery();
      // The socket dies before any terminal frame arrives. The REQ that was on
      // it is gone; a reconnect replays it on a fresh socket, long after this
      // caller has given up.
      dropping.onError('socket closed', reconnect: true);

      final result = await pending;
      stopwatch.stop();

      expect(result.timedOut, isFalse);
      expect(
        stopwatch.elapsed,
        lessThan(_timeout),
        reason: 'a dropped socket cannot deliver EOSE for its REQ',
      );
    });

    test('a healthy relay still holds the query until its EOSE', () async {
      final nostr = _newNostr();
      final fast = _SilentRelay('wss://fast.example');
      final slow = _SilentRelay('wss://slow.example');
      expect(await nostr.relayPool.add(fast), isTrue);
      expect(await nostr.relayPool.add(slow), isTrue);

      var completedEarly = false;
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);
      unawaited(pending.whenComplete(() => completedEarly = true));

      final fastSubId = await fast.awaitPendingQuery();
      final slowSubId = await slow.awaitPendingQuery();

      await fast.deliver(['EOSE', fastSubId]);
      await Future<void>.delayed(Duration.zero);
      expect(
        completedEarly,
        isFalse,
        reason: 'the second, still-connected relay owes a terminal frame',
      );

      await slow.deliver(['EOSE', slowSubId]);
      final result = await pending;
      expect(result.timedOut, isFalse);
    });
  });
}
