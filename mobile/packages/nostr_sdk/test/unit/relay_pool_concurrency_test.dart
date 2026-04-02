// ABOUTME: Regression tests for RelayPool concurrent modification hazards.
// ABOUTME: Ensures autoSubscribe tolerates subscription changes during resend.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _MutatingRelay extends Relay {
  _MutatingRelay(String url, {required this.onFirstSend})
    : super(url, RelayStatus(url));

  final Future<void> Function() onFirstSend;
  final List<List<dynamic>> sentMessages = [];
  bool _didMutate = false;

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
  }) async {
    sentMessages.add(message);

    if (!_didMutate) {
      _didMutate = true;
      await onFirstSend();
    }

    return true;
  }
}

/// A relay that succeeds on send and immediately responds with EOSE.
class _SucceedingRelay extends Relay {
  _SucceedingRelay(String url) : super(url, RelayStatus(url));

  final List<List<dynamic>> sentMessages = [];

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
  }) async {
    sentMessages.add(message);
    // Simulate EOSE after a short delay so saveQuery runs first
    if (message.isNotEmpty && message.first == 'REQ') {
      final subId = message[1] as String;
      Future.delayed(const Duration(milliseconds: 10), () {
        if (onMessage != null) {
          onMessage!(this, ['EOSE', subId]);
        }
      });
    }
    return true;
  }
}

/// A relay that responds to COUNT queries with a configurable count.
class _CountRelay extends Relay {
  _CountRelay(String url, {required this.countValue})
    : super(url, RelayStatus(url));

  final int countValue;
  final List<List<dynamic>> sentMessages = [];

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
  }) async {
    sentMessages.add(message);
    if (message.isNotEmpty && message.first == 'COUNT') {
      final subId = message[1] as String;
      Future.delayed(const Duration(milliseconds: 10), () {
        if (onMessage != null) {
          onMessage!(this, [
            'COUNT',
            subId,
            {'count': countValue, 'approximate': false},
          ]);
        }
      });
    }
    return true;
  }
}

/// A relay that always fails to send, used to test that failed sends
/// do not block EOSE completion for other relays.
class _FailingSendRelay extends Relay {
  _FailingSendRelay(String url) : super(url, RelayStatus(url));

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
  }) async {
    return false; // Always fail
  }
}

void main() {
  group('RelayPool concurrency', () {
    late Nostr nostr;
    late LocalNostrSigner signer;

    setUp(() async {
      signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
    });

    test('failed relay send does not block query EOSE completion', () async {
      // Add a relay that always fails to send
      final failingRelay = _FailingSendRelay('wss://failing.relay');
      await nostr.relayPool.add(failingRelay);

      // Query should complete quickly (not hang for 10s timeout)
      // because the failing relay's query is never registered
      final stopwatch = Stopwatch()..start();
      final events = await nostr.queryEvents([
        {
          'kinds': [1],
          'limit': 1,
        },
      ], timeout: const Duration(seconds: 5));
      stopwatch.stop();

      // Should complete well under the 5s timeout since the only relay
      // fails to send and is not registered in the EOSE tracking
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      expect(events, isEmpty);
    });

    test(
      'query completes via EOSE when some relays succeed and some fail',
      () async {
        // Add one succeeding and one failing relay
        final succeedingRelay = _SucceedingRelay('wss://good.relay');
        final failingRelay = _FailingSendRelay('wss://failing.relay');
        await nostr.relayPool.add(succeedingRelay);
        await nostr.relayPool.add(failingRelay);

        final stopwatch = Stopwatch()..start();
        final events = await nostr.queryEvents([
          {
            'kinds': [1],
            'limit': 1,
          },
        ], timeout: const Duration(seconds: 5));
        stopwatch.stop();

        // Should complete quickly via EOSE from the succeeding relay,
        // not hang until the 5s timeout waiting for the failing one.
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
        expect(events, isA<List<Event>>());
        // The succeeding relay should have received the REQ
        expect(
          succeedingRelay.sentMessages.where((m) => m.first == 'REQ').length,
          equals(1),
        );
      },
    );

    test(
      'add(autoSubscribe: true) tolerates subscriptions added during resend',
      () async {
        nostr.relayPool.subscribe([
          Filter(kinds: const [1], limit: 1).toJson(),
        ], (_) {});

        final relay = _MutatingRelay(
          'wss://test.relay',
          onFirstSend: () async {
            nostr.relayPool.subscribe([
              Filter(kinds: const [7], limit: 1).toJson(),
            ], (_) {});
          },
        );

        await expectLater(
          nostr.relayPool.add(relay, autoSubscribe: true),
          completes,
        );
        expect(
          relay.sentMessages.where((message) => message.first == 'REQ').length,
          greaterThanOrEqualTo(1),
        );
      },
    );

    test('failed send does not register query on relay', () async {
      final failingRelay = _FailingSendRelay('wss://failing.relay');
      await nostr.relayPool.add(failingRelay);

      var completeCalled = false;
      await nostr.relayPool.query(
        [
          {
            'kinds': [1],
            'limit': 1,
          },
        ],
        (event) {},
        onComplete: () => completeCalled = true,
      );

      // onComplete should have been called immediately since no relay
      // accepted the query (saveQuery was never called)
      expect(completeCalled, isTrue);
    });
  });

  group('RelayPool COUNT concurrency', () {
    late Nostr nostr;
    late LocalNostrSigner signer;

    setUp(() async {
      signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
    });

    test('count returns highest count from multiple relays', () async {
      final relay1 = _CountRelay('wss://relay1.test', countValue: 10);
      final relay2 = _CountRelay('wss://relay2.test', countValue: 42);
      await nostr.relayPool.add(relay1);
      await nostr.relayPool.add(relay2);

      final result = await nostr.relayPool.count([
        {
          'kinds': [1],
        },
      ]);

      expect(result.count, equals(42));
    });

    test('count succeeds when some relays fail and some succeed', () async {
      final countRelay = _CountRelay('wss://good.relay', countValue: 7);
      final failingRelay = _FailingSendRelay('wss://failing.relay');
      await nostr.relayPool.add(countRelay);
      await nostr.relayPool.add(failingRelay);

      final result = await nostr.relayPool.count([
        {
          'kinds': [1],
        },
      ]);

      expect(result.count, equals(7));
    });

    test(
      'count throws CountNotSupportedException when all relays fail',
      () async {
        final failingRelay = _FailingSendRelay('wss://failing.relay');
        await nostr.relayPool.add(failingRelay);

        await expectLater(
          nostr.relayPool.count([
            {
              'kinds': [1],
            },
          ]),
          throwsA(isA<CountNotSupportedException>()),
        );
      },
    );
  });
}
