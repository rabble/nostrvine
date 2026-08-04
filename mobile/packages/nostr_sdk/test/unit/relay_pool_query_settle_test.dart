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

  /// When set, a `REQ` write blocks until [releaseReq], which holds the pool's
  /// fan-out open while other relays answer.
  Completer<void>? reqGate;

  void releaseReq() {
    final gate = reqGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  /// `CLOSE` frames this relay was sent, by subscription id.
  List<String> get closedSubIds => [
    for (final message in sentMessages)
      if (message.isNotEmpty && message[0] == 'CLOSE' && message.length > 1)
        message[1] as String,
  ];

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
      final gate = reqGate;
      if (gate != null) await gate.future;
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

    test('one relay that never answers cannot hold the caller past the settle '
        'window once another relay has', () async {
      final nostr = _newNostr();
      final answering = _SilentRelay('wss://answers.example');
      final mute = _SilentRelay('wss://never-eoses.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(mute), isTrue);

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      final subId = await answering.awaitPendingQuery();
      await mute.awaitPendingQuery();
      // `mute` stays connected and simply never sends a terminal frame — the
      // shape measured against relay.divine.video.
      await answering.deliver(['EOSE', subId]);

      final result = await pending;
      stopwatch.stop();

      expect(result.timedOut, isFalse);
      expect(
        stopwatch.elapsed,
        lessThan(_timeout),
        reason: 'the settle window must bound the silent relay',
      );
      expect(
        stopwatch.elapsed,
        greaterThanOrEqualTo(RelayPool.querySettleWindow),
        reason: 'the silent relay still gets its grace period first',
      );
    });

    test('the settle window closes the REQ it abandons', () async {
      final nostr = _newNostr();
      final answering = _SilentRelay('wss://answers.example');
      final mute = _SilentRelay('wss://never-eoses.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(mute), isTrue);

      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      final subId = await answering.awaitPendingQuery();
      await mute.awaitPendingQuery();
      await answering.deliver(['EOSE', subId]);
      await pending;

      // The caller is gone, so the REQ it left on the silent relay has to go
      // with it. Left open it stays live for the life of the socket — against
      // the relay's concurrent-subscription cap, pinning the caller's event
      // box, and re-issued by every post-AUTH and zombie-reconnect replay.
      expect(
        mute.closedSubIds,
        contains(subId),
        reason: 'the abandoned REQ must be closed on the relay',
      );
      expect(
        mute.checkQuery(subId),
        isFalse,
        reason: 'and dropped from the pool-side query book',
      );
    });

    test('a terminal frame that lands during fan-out still arms the settle '
        'window', () async {
      final nostr = _newNostr();
      final fast = _SilentRelay('wss://fast.example');
      final blocked = _SilentRelay('wss://slow-to-accept.example')
        ..reqGate = Completer<void>();
      expect(await nostr.relayPool.add(fast), isTrue);
      expect(await nostr.relayPool.add(blocked), isTrue);

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      // `fast` answers while `blocked` has not finished accepting its REQ, so
      // the completion sweep driven by that EOSE is swallowed by the fan-out
      // guard. The window still has to arm off it once fan-out ends.
      final subId = await fast.awaitPendingQuery();
      await fast.deliver(['EOSE', subId]);
      blocked.releaseReq();

      final result = await pending;
      stopwatch.stop();

      expect(result.timedOut, isFalse);
      expect(
        stopwatch.elapsed,
        lessThan(_timeout),
        reason: 'an EOSE during fan-out is still proof the fan-out is served',
      );
    });

    test('an auth-gated relay that has not been challenged yet still holds '
        'the query', () async {
      final nostr = _newNostr();
      final answering = _SilentRelay('wss://answers.example');
      final gated = _SilentRelay('wss://gated.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(gated), isTrue);

      // `alwaysAuth` latches for the session, so a relay that has just
      // reconnected sits in this state for the round trip before its challenge
      // arrives. Writing it off there would drop every read-gated relay's
      // results on cold start.
      gated.relayStatus.alwaysAuth = true;

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      final subId = await answering.awaitPendingQuery();
      await gated.awaitPendingQuery();
      await answering.deliver(['EOSE', subId]);

      await pending;
      stopwatch.stop();

      expect(
        stopwatch.elapsed,
        greaterThanOrEqualTo(RelayPool.querySettleWindow),
        reason: 'an unchallenged auth gate is not evidence the gate is shut',
      );
    });

    test('a reconnect gives a relay whose auth gate was shut a fresh '
        'handshake', () async {
      final nostr = _newNostr();
      final gated = _SilentRelay('wss://gated.example');
      expect(await nostr.relayPool.add(gated), isTrue);
      gated.relayStatus.alwaysAuth = true;

      // First connection: the relay refuses the REQ outright, so the gate is
      // recorded shut and the caller stops waiting on it.
      final first = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);
      final firstSubId = await gated.awaitPendingQuery();
      await gated.deliver(['CLOSED', firstSubId, 'auth-required: sign in']);
      expect((await first).timedOut, isFalse);

      // The socket cycles. Whatever the previous connection concluded about
      // NIP-42 does not carry over to the new one.
      gated.onError('socket closed', reconnect: true);
      expect(await gated.connect(), isTrue);

      final answering = _SilentRelay('wss://answers.example');
      expect(await nostr.relayPool.add(answering), isTrue);

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      final subId = await answering.awaitPendingQuery();
      await gated.awaitPendingQuery();
      await answering.deliver(['EOSE', subId]);

      await pending;
      stopwatch.stop();

      expect(
        stopwatch.elapsed,
        greaterThanOrEqualTo(RelayPool.querySettleWindow),
        reason: 'the fresh connection has not refused anything yet',
      );
    });

    test('a relay still streaming its result set is not cut off by the settle '
        'window', () async {
      final nostr = _newNostr();
      final fast = _SilentRelay('wss://fast.example');
      final streaming = _SilentRelay('wss://streams-slowly.example');
      expect(await nostr.relayPool.add(fast), isTrue);
      expect(await nostr.relayPool.add(streaming), isTrue);
      final pubkey = await nostr.ensurePublicKey();

      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      final subId = await fast.awaitPendingQuery();
      await streaming.awaitPendingQuery();
      // `fast` has nothing to return and answers at once, arming the window.
      await fast.deliver(['EOSE', subId]);

      // `streaming` is healthy and part-way through a result set larger than
      // the window. Its events are the proof it has not gone silent, so the
      // window must not expire under it and truncate the caller's results.
      const streamed = 5;
      for (var i = 0; i < streamed; i++) {
        await Future<void>.delayed(RelayPool.querySettleWindow ~/ 2);
        final event = await nostr.nostrSigner.signEvent(
          Event(pubkey, EventKind.textNote, const [], 'streamed-$i'),
        );
        await streaming.deliver(['EVENT', subId, event!.toJson()]);
      }
      await streaming.deliver(['EOSE', subId]);

      final result = await pending;
      expect(result.timedOut, isFalse);
      expect(
        result.events,
        hasLength(streamed),
        reason:
            'every event the relay sent must reach the caller — a '
            'truncated result set reads as a complete one',
      );
    });

    test(
      'an outstanding NIP-42 handshake survives the settle window',
      () async {
        final nostr = _newNostr();
        final answering = _SilentRelay('wss://answers.example');
        final gated = _SilentRelay('wss://gated.example');
        expect(await nostr.relayPool.add(answering), isTrue);
        expect(await nostr.relayPool.add(gated), isTrue);

        final pending = nostr.queryEventsDetailed([
          {
            'kinds': [1],
          },
        ], timeout: _timeout);

        final subId = await answering.awaitPendingQuery();
        await gated.awaitPendingQuery();

        // The gate challenges us and parks the query for the post-AUTH replay.
        // Signing is a network call under a NIP-46 remote signer, so the `OK`
        // can easily land after the settle window a sibling arms.
        await gated.deliver(['AUTH', 'test-challenge']);
        await gated.deliver(['CLOSED', subId, 'auth-required: sign in']);
        expect(gated.capturedAuthEventId, isNotNull);

        await answering.deliver(['EOSE', subId]);
        await Future<void>.delayed(RelayPool.querySettleWindow * 1.5);

        // Closing the REQ here would leave the replay loop in the AUTH `OK`
        // handler nothing to re-issue, so a read-gated relay would contribute
        // nothing to any query a sibling answers first.
        expect(
          gated.getQueries(),
          isNotEmpty,
          reason: 'a relay mid-handshake is being served, not silent',
        );
        expect(gated.closedSubIds, isNot(contains(subId)));

        await gated.deliver(['OK', gated.capturedAuthEventId, true, '']);
        expect(
          gated.sentMessages.where((m) => m.isNotEmpty && m[0] == 'REQ'),
          hasLength(2),
          reason: 'the post-AUTH replay still reaches the original caller',
        );

        await pending;
      },
    );

    test('a handshake that is never answered still gets bounded', () async {
      final nostr = _newNostr();
      final answering = _SilentRelay('wss://answers.example');
      final gated = _SilentRelay('wss://swallows-auth.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(gated), isTrue);

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: RelayPool.authHandshakeWindow * 3);

      final subId = await answering.awaitPendingQuery();
      await gated.awaitPendingQuery();
      // Our AUTH event goes out and the relay never answers it. Nothing about
      // that relay distinguishes it from one still working, so only the
      // handshake window can end the wait.
      await gated.deliver(['AUTH', 'test-challenge']);
      await gated.deliver(['CLOSED', subId, 'auth-required: sign in']);
      await answering.deliver(['EOSE', subId]);

      final result = await pending;
      stopwatch.stop();

      expect(result.timedOut, isFalse);
      expect(
        stopwatch.elapsed,
        lessThan(RelayPool.authHandshakeWindow * 3),
        reason: 'a swallowed AUTH must not cost the caller its whole budget',
      );
    });

    test(
      "a stale handshake stops suppressing the relay's own refusal",
      () async {
        final nostr = _newNostr();
        final gated = _SilentRelay('wss://swallows-auth.example');
        expect(await nostr.relayPool.add(gated), isTrue);

        // The relay challenges us, takes our AUTH event, and never answers it.
        final first = nostr.queryEventsDetailed([
          {
            'kinds': [1],
          },
        ], timeout: const Duration(milliseconds: 300));
        final firstSubId = await gated.awaitPendingQuery();
        await gated.deliver(['AUTH', 'test-challenge']);
        await gated.deliver(['CLOSED', firstSubId, 'auth-required: sign in']);
        expect(gated.capturedAuthEventId, isNotNull);
        await first;

        // No `OK` lands and the socket never cycles, so the marker is still
        // there while the handshake it describes is long dead.
        await Future<void>.delayed(RelayPool.authHandshakeWindow * 1.2);

        final stopwatch = Stopwatch()..start();
        final pending = nostr.queryEventsDetailed([
          {
            'kinds': [1],
          },
        ], timeout: _timeout);
        final subId = await gated.awaitPendingQuery();
        // The relay names the gate again. A dead handshake is not a reason to
        // discard that evidence — nothing is going to run the replay it parks
        // the query for, so every later query would pay its full budget.
        await gated.deliver(['CLOSED', subId, 'auth-required: sign in']);

        final result = await pending;
        stopwatch.stop();

        expect(result.timedOut, isFalse);
        expect(
          stopwatch.elapsed,
          lessThan(RelayPool.querySettleWindow),
          reason: 'the refusal releases the query outright, not on a timer',
        );
      },
    );

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
