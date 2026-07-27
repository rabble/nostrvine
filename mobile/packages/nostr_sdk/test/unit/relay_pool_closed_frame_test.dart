// ABOUTME: Regression tests for CLOSED frames terminating a pending REQ.
// ABOUTME: A relay that CLOSEs a query must not strand the caller until timeout.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// Relay that records the REQ it was sent and answers only when the test says
/// so — never EVENT, never EOSE.
///
/// This mirrors Funnelcake, which replies `CLOSED` with no EOSE when the
/// stored-event query fails or the stored replay is backpressured
/// (`crates/relay/src/handler.rs:117`, `:405`, `:433`, `:488`).
class _ClosedOnReqRelay extends Relay {
  _ClosedOnReqRelay(String url) : super(url, RelayStatus(url));

  String? capturedSubId;

  @override
  Future<bool> doConnect() async {
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
    if (message.isNotEmpty && message[0] == 'REQ' && message.length > 1) {
      capturedSubId = message[1] as String;
    }
    return true;
  }

  Future<void> deliver(List<dynamic> json) async {
    final handler = onMessage;
    expect(handler, isNotNull, reason: 'RelayPool did not wire onMessage');
    final dynamic result = handler!(this, json);
    if (result is Future) {
      await result;
    }
  }

  /// Yields until the pool has registered the REQ as a pending query, so the
  /// CLOSED lands after `saveQuery` exactly as a network round trip would.
  Future<String> awaitPendingQuery() async {
    for (var i = 0; i < 1000; i++) {
      final subId = capturedSubId;
      if (subId != null && checkQuery(subId)) return subId;
      await Future<void>.delayed(Duration.zero);
    }
    fail('RelayPool never registered a pending query for the REQ');
  }
}

void main() {
  group('RelayPool CLOSED frame handling', () {
    Relay dummyTempRelay(String url) => RelayBase(url, RelayStatus(url));

    test('CLOSED on a pending REQ completes the query without waiting for '
        'the full timeout', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final relay = _ClosedOnReqRelay('wss://closed.example');

      expect(await nostr.relayPool.add(relay), isTrue);

      const timeout = Duration(seconds: 2);
      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'ids': [
            '0739befe110ec68c28a33650b84c10b356015ec3b8401787d05a84ae285c976a',
          ],
          'limit': 1,
        },
      ], timeout: timeout);

      final subId = await relay.awaitPendingQuery();
      await relay.deliver(['CLOSED', subId, 'error: query failed']);

      final result = await pending;
      stopwatch.stop();

      expect(result.events, isEmpty);
      expect(
        stopwatch.elapsed,
        lessThan(timeout ~/ 2),
        reason:
            'CLOSED should terminate the query immediately; instead the '
            'caller waited ${stopwatch.elapsedMilliseconds}ms of the '
            '${timeout.inMilliseconds}ms budget',
      );
      expect(
        result.timedOut,
        isFalse,
        reason: 'a relay-refused query is not a timeout',
      );
      expect(
        relay.checkQuery(subId),
        isFalse,
        reason: 'the refused query must not stay pending on the relay',
      );
    });

    test('EOSE still completes a pending REQ', () async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      final nostr = Nostr(signer, [], dummyTempRelay);
      final relay = _ClosedOnReqRelay('wss://eose.example');

      expect(await nostr.relayPool.add(relay), isTrue);

      const timeout = Duration(seconds: 2);
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: timeout);

      final subId = await relay.awaitPendingQuery();
      await relay.deliver(['EOSE', subId]);

      final result = await pending;
      expect(result.timedOut, isFalse);
      expect(result.events, isEmpty);
    });
  });
}
