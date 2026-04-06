// ABOUTME: Tests for Nostr._ensurePublicKey() lazy-refresh guard.
// ABOUTME: Verifies that event-sending methods refresh the cached public key
// ABOUTME: when it is empty, and throw StateError when the signer has no key.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

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

void main() {
  group('Nostr _ensurePublicKey guard', () {
    const testPrivateKey =
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
    const testEventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    Relay dummyRelay(String url) => RelayBase(url, RelayStatus(url));

    group('sendLike', () {
      test('succeeds when publicKey is already cached', () async {
        final signer = LocalNostrSigner(testPrivateKey);
        final nostr = Nostr(signer, [], dummyRelay);
        await nostr.refreshPublicKey();

        // sendLike creates the Event without error (no relays → returns null)
        final result = await nostr.sendLike(testEventId);
        // null because no relays are connected, but no ArgumentError thrown
        expect(result, isNull);
      });

      test('lazily refreshes publicKey when cache is empty', () async {
        final signer = LocalNostrSigner(testPrivateKey);
        final nostr = Nostr(signer, [], dummyRelay);
        // Do NOT call refreshPublicKey — cache is empty ''

        expect(nostr.publicKey, isEmpty);

        // sendLike should lazy-refresh and NOT throw ArgumentError
        final result = await nostr.sendLike(testEventId);
        expect(result, isNull); // null because no relays
        expect(nostr.publicKey, isNotEmpty);
      });

      test('throws StateError when signer returns null', () async {
        final signer = _NullKeySigner();
        final nostr = Nostr(signer, [], dummyRelay);

        await expectLater(
          nostr.sendLike(testEventId),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('deleteEvent', () {
      test('lazily refreshes publicKey when cache is empty', () async {
        final signer = LocalNostrSigner(testPrivateKey);
        final nostr = Nostr(signer, [], dummyRelay);

        expect(nostr.publicKey, isEmpty);

        final result = await nostr.deleteEvent(testEventId);
        expect(result, isNull);
        expect(nostr.publicKey, isNotEmpty);
      });

      test('throws StateError when signer returns null', () async {
        final signer = _NullKeySigner();
        final nostr = Nostr(signer, [], dummyRelay);

        await expectLater(
          nostr.deleteEvent(testEventId),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('deleteEvents', () {
      test('lazily refreshes publicKey when cache is empty', () async {
        final signer = LocalNostrSigner(testPrivateKey);
        final nostr = Nostr(signer, [], dummyRelay);

        expect(nostr.publicKey, isEmpty);

        final result = await nostr.deleteEvents([testEventId]);
        expect(result, isNull);
        expect(nostr.publicKey, isNotEmpty);
      });

      test('throws StateError when signer returns null', () async {
        final signer = _NullKeySigner();
        final nostr = Nostr(signer, [], dummyRelay);

        await expectLater(
          nostr.deleteEvents([testEventId]),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('sendRepost', () {
      test('lazily refreshes publicKey when cache is empty', () async {
        final signer = LocalNostrSigner(testPrivateKey);
        final nostr = Nostr(signer, [], dummyRelay);

        expect(nostr.publicKey, isEmpty);

        final result = await nostr.sendRepost(testEventId);
        expect(result, isNull);
        expect(nostr.publicKey, isNotEmpty);
      });

      test('throws StateError when signer returns null', () async {
        final signer = _NullKeySigner();
        final nostr = Nostr(signer, [], dummyRelay);

        await expectLater(
          nostr.sendRepost(testEventId),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('sendContactList', () {
      test('lazily refreshes publicKey when cache is empty', () async {
        final signer = LocalNostrSigner(testPrivateKey);
        final nostr = Nostr(signer, [], dummyRelay);

        expect(nostr.publicKey, isEmpty);

        final result = await nostr.sendContactList(ContactList(), '');
        expect(result, isNull);
        expect(nostr.publicKey, isNotEmpty);
      });

      test('throws StateError when signer returns null', () async {
        final signer = _NullKeySigner();
        final nostr = Nostr(signer, [], dummyRelay);

        await expectLater(
          nostr.sendContactList(ContactList(), ''),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
