// ABOUTME: Regression tests for repairs that race the pool's teardown and used
// ABOUTME: to leave an orphaned socket plus heartbeat timer behind (#7367).

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

import '../support/fake_web_socket.dart';

void main() {
  group('RelayPool teardown race', () {
    const relayUrl = 'wss://relay.divine.video';
    const otherUrl = 'wss://other.divine.video';
    const probe = Duration(milliseconds: 20);
    // Comfortably past [probe] plus the reconnect's own async hops.
    const afterProbe = Duration(milliseconds: 80);

    late Nostr nostr;
    late FakeWebSocketChannelFactory factory;
    late FakeWebSocketChannelFactory tempFactory;

    Future<void> setUpPool({Object? initialConnectError}) async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      tempFactory = FakeWebSocketChannelFactory();
      nostr = Nostr(
        signer,
        [],
        (url) => RelayBase(url, RelayStatus(url), channelFactory: tempFactory),
      );
      await nostr.refreshPublicKey();
      factory = FakeWebSocketChannelFactory(readyError: initialConnectError);
      await nostr.relayPool.add(
        RelayBase(relayUrl, RelayStatus(relayUrl), channelFactory: factory),
      );
      nostr.relayPool.subscriptionSilenceProbe = probe;
    }

    String subscribeToFeed() => nostr.subscribe([
      {
        'kinds': [34236],
      },
    ], (_) {});

    test('a probe armed before teardown is disarmed and opens no '
        'socket', () async {
      await setUpPool();
      final subId = subscribeToFeed();
      await Future<void>.delayed(Duration.zero);
      expect(nostr.relayPool.armedSilenceProbeSubscriptionIds, [subId]);

      // The owner's dispose() has begun. removeAll() is several awaits away,
      // and the probe would otherwise fire inside that window.
      nostr.relayPool.beginClose();

      expect(nostr.relayPool.isClosed, isTrue);
      expect(nostr.relayPool.armedSilenceProbeSubscriptionIds, isEmpty);

      await Future<void>.delayed(afterProbe);
      expect(
        factory.createdChannels,
        hasLength(1),
        reason:
            'a socket opened inside the teardown window outlives the '
            'removeAll() that was supposed to close it',
      );
    });

    // The probes are the repair trigger that `beginClose` disarms outright,
    // so nothing timer-driven survives into the window. This one does: it is
    // reached straight off `unsubscribe`, which is what the first await of
    // `NostrClient.dispose()` — `closeAllSubscriptions()` — spends its time
    // doing. Without the flag the pool force-reconnects the relay it is in
    // the middle of tearing down.
    test('closing subscriptions inside the window repairs nothing', () async {
      await setUpPool();
      // The relay answered nothing since the REQ, which is what marks it as a
      // half-open zombie worth force-cycling.
      nostr.relayPool.minSubscriptionAgeBeforeRepair = Duration.zero;
      final subId = subscribeToFeed();
      await Future<void>.delayed(Duration.zero);

      nostr.relayPool.beginClose();
      nostr.unsubscribe(subId);
      await Future<void>.delayed(afterProbe);

      expect(
        factory.createdChannels,
        hasLength(1),
        reason:
            'the repair would force-reconnect a relay that removeAll() is '
            'about to dispose, stranding the fresh socket and its heartbeat',
      );
    });

    // A query that lands during teardown routes through a temp relay, which
    // both dials the address and arms the pool-wide idle sweep.
    test('a temp relay minted inside the window connects nothing', () async {
      await setUpPool();
      nostr.relayPool.beginClose();

      nostr.relayPool.checkAndGenTempRelay(otherUrl);
      await Future<void>.delayed(afterProbe);

      expect(tempFactory.createdChannels, isEmpty);
      expect(
        nostr.relayPool.hasTempRelaySweepScheduled,
        isFalse,
        reason: 'a periodic sweep armed here outlives the pool that armed it',
      );
    });

    test('teardown leaves no live socket behind', () async {
      await setUpPool();
      subscribeToFeed();
      await Future<void>.delayed(Duration.zero);

      nostr.relayPool.beginClose();
      nostr.relayPool.removeAll();
      await Future<void>.delayed(afterProbe);

      expect(factory.createdChannels.single.isClosed, isTrue);
    });

    test('a subscription issued after teardown began arms no probe', () async {
      await setUpPool();
      nostr.relayPool.beginClose();

      subscribeToFeed();
      await Future<void>.delayed(Duration.zero);

      expect(nostr.relayPool.armedSilenceProbeSubscriptionIds, isEmpty);
      await Future<void>.delayed(afterProbe);
      expect(factory.createdChannels, hasLength(1));
    });

    test('reconnect() after teardown began opens no socket', () async {
      // The relay never connected, so a reconnect would open a fresh socket.
      await setUpPool(initialConnectError: Exception('connect failed'));
      expect(factory.createdChannels, hasLength(1));
      factory.readyError = null;

      nostr.relayPool.beginClose();
      nostr.relayPool.reconnect();
      await Future<void>.delayed(afterProbe);

      expect(factory.createdChannels, hasLength(1));
    });

    // The pool drops a relay from every map at the moment it disposes it, so
    // this is the belt to the pool flag's braces: a caller that still holds a
    // `Relay` reference — `checkAndGenTempRelay` and `getRelay` both hand one
    // out — must not be able to bring a dead relay back to life.
    test('a disposed relay opens no further socket', () async {
      final relayFactory = FakeWebSocketChannelFactory();
      final relay = RelayBase(
        relayUrl,
        RelayStatus(relayUrl),
        channelFactory: relayFactory,
      );
      expect(await relay.connect(), isTrue);
      expect(relayFactory.createdChannels, hasLength(1));

      relay.dispose();

      // forceReconnect falls through to connect() once dispose has dropped
      // the connection manager, and connect() used to create a brand new one.
      expect(await relay.forceReconnect(), isFalse);
      expect(await relay.connect(), isFalse);
      expect(
        relayFactory.createdChannels,
        hasLength(1),
        reason:
            'a socket opened by a disposed relay has no owner left to '
            'close it, and neither has the heartbeat timer it arms',
      );
    });

    test('Nostr.close() leaves the pool closed to new connections', () async {
      await setUpPool();

      nostr.close();

      expect(nostr.relayPool.isClosed, isTrue);

      final lateFactory = FakeWebSocketChannelFactory();
      final added = await nostr.relayPool.add(
        RelayBase(otherUrl, RelayStatus(otherUrl), channelFactory: lateFactory),
      );

      expect(added, isFalse);
      expect(
        lateFactory.createdChannels,
        isEmpty,
        reason:
            'close() is what marks the pool terminally closed, so a '
            'relay added afterwards must not open a socket',
      );
    });

    test('add() after teardown began does not connect the relay', () async {
      await setUpPool();
      nostr.relayPool.beginClose();

      final lateFactory = FakeWebSocketChannelFactory();
      final added = await nostr.relayPool.add(
        RelayBase(otherUrl, RelayStatus(otherUrl), channelFactory: lateFactory),
      );

      expect(added, isFalse);
      expect(lateFactory.createdChannels, isEmpty);
    });
  });
}
