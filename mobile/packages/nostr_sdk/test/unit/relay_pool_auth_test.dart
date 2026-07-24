// ABOUTME: Regression tests for RelayPool AUTH branch empty-pubkey race.
// ABOUTME: Ensures NIP-42 AUTH challenges do not crash when the cached
// ABOUTME: public key is empty (post-signOut, mid-init, account switch).

import 'dart:async';

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

  /// When true, [send] records the frame but reports transport failure, so the
  /// post-auth resend path (`onRelayUnavailable`) can be exercised.
  bool failSends = false;

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
    sentMessages.add(message);
    return !failSends;
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
  const testPrivateKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  const challenge =
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

  List<List<dynamic>> sentMessagesOfType(_AuthFakeRelay relay, String type) {
    return relay.sentMessages
        .where((m) => m.isNotEmpty && m.first == type)
        .toList(growable: false);
  }

  String sentAuthEventId(_AuthFakeRelay relay) {
    final authMessages = sentMessagesOfType(relay, 'AUTH');
    expect(authMessages, hasLength(1));
    final authEvent = authMessages.single[1] as Map<String, dynamic>;
    final id = authEvent['id'];
    expect(id, isA<String>());
    return id as String;
  }

  group('RelayPool AUTH branch empty-pubkey guard', () {
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
        final sentAuth = sentMessagesOfType(fakeRelay, 'AUTH');
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
      final sentAuth = sentMessagesOfType(fakeRelay, 'AUTH');
      expect(sentAuth, isEmpty);
    });

    test('marks relay alwaysAuth after AUTH challenge', () async {
      final signer = LocalNostrSigner(testPrivateKey);
      final nostr = Nostr(signer, [], dummyTempRelay);
      await nostr.refreshPublicKey();

      final fakeRelay = _AuthFakeRelay('wss://auth-fake.example');
      final added = await nostr.relayPool.add(fakeRelay);
      expect(added, isTrue);
      expect(fakeRelay.relayStatus.alwaysAuth, isFalse);

      await fakeRelay.deliver(['AUTH', challenge]);

      expect(fakeRelay.relayStatus.alwaysAuth, isTrue);
      expect(sentMessagesOfType(fakeRelay, 'AUTH'), hasLength(1));
    });
  });

  group('RelayPool auth-required publish retry', () {
    late LocalNostrSigner signer;
    late Nostr nostr;
    late _AuthFakeRelay relay;

    setUp(() async {
      signer = LocalNostrSigner(testPrivateKey);
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
      relay = _AuthFakeRelay('wss://auth-required.example');
      final added = await nostr.relayPool.add(relay);
      expect(added, isTrue);
    });

    test('republishes an awaited EVENT once after NIP-42 succeeds', () async {
      const eventId =
          '1111111111111111111111111111111111111111111111111111111111111111';
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        eventKind: EventKind.giftWrap,
        targetRelays: [relay.url],
        timeout: const Duration(seconds: 1),
      );

      expect(sentMessagesOfType(relay, 'EVENT'), hasLength(1));

      await relay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);
      var completed = false;
      unawaited(outcomeFuture.then((_) => completed = true));
      await Future<void>.delayed(Duration.zero);
      expect(
        completed,
        isFalse,
        reason: 'auth-required rejection should wait for AUTH retry',
      );

      await relay.deliver(['AUTH', challenge]);
      final authEventId = sentAuthEventId(relay);
      await relay.deliver(['OK', authEventId, true, '']);

      expect(
        sentMessagesOfType(relay, 'EVENT'),
        hasLength(2),
        reason: 'the original EVENT should be retried once after AUTH',
      );

      await relay.deliver(['OK', eventId, true, '']);
      final outcome = await outcomeFuture;

      expect(outcome.confirmed, isTrue);
      expect(outcome.acceptedBy, equals([relay.url]));
      expect(outcome.rejectedBy, isEmpty);
      expect(relay.relayStatus.alwaysAuth, isTrue);
    });

    test(
      'registers auth-required query even when trigger send fails',
      () async {
        relay.relayStatus.alwaysAuth = true;
        relay.failSends = true;
        final subscription = Subscription([
          Filter(kinds: [EventKind.textNote]).toJson(),
        ], (_) {});

        final result = await nostr.relayPool.relayDoQuery(
          relay,
          subscription,
          false,
        );

        expect(result, isTrue);
        expect(relay.checkQuery(subscription.id), isTrue);
        expect(sentMessagesOfType(relay, 'REQ'), hasLength(1));
      },
    );

    test('republishes when AUTH OK arrives before EVENT rejection', () async {
      const eventId =
          '3333333333333333333333333333333333333333333333333333333333333333';
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        eventKind: EventKind.giftWrap,
        targetRelays: [relay.url],
        timeout: const Duration(seconds: 1),
      );

      await relay.deliver(['AUTH', challenge]);
      final authEventId = sentAuthEventId(relay);
      await relay.deliver(['OK', authEventId, true, '']);
      await relay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);

      expect(sentMessagesOfType(relay, 'EVENT'), hasLength(2));

      await relay.deliver(['OK', eventId, true, '']);
      final outcome = await outcomeFuture;

      expect(outcome.confirmed, isTrue);
      expect(outcome.acceptedBy, equals([relay.url]));
    });

    test('does not loop when the relay keeps rejecting after AUTH', () async {
      const eventId =
          '2222222222222222222222222222222222222222222222222222222222222222';
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        eventKind: EventKind.giftWrap,
        targetRelays: [relay.url],
        timeout: const Duration(seconds: 1),
      );

      await relay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);
      await relay.deliver(['AUTH', challenge]);
      final authEventId = sentAuthEventId(relay);
      await relay.deliver(['OK', authEventId, true, '']);
      // A second auth-required after AUTH would re-trigger a retry if the
      // dedup marker were missing; the tracked entry must suppress it. Using
      // an auth-required reason here (not "restricted") isolates the dedup
      // guard as the sole reason the second republish does not happen.
      await relay.deliver(['OK', eventId, false, 'auth-required: still no']);

      final outcome = await outcomeFuture;

      expect(outcome.failed, isTrue);
      expect(outcome.acceptedBy, isEmpty);
      expect(
        outcome.rejectedBy,
        equals({relay.url: 'auth-required: still no'}),
      );
      expect(
        sentMessagesOfType(relay, 'EVENT'),
        hasLength(2),
        reason: 'the dedup marker must prevent a second post-auth republish',
      );
    });

    test('fails fast on restricted rejection with no AUTH offered', () async {
      const eventId =
          '4444444444444444444444444444444444444444444444444444444444444444';
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        eventKind: EventKind.giftWrap,
        targetRelays: [relay.url],
        timeout: const Duration(seconds: 1),
      );

      // The relay never sends an AUTH challenge (alwaysAuth stays false), so a
      // bare "restricted" is a permanent members-only rejection, not NIP-42.
      await relay.deliver([
        'OK',
        eventId,
        false,
        'restricted: not on allow list',
      ]);

      final outcome = await outcomeFuture;

      expect(outcome.failed, isTrue);
      expect(
        outcome.rejectedBy,
        equals({relay.url: 'restricted: not on allow list'}),
      );
      expect(
        sentMessagesOfType(relay, 'EVENT'),
        hasLength(1),
        reason: 'a members-only relay that never offers AUTH must not retry',
      );
    });

    test('rejects the publish when the relay AUTH fails', () async {
      const eventId =
          '5555555555555555555555555555555555555555555555555555555555555555';
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        eventKind: EventKind.giftWrap,
        targetRelays: [relay.url],
        timeout: const Duration(seconds: 1),
      );

      await relay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);
      await relay.deliver(['AUTH', challenge]);
      final authEventId = sentAuthEventId(relay);
      await relay.deliver([
        'OK',
        authEventId,
        false,
        'auth failed: bad signature',
      ]);

      final outcome = await outcomeFuture;

      expect(outcome.failed, isTrue);
      expect(
        outcome.rejectedBy,
        equals({relay.url: 'auth failed: bad signature'}),
      );
      expect(
        sentMessagesOfType(relay, 'EVENT'),
        hasLength(1),
        reason: 'a failed AUTH must not retry the EVENT',
      );
    });

    test('reports auth-required reason when relay never challenges', () async {
      const eventId =
          '7777777777777777777777777777777777777777777777777777777777777777';
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        eventKind: EventKind.giftWrap,
        targetRelays: [relay.url],
        timeout: const Duration(milliseconds: 10),
      );

      await relay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);

      final outcome = await outcomeFuture;

      expect(outcome.failed, isTrue);
      expect(
        outcome.rejectedBy,
        equals({relay.url: 'auth-required: you must auth'}),
      );
      expect(outcome.noResponseFrom, isEmpty);
    });

    test('rejects with stored reason when AUTH cannot be signed', () async {
      const eventId =
          '8888888888888888888888888888888888888888888888888888888888888888';
      final unauthenticatedNostr = Nostr(
        _NullKeySigner(),
        [],
        (url) => RelayBase(url, RelayStatus(url)),
      );
      final unauthenticatedRelay = _AuthFakeRelay(
        'wss://auth-required-no-key.example',
      );
      final added = await unauthenticatedNostr.relayPool.add(
        unauthenticatedRelay,
      );
      expect(added, isTrue);
      final outcomeFuture = unauthenticatedNostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        eventKind: EventKind.giftWrap,
        targetRelays: [unauthenticatedRelay.url],
        timeout: const Duration(seconds: 1),
      );

      await unauthenticatedRelay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);
      await unauthenticatedRelay.deliver(['AUTH', challenge]);

      final outcome = await outcomeFuture;

      expect(outcome.failed, isTrue);
      expect(
        outcome.rejectedBy,
        equals({unauthenticatedRelay.url: 'auth-required: you must auth'}),
      );
      expect(sentMessagesOfType(unauthenticatedRelay, 'AUTH'), isEmpty);
    });

    test(
      'marks the relay unavailable when the post-auth resend fails',
      () async {
        const eventId =
            '6666666666666666666666666666666666666666666666666666666666666666';
        final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': eventId, 'kind': EventKind.giftWrap},
          ],
          eventId: eventId,
          eventKind: EventKind.giftWrap,
          targetRelays: [relay.url],
          timeout: const Duration(seconds: 1),
        );

        await relay.deliver([
          'OK',
          eventId,
          false,
          'auth-required: you must auth',
        ]);
        await relay.deliver(['AUTH', challenge]);
        final authEventId = sentAuthEventId(relay);
        relay.failSends = true;
        await relay.deliver(['OK', authEventId, true, '']);

        final outcome = await outcomeFuture;

        expect(outcome.failed, isTrue);
        expect(outcome.acceptedBy, isEmpty);
        expect(outcome.rejectedBy, isEmpty);
        expect(
          sentMessagesOfType(relay, 'EVENT'),
          hasLength(2),
          reason: 'the resend is attempted once before giving up',
        );
      },
    );
  });
}
