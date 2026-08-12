// ABOUTME: Regression tests for zombie-socket remediation driven by a live
// ABOUTME: subscription its caller tore down without ever being served.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

import '../support/fake_web_socket.dart';

List<List<dynamic>> _reqFrames(FakeWebSocketChannel channel) => channel
    .sentMessages
    .map((m) => jsonDecode(m as String) as List<dynamic>)
    .where((m) => m.first == 'REQ')
    .toList();

void main() {
  group('RelayPool zombie-socket remediation on subscription teardown', () {
    const relayUrl = 'wss://relay.divine.video';
    late Nostr nostr;
    late FakeWebSocketChannelFactory factory;

    setUp(() async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
      factory = FakeWebSocketChannelFactory();
      await nostr.relayPool.add(
        RelayBase(relayUrl, RelayStatus(relayUrl), channelFactory: factory),
      );
      // These tests tear the subscription down immediately; the age floor
      // that protects navigation-speed teardowns has its own test below.
      nostr.relayPool.minSubscriptionAgeBeforeRepair = Duration.zero;
    });

    String subscribeToFeed() => nostr.subscribe([
      {
        'kinds': [34236],
      },
    ], (_) {});

    test('a relay that swallows the REQ and never sends a frame is '
        'force-reconnected when the caller gives up', () async {
      expect(factory.createdChannels, hasLength(1));
      final zombieChannel = factory.createdChannels.single;

      final subId = subscribeToFeed();
      await Future<void>.delayed(Duration.zero);
      expect(_reqFrames(zombieChannel), hasLength(1));

      // The feed-load deadline expired with no EVENT and no EOSE.
      nostr.unsubscribe(subId);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(2),
        reason: 'a socket that swallowed the REQ must be cycled',
      );
    });

    test('a relay that answered the subscription is left alone', () async {
      final channel = factory.createdChannels.single;

      final subId = subscribeToFeed();
      await Future<void>.delayed(Duration.zero);
      channel.simulateMessage(jsonEncode(['EOSE', subId]));
      await Future<void>.delayed(Duration.zero);

      nostr.unsubscribe(subId);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(1),
        reason: 'an EOSE-ing relay is healthy and must not be cycled',
      );
    });

    test('a relay that stays inbound-active is left alone — silence '
        'discriminates zombie from slow', () async {
      final channel = factory.createdChannels.single;

      final subId = subscribeToFeed();
      await Future<void>.delayed(Duration.zero);
      // Nothing for our REQ, but the connection is demonstrably alive.
      channel.simulateMessage(jsonEncode(['NOTICE', 'busy']));
      await Future<void>.delayed(Duration.zero);

      nostr.unsubscribe(subId);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(1),
        reason: 'an inbound-active connection must not be cycled',
      );
    });

    test('a subscription dropped before the age floor is not charged against '
        'the socket', () async {
      nostr.relayPool.minSubscriptionAgeBeforeRepair = const Duration(
        minutes: 1,
      );

      final subId = subscribeToFeed();
      await Future<void>.delayed(Duration.zero);

      // The user left the screen inside the relay's round-trip time.
      nostr.unsubscribe(subId);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(1),
        reason:
            'a teardown faster than the relay could answer proves nothing '
            'about the connection',
      );
    });

    test('the reconnect re-issues the REQs the relay still holds', () async {
      final zombieChannel = factory.createdChannels.single;

      final abandoned = subscribeToFeed();
      final survivor = nostr.subscribe([
        {
          'kinds': [1],
        },
      ], (_) {});
      await Future<void>.delayed(Duration.zero);
      expect(_reqFrames(zombieChannel), hasLength(2));

      nostr.unsubscribe(abandoned);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(factory.createdChannels, hasLength(2));
      final freshChannel = factory.createdChannels.last;
      expect(
        _reqFrames(freshChannel).map((frame) => frame[1]),
        [survivor],
        reason:
            'the surviving subscription runs again on the live socket, '
            'the abandoned one does not',
      );
    });
  });
}
