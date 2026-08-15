// ABOUTME: Regression tests for which relays count as publish targets.
// ABOUTME: A configured-but-disconnected relay must not inflate the denominator.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

import '../support/fake_web_socket.dart';

/// Answers `OK true` from [factory]'s channel as soon as its EVENT lands.
void _acceptEventWhenSent(FakeWebSocketChannelFactory factory, String eventId) {
  Timer? timer;
  timer = Timer.periodic(const Duration(milliseconds: 5), (_) {
    if (factory.createdChannels.isEmpty) return;
    final channel = factory.createdChannels.last;
    final sawEvent = channel.sentMessages.any((m) {
      final frame = jsonDecode(m as String) as List<dynamic>;
      return frame.first == 'EVENT';
    });
    if (!sawEvent) return;
    timer?.cancel();
    channel.simulateMessage(jsonEncode(['OK', eventId, true, '']));
  });
  addTearDown(() => timer?.cancel());
}

Future<void> _waitForRelayState(RelayBase relay, int state) async {
  for (var i = 0; i < 50; i++) {
    if (relay.relayStatus.connected == state) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('relay ${relay.url} did not reach state $state');
}

void main() {
  group('RelayPool publish targets', () {
    const liveUrl = 'wss://relay.divine.video';
    const downUrl = 'wss://relay.offline.example';
    const secondDownUrl = 'wss://relay.offline-two.example';
    const bystanderUrl = 'wss://relay.bystander.example';
    const eventId = 'target-denominator-event-id';

    late LocalNostrSigner signer;
    late Nostr nostr;
    late FakeWebSocketChannelFactory liveFactory;

    setUp(() async {
      signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();

      liveFactory = FakeWebSocketChannelFactory();
      await nostr.relayPool.add(
        RelayBase(liveUrl, RelayStatus(liveUrl), channelFactory: liveFactory),
      );

      // Configured, write-enabled, but the socket never comes up. `add()`
      // keeps it in the pool even when connect() fails, which is exactly the
      // steady state on mobile when one of the user's relays is down.
      await nostr.relayPool.add(
        RelayBase(
          downUrl,
          RelayStatus(downUrl),
          channelFactory: FakeWebSocketChannelFactory(
            readyError: StateError('unreachable'),
          ),
        ),
      );
    });

    /// Answers `OK true` from the live relay as soon as its EVENT lands.
    void acceptFromLiveRelay() {
      _acceptEventWhenSent(liveFactory, eventId);
    }

    test(
      'a configured relay that never connected is not a publish target',
      () async {
        acceptFromLiveRelay();

        final outcome = await nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': eventId, 'kind': 5},
          ],
          eventId: eventId,
          timeout: const Duration(milliseconds: 400),
        );

        expect(outcome.acceptedBy, equals([liveUrl]));
        expect(
          outcome.unreachableTargets,
          isEmpty,
          reason:
              'a relay that was never connected was never a target, so it '
              'cannot be an unreachable one',
        );
        expect(outcome.targetCount, equals(1));
        expect(
          outcome.acceptedByAll,
          isTrue,
          reason:
              'every relay this publish could reach accepted it, so the '
              'outcome must not read as partial',
        );
      },
    );

    test(
      'an explicitly targeted relay is reported unreachable, not dropped',
      () async {
        acceptFromLiveRelay();

        // Naming relays is the caller asserting intent — the kind:10002
        // bootstrap does this so it can tell an unreached indexer from a
        // refusing one. Silently shrinking the denominator would destroy
        // exactly the signal it publishes for.
        final outcome = await nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': eventId, 'kind': 10002},
          ],
          eventId: eventId,
          targetRelays: const [liveUrl, downUrl],
          timeout: const Duration(milliseconds: 400),
        );

        expect(outcome.acceptedBy, equals([liveUrl]));
        expect(outcome.unreachableTargets, equals([downUrl]));
        expect(outcome.targetCount, equals(2));
        expect(outcome.acceptedByAll, isFalse);
      },
    );

    test(
      'a connected relay outside the target list cannot decide the publish',
      () async {
        // Trackers are keyed on event id alone, so without the `isTarget`
        // gate any connected relay could accept or reject a publish it was
        // never sent — deciding the outcome of, say, a narrowly targeted
        // direct message it has no part in.
        final bystanderFactory = FakeWebSocketChannelFactory();
        await nostr.relayPool.add(
          RelayBase(
            bystanderUrl,
            RelayStatus(bystanderUrl),
            channelFactory: bystanderFactory,
          ),
        );
        acceptFromLiveRelay();
        // The bystander volunteers an OK for an event it never received.
        Timer.run(() {
          bystanderFactory.createdChannels.single.simulateMessage(
            jsonEncode(['OK', eventId, true, '']),
          );
        });

        final outcome = await nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': eventId, 'kind': 5},
          ],
          eventId: eventId,
          targetRelays: const [liveUrl],
          timeout: const Duration(milliseconds: 400),
        );

        expect(outcome.acceptedBy, equals([liveUrl]));
        expect(
          outcome.acceptedBy,
          isNot(contains(bystanderUrl)),
          reason: 'a relay outside targetRelays must not be able to accept',
        );
        expect(outcome.rejectedBy.keys, isNot(contains(bystanderUrl)));
        expect(outcome.noResponseFrom, isNot(contains(bystanderUrl)));
      },
    );

    test(
      'a publish that reached nothing still reports how many relays it had',
      () async {
        // Every relay offline. Narrowing the counted set must not collapse the
        // outcome to targetCount 0 — "you have no relays" and "every relay you
        // have is down" need to stay distinguishable in logs and error copy.
        nostr.relayPool.removeAll();
        for (final url in [downUrl, secondDownUrl]) {
          await nostr.relayPool.add(
            RelayBase(
              url,
              RelayStatus(url),
              channelFactory: FakeWebSocketChannelFactory(
                readyError: StateError('unreachable'),
              ),
            ),
          );
        }

        final outcome = await nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': eventId, 'kind': 5},
          ],
          eventId: eventId,
          timeout: const Duration(milliseconds: 400),
        );

        expect(outcome.failed, isTrue);
        expect(outcome.targetCount, equals(2));
        expect(
          outcome.unreachableTargets,
          containsAll(<String>[downUrl, secondDownUrl]),
        );
        expect(outcome.summary, contains('2 unreachable'));
      },
    );
  });

  group('RelayPool publish targets while relays are still connecting', () {
    const fastUrl = 'wss://relay.fast.example';
    const slowUrl = 'wss://relay.slow.example';
    const failedUrl = 'wss://relay.failed.example';
    const eventId = 'still-connecting-event-id';

    test(
      'counts an OK from a relay whose handshake was still in flight',
      () async {
        final signer = LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        );
        final nostr = Nostr(
          signer,
          [],
          (url) => RelayBase(url, RelayStatus(url)),
        );
        await nostr.refreshPublicKey();

        // Both relays are healthy; both handshakes are simply still in flight
        // when the publish starts — the ordinary shape right after launch or a
        // connectivity flap, where `relayStatus.connected` has not caught up
        // with the socket yet. The fast one lands and answers while the
        // sequential fan-out is still waiting on the slow one, so its OK
        // arrives before the fan-out reports which relays it wrote to.
        final fastFactory = FakeWebSocketChannelFactory(
          readyDelay: const Duration(milliseconds: 30),
        );
        unawaited(
          nostr.relayPool.add(
            RelayBase(
              fastUrl,
              RelayStatus(fastUrl),
              channelFactory: fastFactory,
            ),
          ),
        );
        unawaited(
          nostr.relayPool.add(
            RelayBase(
              slowUrl,
              RelayStatus(slowUrl),
              channelFactory: FakeWebSocketChannelFactory(
                readyDelay: const Duration(milliseconds: 800),
              ),
            ),
          ),
        );

        _acceptEventWhenSent(fastFactory, eventId);

        final outcome = await nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': eventId, 'kind': 5},
          ],
          eventId: eventId,
          timeout: const Duration(seconds: 3),
        );

        expect(
          outcome.acceptedBy,
          contains(fastUrl),
          reason:
              'the relay answered OK true, so it must be allowed to speak for '
              'the publish however unconnected it looked when targets were '
              'resolved — discarding the answer turns a confirmed publish into '
              'a failed one',
        );
        expect(outcome.failed, isFalse);
      },
    );

    test(
      'reports an attempted connecting relay as unreachable when write times out',
      () async {
        final signer = LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        );
        final nostr = Nostr(
          signer,
          [],
          (url) => RelayBase(url, RelayStatus(url)),
        );
        await nostr.refreshPublicKey();

        final fastFactory = FakeWebSocketChannelFactory();
        await nostr.relayPool.add(
          RelayBase(fastUrl, RelayStatus(fastUrl), channelFactory: fastFactory),
        );

        final slowAdd = nostr.relayPool.add(
          RelayBase(
            slowUrl,
            RelayStatus(slowUrl),
            channelFactory: FakeWebSocketChannelFactory(
              readyDelay: const Duration(milliseconds: 800),
            ),
          ),
        );

        _acceptEventWhenSent(fastFactory, eventId);

        final outcome = await nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': eventId, 'kind': 5},
          ],
          eventId: eventId,
          timeout: const Duration(milliseconds: 250),
        );
        await slowAdd;

        expect(outcome.acceptedBy, equals([fastUrl]));
        expect(outcome.unreachableTargets, equals([slowUrl]));
        expect(outcome.noResponseFrom, isNot(contains(slowUrl)));
        expect(outcome.targetCount, equals(2));
        expect(
          outcome.acceptedByAll,
          isFalse,
          reason:
              'a relay whose connecting socket was actually attempted and '
              'timed out must still count as unreachable',
        );
      },
    );

    test(
      'reports an attempted connecting relay as unreachable when connect fails',
      () async {
        final signer = LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        );
        final nostr = Nostr(
          signer,
          [],
          (url) => RelayBase(url, RelayStatus(url)),
        );
        await nostr.refreshPublicKey();

        final fastFactory = FakeWebSocketChannelFactory();
        await nostr.relayPool.add(
          RelayBase(fastUrl, RelayStatus(fastUrl), channelFactory: fastFactory),
        );

        final failedReady = Completer<void>();
        final failedRelay = RelayBase(
          failedUrl,
          RelayStatus(failedUrl),
          channelFactory: FakeWebSocketChannelFactory(
            readyFutureFactory: () => failedReady.future,
          ),
        );
        final failedAdd = nostr.relayPool.add(failedRelay);
        await _waitForRelayState(failedRelay, ClientConnected.connecting);

        _acceptEventWhenSent(fastFactory, eventId);
        final failTimer = Timer(const Duration(milliseconds: 20), () {
          failedReady.completeError(StateError('connect failed'));
        });
        addTearDown(failTimer.cancel);

        final outcome = await nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': eventId, 'kind': 5},
          ],
          eventId: eventId,
          timeout: const Duration(seconds: 1),
        );
        await failedAdd;

        expect(outcome.acceptedBy, equals([fastUrl]));
        expect(outcome.unreachableTargets, equals([failedUrl]));
        expect(outcome.noResponseFrom, isNot(contains(failedUrl)));
        expect(outcome.targetCount, equals(2));
        expect(outcome.acceptedByAll, isFalse);
      },
    );

    test(
      'counts an attempted relay whose status still lags the socket',
      () async {
        final signer = LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        );
        final nostr = Nostr(
          signer,
          [],
          (url) => RelayBase(url, RelayStatus(url)),
        );
        await nostr.refreshPublicKey();

        final fastFactory = FakeWebSocketChannelFactory();
        await nostr.relayPool.add(
          RelayBase(fastUrl, RelayStatus(fastUrl), channelFactory: fastFactory),
        );

        final slowRelay = RelayBase(
          slowUrl,
          RelayStatus(slowUrl),
          channelFactory: FakeWebSocketChannelFactory(
            readyDelay: const Duration(milliseconds: 800),
          ),
        );
        final slowAdd = nostr.relayPool.add(slowRelay);
        await _waitForRelayState(slowRelay, ClientConnected.connecting);

        // `relayStatus.connected` is written from the connection manager's
        // state stream, so it trails the socket it describes. Force the stale
        // reading the fan-out can genuinely observe: the manager is already
        // connecting, the pool-visible status still says disconnect.
        slowRelay.relayStatus.connected = ClientConnected.disconnect;

        _acceptEventWhenSent(fastFactory, eventId);

        final outcome = await nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': eventId, 'kind': 5},
          ],
          eventId: eventId,
          timeout: const Duration(milliseconds: 250),
        );
        await slowAdd;

        expect(outcome.acceptedBy, equals([fastUrl]));
        expect(
          outcome.unreachableTargets,
          equals([slowUrl]),
          reason:
              'the fan-out waited out this relay and spent its whole budget '
              'on it, so it was attempted — deciding that from the lagging '
              'status field instead would drop it from the denominator',
        );
        expect(outcome.targetCount, equals(2));
        expect(
          outcome.acceptedByAll,
          isFalse,
          reason:
              'reporting a publish as accepted by all while one relay was '
              'attempted and stayed silent is the exact signal this outcome '
              'exists to prevent',
        );
      },
    );
  });
}
