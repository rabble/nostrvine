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
  }) async {
    sentMessages.add(message);

    if (!_didMutate) {
      _didMutate = true;
      await onFirstSend();
    }

    return true;
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
  });
}
