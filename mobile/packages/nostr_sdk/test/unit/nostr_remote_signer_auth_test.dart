// ABOUTME: Security tests for NostrRemoteSigner inbound sender authentication.
// ABOUTME: A kind-24133 response is acted on only if authored by the paired
// ABOUTME: remote signer and validly signed (#7339 auth_url, #7344 callbacks).

import 'dart:async';
import 'dart:convert';

import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nip46/nostr_remote_signer.dart';
import 'package:nostr_sdk/nip46/nostr_remote_signer_info.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_mode.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:test/test.dart';

void main() {
  group('NostrRemoteSigner inbound sender authentication', () {
    late String clientPriv;
    late String clientPub;
    late String bunkerPriv;
    late String bunkerPub;
    late String attackerPriv;
    late NostrRemoteSigner signer;

    setUp(() {
      clientPriv = generatePrivateKey();
      clientPub = getPublicKey(clientPriv);
      bunkerPriv = generatePrivateKey();
      bunkerPub = getPublicKey(bunkerPriv);
      attackerPriv = generatePrivateKey();

      signer = NostrRemoteSigner(
        RelayMode.baseMode,
        NostrRemoteSignerInfo(
          remoteSignerPubkey: bunkerPub,
          relays: const ['wss://relay.example.com'],
          nsec: Nip19.encodePrivateKey(clientPriv),
        ),
      );
      // The field connect() would assign; set it directly to avoid any socket.
      signer.localNostrSigner = LocalNostrSigner(clientPriv);
    });

    tearDown(() {
      signer.close();
    });

    RelayBase idleRelay() => RelayBase(
      'wss://relay.example.com',
      RelayStatus('wss://relay.example.com'),
    );

    /// Builds a genuinely signed kind-24133 event whose NIP-44 payload the
    /// client can really decrypt (author = holder of [authorPriv]).
    Future<Event> buildResponse(
      String authorPriv, {
      required Map<String, dynamic> payload,
      String? sigOverride,
    }) async {
      final ciphertext = await LocalNostrSigner(
        authorPriv,
      ).nip44Encrypt(clientPub, jsonEncode(payload));
      final event = Event(
        getPublicKey(authorPriv),
        EventKind.nostrRemoteSigning,
        [
          ['p', clientPub],
        ],
        ciphertext!,
      );
      event.sign(authorPriv);
      if (sigOverride != null) event.sig = sigOverride;
      return event;
    }

    Map<String, dynamic> authUrlPayload(String id, String url) => {
      'id': id,
      'result': 'auth_url',
      'error': url,
    };

    // An auth challenge answers a request the client already sent, so its id
    // is present in `callbacks`. Register one so these tests isolate the
    // author/signature checks rather than the id-correlation gate.
    void registerPending(String id) {
      final completer = Completer<String?>();
      completer.future.ignore();
      signer.callbacks[id] = completer;
    }

    group('auth_url challenge (#7339)', () {
      test('a stranger auth_url never reaches the launcher', () async {
        String? opened;
        signer.onAuthUrlReceived = (url) => opened = url;
        registerPending('req-1');

        final forged = await buildResponse(
          attackerPriv,
          payload: authUrlPayload('req-1', 'https://evil.example/phish'),
        );
        // Prove the forgery is real, so a green test is not a broken fixture.
        expect(forged.isValid, isTrue);
        expect(forged.isSigned, isTrue);
        expect(forged.pubkey, isNot(bunkerPub));

        await signer.onMessage(idleRelay(), [
          'EVENT',
          'sub-1',
          forged.toJson(),
        ]);

        expect(opened, isNull);
      });

      test('the paired bunker auth_url still reaches the launcher (positive '
          'control)', () async {
        String? opened;
        signer.onAuthUrlReceived = (url) => opened = url;
        registerPending('req-1');

        final legit = await buildResponse(
          bunkerPriv,
          payload: authUrlPayload('req-1', 'https://bunker.example/approve'),
        );

        await signer.onMessage(idleRelay(), ['EVENT', 'sub-1', legit.toJson()]);

        expect(opened, 'https://bunker.example/approve');
      });

      test('a bunker auth_url with an invalid signature is dropped', () async {
        String? opened;
        signer.onAuthUrlReceived = (url) => opened = url;
        registerPending('req-1');

        final tampered = await buildResponse(
          bunkerPriv,
          payload: authUrlPayload('req-1', 'https://bunker.example/approve'),
          sigOverride: '',
        );
        expect(tampered.isSigned, isFalse);

        await signer.onMessage(idleRelay(), [
          'EVENT',
          'sub-1',
          tampered.toJson(),
        ]);

        expect(opened, isNull);
      });

      test('an auth_url for an uncorrelated request id is ignored', () async {
        String? opened;
        signer.onAuthUrlReceived = (url) => opened = url;
        // No registerPending: nothing is waiting on this id.

        final legit = await buildResponse(
          bunkerPriv,
          payload: authUrlPayload('never-requested', 'https://bunker/approve'),
        );

        await signer.onMessage(idleRelay(), ['EVENT', 'sub-1', legit.toJson()]);

        expect(opened, isNull);
      });

      test('a stranger event is dropped without throwing', () async {
        registerPending('req-1');
        final forged = await buildResponse(
          attackerPriv,
          payload: authUrlPayload('req-1', 'https://evil.example/phish'),
        );

        await expectLater(
          signer.onMessage(idleRelay(), ['EVENT', 'sub-1', forged.toJson()]),
          completes,
        );
      });
    });

    group('subscription filter (defense in depth)', () {
      test('constrains authors to the paired remote signer', () async {
        final query = await signer.genQueryMsg();
        expect(query, isNotNull);
        final filter = query![2] as Map<String, dynamic>;
        expect(filter['authors'], [bunkerPub]);
        expect(filter['#p'], [clientPub]);
        expect(filter['kinds'], [EventKind.nostrRemoteSigning]);
      });

      test('omits authors when the remote signer pubkey is unknown', () async {
        final unpaired = NostrRemoteSigner(
          RelayMode.baseMode,
          NostrRemoteSignerInfo(
            remoteSignerPubkey: '',
            relays: const ['wss://relay.example.com'],
            nsec: Nip19.encodePrivateKey(clientPriv),
          ),
        );
        unpaired.localNostrSigner = LocalNostrSigner(clientPriv);
        addTearDown(unpaired.close);

        final query = await unpaired.genQueryMsg();
        final filter = query![2] as Map<String, dynamic>;
        expect(filter.containsKey('authors'), isFalse);
      });
    });

    group('response correlation (#7344)', () {
      test(
        'a stranger cannot complete a pending request via callbacks',
        () async {
          final completer = Completer<String?>();
          signer.callbacks['req-2'] = completer;
          // The stranger must not complete it; tearDown's close() will
          // error the still-pending completer, so swallow that.
          completer.future.ignore();

          final forged = await buildResponse(
            attackerPriv,
            payload: {'id': 'req-2', 'result': 'attacker-chosen-pubkey'},
          );

          await signer.onMessage(idleRelay(), [
            'EVENT',
            'sub-2',
            forged.toJson(),
          ]);

          expect(completer.isCompleted, isFalse);
        },
      );

      test('the paired bunker completes a pending request', () async {
        final completer = Completer<String?>();
        signer.callbacks['req-2'] = completer;

        final legit = await buildResponse(
          bunkerPriv,
          payload: {'id': 'req-2', 'result': 'the-real-pubkey'},
        );

        await signer.onMessage(idleRelay(), ['EVENT', 'sub-2', legit.toJson()]);

        expect(completer.isCompleted, isTrue);
        expect(await completer.future, 'the-real-pubkey');
      });
    });
  });
}
