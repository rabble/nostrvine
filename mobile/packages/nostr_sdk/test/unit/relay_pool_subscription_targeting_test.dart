// ABOUTME: Pins how RelayPool.subscribe routes a REQ when tempRelays and
// ABOUTME: targetRelays are supplied, over real sockets rather than mocks.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

import '../support/fake_web_socket.dart';

/// Lets every pending microtask and short timer drain so the pool has finished
/// connecting and fanning the REQ out.
Future<void> _settle() async {
  for (var i = 0; i < 60; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

/// Subscription ids of every `REQ` frame [factory]'s sockets were asked to send.
List<String> _reqIds(FakeWebSocketChannelFactory factory) {
  return [
    for (final channel in factory.createdChannels)
      for (final message in channel.sentMessages)
        if ((jsonDecode(message as String) as List<dynamic>).first == 'REQ')
          (jsonDecode(message) as List<dynamic>)[1] as String,
  ];
}

void main() {
  group('RelayPool.subscribe relay routing', () {
    // The production shape this guards: divine's own relay plus one of the
    // four IndexerRelayConfig.safeFallbackRelays that #2931 connects so DMs
    // written to other relays stay visible.
    const pooledPrimary = 'wss://relay.divine.video';
    const pooledFallback = 'wss://relay.nos.social';
    final filters = [
      {
        'kinds': [1059],
        '#p': ['a' * 64],
      },
    ];

    late FakeWebSocketChannelFactory primaryFactory;
    late FakeWebSocketChannelFactory fallbackFactory;
    late FakeWebSocketChannelFactory tempFactory;
    late List<String> tempRelaysGenerated;
    late Nostr nostr;

    setUp(() async {
      primaryFactory = FakeWebSocketChannelFactory();
      fallbackFactory = FakeWebSocketChannelFactory();
      tempFactory = FakeWebSocketChannelFactory();
      tempRelaysGenerated = <String>[];

      nostr = Nostr(
        LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        ),
        [],
        (url) {
          tempRelaysGenerated.add(url);
          return RelayBase(url, RelayStatus(url), channelFactory: tempFactory);
        },
      );
      await nostr.refreshPublicKey();

      await nostr.relayPool.add(
        RelayBase(
          pooledPrimary,
          RelayStatus(pooledPrimary),
          channelFactory: primaryFactory,
        ),
      );
      await nostr.relayPool.add(
        RelayBase(
          pooledFallback,
          RelayStatus(pooledFallback),
          channelFactory: fallbackFactory,
        ),
      );
      await _settle();
    });

    test('untargeted subscribe reaches every pooled relay', () async {
      nostr.relayPool.subscribe(filters, (_) {}, id: 'untargeted');
      await _settle();

      expect(_reqIds(primaryFactory), contains('untargeted'));
      expect(_reqIds(fallbackFactory), contains('untargeted'));
    });

    test(
      'tempRelays ADDS the named relay and leaves the pool subscribed',
      () async {
        // The shape DmRepository.startListening uses for the live gift-wrap
        // read once the user advertises a kind-10050 (#4974, #7320).
        nostr.relayPool.subscribe(
          filters,
          (_) {},
          id: 'temp-only',
          tempRelays: const ['wss://inbox.example'],
        );
        await _settle();

        expect(_reqIds(primaryFactory), contains('temp-only'));
        expect(_reqIds(fallbackFactory), contains('temp-only'));
        expect(tempRelaysGenerated, contains('wss://inbox.example/'));
        expect(_reqIds(tempFactory), contains('temp-only'));
      },
    );

    test('targetRelays narrows the pool away, even when it names a pooled '
        'relay verbatim', () async {
      // Two separate reasons the pooled relays drop out, and the test asserts
      // the outcome rather than either mechanism:
      //
      //   1. `targetRelays` is a filter over the pool, not an addition —
      //      subscribe() skips every pooled relay the list does not name.
      //   2. The two sides are not even comparable. Pool keys come from
      //      `normalizeRelayUrl` (nostr_client), which STRIPS a trailing
      //      slash; `targetRelays` is run through `RelayAddrUtil.handle`,
      //      which ADDS one. So `targetRelays.contains(relayAddr)` is false
      //      for every pooled relay, and naming one verbatim does not help.
      //
      // Reason 2 is why the named relay below is re-dialed as a *temp* relay
      // instead of reusing the pooled socket. It is tracked separately; this
      // test exists so the DM live subscription can never quietly regress to
      // passing `targetRelays` again.
      nostr.relayPool.subscribe(
        filters,
        (_) {},
        id: 'targeted',
        tempRelays: const [pooledPrimary],
        targetRelays: const [pooledPrimary],
      );
      await _settle();

      expect(_reqIds(primaryFactory), isNot(contains('targeted')));
      expect(_reqIds(fallbackFactory), isNot(contains('targeted')));
      expect(tempRelaysGenerated, contains('$pooledPrimary/'));
    });
  });
}
