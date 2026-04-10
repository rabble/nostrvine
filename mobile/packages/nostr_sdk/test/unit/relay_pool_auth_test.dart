// ABOUTME: Regression tests for RelayPool AUTH branch empty-pubkey race.
// ABOUTME: Ensures NIP-42 AUTH challenges do not crash when the cached
// ABOUTME: public key is empty (post-signOut, mid-init, account switch).

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// A signer that returns null for getPublicKey (simulates unconfigured signer).
class _NullKeySigner implements NostrSigner {
  @override
  Future<String?> getPublicKey() async => null;

  @override
  Future<Event?> signEvent(Event event) async => null;

  @override
  Future<Map?> getRelays() async => null;

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async => null;

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async => null;

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async => null;

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async => null;

  @override
  void close() {}
}

/// A fake relay that records sent messages and allows tests to drive
/// `onMessage` directly. No real network I/O.
class _AuthFakeRelay extends Relay {
  _AuthFakeRelay(String url) : super(url, RelayStatus(url));

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
    return true;
  }

  /// Drive an inbound message through the handler registered by RelayPool,
  /// awaiting the async result so exceptions surface to the test.
  Future<void> deliver(List<dynamic> json) async {
    final handler = onMessage;
    expect(handler, isNotNull, reason: 'RelayPool did not wire onMessage');
    final dynamic result = handler!(this, json);
    if (result is Future) {
      await result;
    }
  }
}

void main() {
  group('RelayPool AUTH branch empty-pubkey guard', () {
    const testPrivateKey =
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
    const challenge = 'abcdef0123456789abcdef0123456789';

    Relay dummyTempRelay(String url) => RelayBase(url, RelayStatus(url));

    test(
      'lazily refreshes publicKey from signer when cache is empty',
      () async {
        final signer = LocalNostrSigner(testPrivateKey);
        final nostr = Nostr(signer, [], dummyTempRelay);
        // Deliberately skip refreshPublicKey() — simulates the race window
        // where the relay delivers an AUTH challenge before init populated
        // the cache (post-signOut, mid-init, account switch).
        expect(nostr.publicKey, isEmpty);

        final fakeRelay = _AuthFakeRelay('wss://auth-fake.example');
        final added = await nostr.relayPool.add(fakeRelay);
        expect(added, isTrue);

        // BEFORE FIX: Event constructor throws ArgumentError because
        // Nostr.publicKey is '' and keyIsValid('') returns false. The
        // async _onEvent returns a rejected Future which relay_base
        // discards (fire-and-forget), so in production it escapes to
        // runZonedGuarded. In this test we await the handler result and
        // the ArgumentError propagates — failing the test.
        // AFTER FIX: ensurePublicKey refreshes the cache and the AUTH
        // response is signed and sent.
        await fakeRelay.deliver(['AUTH', challenge]);

        expect(
          nostr.publicKey,
          isNotEmpty,
          reason: 'AUTH handler should refresh the cached pubkey from signer',
        );
        final sentAuth = fakeRelay.sentMessages
            .where((m) => m.isNotEmpty && m.first == 'AUTH')
            .toList();
        expect(
          sentAuth,
          hasLength(1),
          reason: 'AUTH handler should send one AUTH response',
        );
      },
    );

    test('does not leak async error when signer has no key', () async {
      final signer = _NullKeySigner();
      final nostr = Nostr(signer, [], dummyTempRelay);

      final fakeRelay = _AuthFakeRelay('wss://auth-fake.example');
      final added = await nostr.relayPool.add(fakeRelay);
      expect(added, isTrue);

      // BEFORE FIX: Event() throws ArgumentError — surfaces as unhandled
      // async error. AFTER FIX: the AUTH branch catches StateError from
      // ensurePublicKey and logs, returning normally.
      await expectLater(fakeRelay.deliver(['AUTH', challenge]), completes);

      // No AUTH response should have been produced since no key is
      // available to sign one.
      final sentAuth = fakeRelay.sentMessages
          .where((m) => m.isNotEmpty && m.first == 'AUTH')
          .toList();
      expect(sentAuth, isEmpty);
    });
  });
}
