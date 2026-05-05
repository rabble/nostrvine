import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/local_key_signer.dart';
import 'package:openvine/services/nostr_identity.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

class _MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _MockLocalKeySigner extends Mock implements LocalKeySigner {}

class _MockKeycastRpc extends Mock implements KeycastRpc {}

void main() {
  const testPrivateKey =
      '6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e';
  const testPublicKey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  setUpAll(() {
    registerFallbackValue(Event(testPublicKey, 0, [], ''));
    registerFallbackValue(Uint8List(0));
  });

  group(LocalNostrIdentity, () {
    late _MockSecureKeyContainer mockKeyContainer;

    setUp(() {
      mockKeyContainer = _MockSecureKeyContainer();
      when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
      when(() => mockKeyContainer.isDisposed).thenReturn(false);
    });

    test('pubkey matches key container public key', () {
      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);

      expect(identity.pubkey, equals(testPublicKey));
    });

    test('npub encodes pubkey to bech32 format', () {
      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);

      expect(identity.npub, startsWith('npub1'));
      expect(identity.npub, equals(NostrKeyUtils.encodePubKey(testPublicKey)));
    });

    test('getPublicKey returns pubkey', () async {
      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);

      expect(await identity.getPublicKey(), equals(testPublicKey));
    });

    test('signEvent signs via LocalKeySigner', () async {
      when(() => mockKeyContainer.withPrivateKey<Event>(any())).thenAnswer((
        invocation,
      ) {
        final callback =
            invocation.positionalArguments[0] as Event Function(String);
        return callback(testPrivateKey);
      });

      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);
      final event = Event(testPublicKey, EventKind.textNote, [], 'test');

      final signed = await identity.signEvent(event);

      expect(signed, isNotNull);
      expect(signed!.sig, isNotEmpty);
    });

    test('signCanonicalPayload signs locally', () async {
      when(() => mockKeyContainer.withPrivateKey<String>(any())).thenAnswer((
        invocation,
      ) {
        final callback =
            invocation.positionalArguments[0] as String Function(String);
        return callback(testPrivateKey);
      });

      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);
      final payload = Uint8List.fromList([1, 2, 3]);

      final signature = await identity.signCanonicalPayload(payload);

      expect(signature, isNotNull);
      expect(signature, isNotEmpty);
    });
  });

  group(KeycastNostrIdentity, () {
    late _MockNostrSigner mockRpc;

    setUp(() {
      mockRpc = _MockNostrSigner();
    });

    test('pubkey is set at construction', () {
      final identity = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockRpc,
      );

      expect(identity.pubkey, equals(testPublicKey));
    });

    test('signEvent delegates to RPC when no local signer', () async {
      final event = Event(testPublicKey, EventKind.textNote, [], 'test');
      when(() => mockRpc.signEvent(any())).thenAnswer((_) async => event);

      final identity = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockRpc,
      );

      final signed = await identity.signEvent(event);

      expect(signed, equals(event));
      verify(() => mockRpc.signEvent(any())).called(1);
    });

    test('signEvent prefers local signer when available', () async {
      final event = Event(testPublicKey, EventKind.textNote, [], 'test');
      final mockLocal = _MockLocalKeySigner();
      when(() => mockLocal.signEvent(any())).thenAnswer((_) async => event);

      final identity = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockRpc,
        localSigner: mockLocal,
      );

      final signed = await identity.signEvent(event);

      expect(signed, equals(event));
      verify(() => mockLocal.signEvent(any())).called(1);
      verifyNever(() => mockRpc.signEvent(any()));
    });

    test(
      'signEvent falls back to RPC when local signer returns null',
      () async {
        final event = Event(testPublicKey, EventKind.textNote, [], 'test');
        final mockLocal = _MockLocalKeySigner();
        when(() => mockLocal.signEvent(any())).thenAnswer((_) async => null);
        when(() => mockRpc.signEvent(any())).thenAnswer((_) async => event);

        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockRpc,
          localSigner: mockLocal,
        );

        final signed = await identity.signEvent(event);

        expect(signed, equals(event));
        verify(() => mockLocal.signEvent(any())).called(1);
        verify(() => mockRpc.signEvent(any())).called(1);
      },
    );

    test(
      'signCanonicalPayload returns null when no local signer and rpcSigner '
      'is a generic NostrSigner (not KeycastRpc)',
      () async {
        // Generic NostrSigner doesn't implement signCanonicalPayload, so the
        // identity must short-circuit to null rather than try to call it.
        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockRpc,
        );

        final result = await identity.signCanonicalPayload(
          Uint8List.fromList([1, 2, 3]),
        );

        expect(result, isNull);
      },
    );

    test(
      'signCanonicalPayload falls back to KeycastRpc when no local signer',
      () async {
        // OAuth-only path: no local key, RPC backend supports sign_canonical.
        final mockKeycastRpc = _MockKeycastRpc();
        when(
          () => mockKeycastRpc.signCanonicalPayload(any()),
        ).thenAnswer((_) async => 'remote_sig_hex');

        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockKeycastRpc,
        );

        final result = await identity.signCanonicalPayload(
          Uint8List.fromList([1, 2, 3]),
        );

        expect(result, equals('remote_sig_hex'));
        verify(() => mockKeycastRpc.signCanonicalPayload(any())).called(1);
      },
    );

    test(
      'signCanonicalPayload returns null when KeycastRpc has no backend '
      'support yet (graceful skip)',
      () async {
        // Backend doesn't expose sign_canonical → KeycastRpc returns null →
        // identity returns null → caller skips creator-binding. Publish is
        // not blocked.
        final mockKeycastRpc = _MockKeycastRpc();
        when(
          () => mockKeycastRpc.signCanonicalPayload(any()),
        ).thenAnswer((_) async => null);

        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockKeycastRpc,
        );

        final result = await identity.signCanonicalPayload(
          Uint8List.fromList([1, 2, 3]),
        );

        expect(result, isNull);
      },
    );

    test(
      'signCanonicalPayload prefers local signer when available',
      () async {
        final mockLocal = _MockLocalKeySigner();
        final mockKeycastRpc = _MockKeycastRpc();
        when(
          () => mockLocal.signCanonicalPayload(any()),
        ).thenAnswer((_) async => 'local_sig_hex');

        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockKeycastRpc,
          localSigner: mockLocal,
        );

        final result = await identity.signCanonicalPayload(
          Uint8List.fromList([1, 2, 3]),
        );

        expect(result, equals('local_sig_hex'));
        verify(() => mockLocal.signCanonicalPayload(any())).called(1);
        // Local short-circuit means RPC must NOT be called for the perf
        // optimisation to hold.
        verifyNever(() => mockKeycastRpc.signCanonicalPayload(any()));
      },
    );

    test(
      'signCanonicalPayload falls back to KeycastRpc when local signer '
      'returns null',
      () async {
        final mockLocal = _MockLocalKeySigner();
        final mockKeycastRpc = _MockKeycastRpc();
        when(
          () => mockLocal.signCanonicalPayload(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockKeycastRpc.signCanonicalPayload(any()),
        ).thenAnswer((_) async => 'remote_sig_hex');

        final identity = KeycastNostrIdentity(
          pubkey: testPublicKey,
          rpcSigner: mockKeycastRpc,
          localSigner: mockLocal,
        );

        final result = await identity.signCanonicalPayload(
          Uint8List.fromList([1, 2, 3]),
        );

        expect(result, equals('remote_sig_hex'));
        verify(() => mockLocal.signCanonicalPayload(any())).called(1);
        verify(() => mockKeycastRpc.signCanonicalPayload(any())).called(1);
      },
    );
  });

  group(BunkerNostrIdentity, () {
    late _MockNostrSigner mockRemote;

    setUp(() {
      mockRemote = _MockNostrSigner();
    });

    test('pubkey is set at construction', () {
      final identity = BunkerNostrIdentity(
        pubkey: testPublicKey,
        remoteSigner: mockRemote,
      );

      expect(identity.pubkey, equals(testPublicKey));
    });

    test('signEvent delegates to remote signer', () async {
      final event = Event(testPublicKey, EventKind.textNote, [], 'test');
      when(() => mockRemote.signEvent(any())).thenAnswer((_) async => event);

      final identity = BunkerNostrIdentity(
        pubkey: testPublicKey,
        remoteSigner: mockRemote,
      );

      final signed = await identity.signEvent(event);

      expect(signed, equals(event));
      verify(() => mockRemote.signEvent(any())).called(1);
    });

    test('signCanonicalPayload returns null', () async {
      final identity = BunkerNostrIdentity(
        pubkey: testPublicKey,
        remoteSigner: mockRemote,
      );

      final result = await identity.signCanonicalPayload(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(result, isNull);
    });
  });

  group(AmberNostrIdentity, () {
    late _MockNostrSigner mockAmber;

    setUp(() {
      mockAmber = _MockNostrSigner();
    });

    test('pubkey is set at construction', () {
      final identity = AmberNostrIdentity(
        pubkey: testPublicKey,
        amberSigner: mockAmber,
      );

      expect(identity.pubkey, equals(testPublicKey));
    });

    test('signEvent delegates to amber signer', () async {
      final event = Event(testPublicKey, EventKind.textNote, [], 'test');
      when(() => mockAmber.signEvent(any())).thenAnswer((_) async => event);

      final identity = AmberNostrIdentity(
        pubkey: testPublicKey,
        amberSigner: mockAmber,
      );

      final signed = await identity.signEvent(event);

      expect(signed, equals(event));
      verify(() => mockAmber.signEvent(any())).called(1);
    });

    test('signCanonicalPayload returns null', () async {
      final identity = AmberNostrIdentity(
        pubkey: testPublicKey,
        amberSigner: mockAmber,
      );

      final result = await identity.signCanonicalPayload(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(result, isNull);
    });
  });

  group(Nip07NostrIdentity, () {
    late _MockNostrSigner mockNip07Signer;

    setUp(() {
      mockNip07Signer = _MockNostrSigner();
    });

    test('pubkey is set at construction', () {
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      expect(identity.pubkey, equals(testPublicKey));
    });

    test('signEvent delegates to nip07 signer', () async {
      final event = Event(testPublicKey, EventKind.textNote, [], 'test');
      when(
        () => mockNip07Signer.signEvent(any()),
      ).thenAnswer((_) async => event);

      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      final signed = await identity.signEvent(event);

      expect(signed, equals(event));
      verify(() => mockNip07Signer.signEvent(any())).called(1);
    });

    test('signCanonicalPayload returns null', () async {
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      final result = await identity.signCanonicalPayload(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(result, isNull);
    });

    test('encrypt delegates to nip07 signer', () async {
      when(
        () => mockNip07Signer.encrypt(any(), any()),
      ).thenAnswer((_) async => 'cipher');
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      final result = await identity.encrypt(testPublicKey, 'plaintext');

      expect(result, equals('cipher'));
      verify(
        () => mockNip07Signer.encrypt(testPublicKey, 'plaintext'),
      ).called(1);
    });

    test('decrypt delegates to nip07 signer', () async {
      when(
        () => mockNip07Signer.decrypt(any(), any()),
      ).thenAnswer((_) async => 'plaintext');
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      final result = await identity.decrypt(testPublicKey, 'cipher');

      expect(result, equals('plaintext'));
    });

    test('nip44Encrypt delegates to nip07 signer', () async {
      when(
        () => mockNip07Signer.nip44Encrypt(any(), any()),
      ).thenAnswer((_) async => 'nip44-cipher');
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      final result = await identity.nip44Encrypt(testPublicKey, 'plaintext');

      expect(result, equals('nip44-cipher'));
    });

    test('nip44Decrypt delegates to nip07 signer', () async {
      when(
        () => mockNip07Signer.nip44Decrypt(any(), any()),
      ).thenAnswer((_) async => 'plaintext');
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      final result = await identity.nip44Decrypt(testPublicKey, 'cipher');

      expect(result, equals('plaintext'));
    });

    test('npub encodes pubkey to bech32', () {
      final identity = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockNip07Signer,
      );

      expect(identity.npub, equals(NostrKeyUtils.encodePubKey(testPublicKey)));
    });
  });

  group('structural desync prevention', () {
    test('pubkey used in event always matches signing key '
        'because both come from the same identity instance', () async {
      // This test proves that the PRIMARY-slot desync bug (#2233) is
      // structurally impossible with NostrIdentity: the pubkey embedded
      // in the event and the key used for signing both originate from
      // the same identity instance.
      final mockKeyContainer = _MockSecureKeyContainer();
      when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
      when(() => mockKeyContainer.isDisposed).thenReturn(false);
      when(() => mockKeyContainer.withPrivateKey<Event>(any())).thenAnswer((
        invocation,
      ) {
        final callback =
            invocation.positionalArguments[0] as Event Function(String);
        return callback(testPrivateKey);
      });

      final identity = LocalNostrIdentity(keyContainer: mockKeyContainer);

      // Simulate what createAndSignEvent does: use identity.pubkey for
      // the event, then identity.signEvent to sign it.
      final event = Event(
        identity.pubkey,
        EventKind.textNote,
        [],
        'test content',
      );
      final signed = await identity.signEvent(event);

      // The signed event's pubkey matches the identity's pubkey — they
      // cannot disagree because they come from the same object.
      expect(signed, isNotNull);
      expect(signed!.pubkey, equals(identity.pubkey));
      expect(signed.isSigned, isTrue);
    });

    test('different identity types all bind pubkey at construction time', () {
      // Each variant stores pubkey as a final field — it cannot change
      // after construction, so there is no window for desync.
      final mockSigner = _MockNostrSigner();
      final mockKeyContainer = _MockSecureKeyContainer();
      when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
      when(() => mockKeyContainer.isDisposed).thenReturn(false);

      final local = LocalNostrIdentity(keyContainer: mockKeyContainer);
      final keycast = KeycastNostrIdentity(
        pubkey: testPublicKey,
        rpcSigner: mockSigner,
      );
      final bunker = BunkerNostrIdentity(
        pubkey: testPublicKey,
        remoteSigner: mockSigner,
      );
      final amber = AmberNostrIdentity(
        pubkey: testPublicKey,
        amberSigner: mockSigner,
      );
      final nip07 = Nip07NostrIdentity(
        pubkey: testPublicKey,
        nip07Signer: mockSigner,
      );

      // All five variants expose the same pubkey — it's a final field,
      // not a getter that reads from a mutable slot.
      for (final identity in <NostrIdentity>[
        local,
        keycast,
        bunker,
        amber,
        nip07,
      ]) {
        expect(identity.pubkey, equals(testPublicKey));
      }
    });
  });
}
