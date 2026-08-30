// ABOUTME: Tests signer readiness across identity and RPC capability states.
// ABOUTME: Pins terminal signer failure separately from temporary warm-up.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth/signer_readiness_resolver.dart';
import 'package:openvine/services/local_key_signer.dart';

class _MockSigner extends Mock implements NostrSigner {}

class _MockKeyContainer extends Mock implements SecureKeyContainer {}

class _MockLocalKeySigner extends Mock implements LocalKeySigner {}

void main() {
  group('resolveSignerReadiness', () {
    const pubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    test('no identity remains pending', () {
      expect(
        resolveSignerReadiness(null, AuthRpcCapability.unavailable),
        SignerReadiness.pending,
      );
    });

    test('pubkey-only identity waits only while RPC is upgrading', () {
      final identity = PubkeyOnlyNostrIdentity(pubkey: pubkey);

      expect(
        resolveSignerReadiness(identity, AuthRpcCapability.upgrading),
        SignerReadiness.pending,
      );
      expect(
        resolveSignerReadiness(identity, AuthRpcCapability.unavailable),
        SignerReadiness.unavailable,
      );
    });

    test('remote Keycast identity follows RPC capability', () {
      final identity = KeycastNostrIdentity(
        pubkey: pubkey,
        rpcSigner: _MockSigner(),
      );

      expect(
        resolveSignerReadiness(identity, AuthRpcCapability.upgrading),
        SignerReadiness.pending,
      );
      expect(
        resolveSignerReadiness(identity, AuthRpcCapability.unavailable),
        SignerReadiness.unavailable,
      );
      expect(
        resolveSignerReadiness(identity, AuthRpcCapability.rpcReady),
        SignerReadiness.ready,
      );
    });

    test('local and interactive identities are always ready', () {
      final keyContainer = _MockKeyContainer();
      when(() => keyContainer.publicKeyHex).thenReturn(pubkey);
      final signer = _MockSigner();
      final identities = <NostrIdentity>[
        LocalNostrIdentity(keyContainer: keyContainer),
        KeycastNostrIdentity(
          pubkey: pubkey,
          rpcSigner: signer,
          localSigner: _MockLocalKeySigner(),
        ),
        BunkerNostrIdentity(pubkey: pubkey, remoteSigner: signer),
        AmberNostrIdentity(pubkey: pubkey, amberSigner: signer),
        Nip07NostrIdentity(pubkey: pubkey, nip07Signer: signer),
      ];

      for (final identity in identities) {
        expect(
          resolveSignerReadiness(identity, AuthRpcCapability.unavailable),
          SignerReadiness.ready,
        );
      }
    });
  });
}
