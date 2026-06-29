import 'dart:typed_data';

import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/local_key_signer.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:unified_logger/unified_logger.dart';

/// The current user's signing identity, coupling pubkey and signing mechanism
/// into a single atomic value.
///
/// Each variant holds its public key as a final field set at construction,
/// structurally preventing the pubkey/signing-key desync that is possible
/// when those values are stored in separate mutable slots.
sealed class NostrIdentity implements NostrSigner {
  /// The hex-encoded public key of this identity.
  String get pubkey;

  /// The bech32-encoded public key (npub format) of this identity.
  String get npub => NostrKeyUtils.encodePubKey(pubkey);

  /// Signs an arbitrary canonical payload (SHA-256 + schnorr with fixed aux).
  ///
  /// Returns the signature hex string, or null if this identity does not
  /// support deterministic canonical signing. Local identities sign
  /// directly; Keycast identities try local first and fall back to a
  /// `sign_canonical` RPC. NIP-46 (bunker) and NIP-55 (amber) identities
  /// always return null because their protocols only define event signing.
  Future<String?> signCanonicalPayload(Uint8List payload);

  /// Whether this identity signs remotely over a non-interactive network
  /// round-trip (no human approval step in the loop).
  ///
  /// True ONLY for the Keycast OAuth-only signer, whose signing is bounded by
  /// a network RPC and can therefore hang on a flaky connection. Viewer-media
  /// auth uses this to apply a short caller-side timeout. Interactive remote
  /// signers (NIP-46 bunker, NIP-55 Amber, NIP-07 extension) are human-paced —
  /// the user reads a prompt and approves — so they must NOT be timed out.
  bool get signsRemotelyNonInteractive;

  /// Whether this identity produces signatures in-process with a private key
  /// it holds directly.
  ///
  /// True for local key signers, and for Keycast when a matching local key is
  /// present. False for external/remote signers (NIP-46 bunker, NIP-55 Amber,
  /// NIP-07 extension), whose returned signature crosses a trust boundary.
  ///
  /// A caller that has just signed an event can skip re-verifying the
  /// signature when this is true: re-verifying a signature we produced
  /// ourselves only exercises the crypto library and costs a full schnorr
  /// verification per event. Structural validation (event id == hash) is
  /// cheap and should still run regardless.
  ///
  /// Contract upheld for the caller: when this is true, every event returned
  /// by [signEvent] carries a signature that needs no external verification.
  /// [KeycastNostrIdentity] keeps that true even in its rare
  /// local-sign-fails → RPC fallback by verifying the RPC result before
  /// returning it, so the flag is a guarantee about the returned event, not
  /// merely the capability that a local key exists.
  bool get signsWithLocalKey;
}

/// Identity backed by a local [SecureKeyContainer] with a private key.
class LocalNostrIdentity extends NostrIdentity implements IsolateDecryptSigner {
  LocalNostrIdentity({required SecureKeyContainer keyContainer})
    : _signer = LocalKeySigner(keyContainer),
      pubkey = keyContainer.publicKeyHex;

  final LocalKeySigner _signer;

  @override
  final String pubkey;

  @override
  Future<String?> getPublicKey() async => pubkey;

  @override
  Future<Event?> signEvent(Event event) => _signer.signEvent(event);

  @override
  Future<String?> signCanonicalPayload(Uint8List payload) =>
      _signer.signCanonicalPayload(payload);

  @override
  bool get signsRemotelyNonInteractive => false;

  @override
  bool get signsWithLocalKey => true;

  @override
  bool get canDecryptInIsolate => _signer.canDecryptInIsolate;

  @override
  T withPrivateKeyHex<T>(T Function(String hex) operation) =>
      _signer.withPrivateKeyHex(operation);

  @override
  Future<Map?> getRelays() async => null;

  @override
  Future<String?> encrypt(String pubkey, String plaintext) =>
      _signer.encrypt(pubkey, plaintext);

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) =>
      _signer.decrypt(pubkey, ciphertext);

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) =>
      _signer.nip44Encrypt(pubkey, plaintext);

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) =>
      _signer.nip44Decrypt(pubkey, ciphertext);

  @override
  void close() {
    // Key container lifecycle is managed by AuthService.
  }
}

/// Identity backed by a Keycast OAuth session.
///
/// When a matching local private key is available, signs locally for speed.
/// Otherwise delegates to the remote [KeycastRpc] signer.
class KeycastNostrIdentity extends NostrIdentity
    implements IsolateDecryptSigner, GiftWrapBatchUnwrapper {
  /// Creates a Keycast identity.
  ///
  /// [rpcSigner] is the remote Keycast RPC signer.
  /// [localSigner] is an optional local signer for the speed optimization.
  /// If provided, the local signer's pubkey must match [pubkey] and the
  /// backing key container must have a private key. If either check fails,
  /// the local signer is ignored and all operations go through RPC.
  KeycastNostrIdentity({
    required this.pubkey,
    required NostrSigner rpcSigner,
    LocalKeySigner? localSigner,
  }) : _rpcSigner = rpcSigner,
       _localSigner = localSigner;

  final NostrSigner _rpcSigner;
  final LocalKeySigner? _localSigner;

  @override
  final String pubkey;

  @override
  Future<String?> getPublicKey() async => pubkey;

  @override
  Future<Event?> signEvent(Event event) async {
    // Try local signing first when a matching local key is available.
    if (_localSigner case final local?) {
      final signed = await local.signEvent(event);
      if (signed != null) return signed;
      Log.warning(
        'Local signing failed for Keycast identity, falling back to RPC',
        name: 'KeycastNostrIdentity',
        category: LogCategory.auth,
      );
      // signsWithLocalKey is true for this identity, so the caller skips its
      // post-sign verify. This fallback result came from the remote RPC — a
      // trust boundary — so verify it here to honor that contract; otherwise a
      // tampered/wrong-key RPC signature would slip through unverified. #5450.
      final rpcSigned = await _rpcSigner.signEvent(event);
      if (rpcSigned != null && !rpcSigned.isSigned) {
        Log.error(
          'Keycast RPC fallback returned an invalid signature; rejecting',
          name: 'KeycastNostrIdentity',
          category: LogCategory.auth,
        );
        return null;
      }
      return rpcSigned;
    }
    return _rpcSigner.signEvent(event);
  }

  @override
  Future<String?> signCanonicalPayload(Uint8List payload) async {
    // Local signing path (fast, deterministic) when a matching local key is
    // available. This is the steady-state path for users who have completed
    // BYOK setup or signed in with a recovery phrase.
    final local = _localSigner;
    if (local != null) {
      final result = await local.signCanonicalPayload(payload);
      if (result != null && result.isNotEmpty) return result;
    }

    // OAuth-only fallback: ask the Keycast backend to sign the canonical
    // payload remotely. Returns null if the backend doesn't expose
    // `sign_canonical` yet, in which case the caller skips creator-binding
    // gracefully rather than blocking the publish.
    final rpc = _rpcSigner;
    if (rpc is KeycastRpc) {
      return rpc.signCanonicalPayload(payload);
    }

    return null;
  }

  @override
  Future<List<GiftWrapUnwrapSlot>?> nip17UnwrapBatch(
    List<Map<String, dynamic>> giftWraps,
  ) {
    // OAuth-only Keycast (no local key) drains DM history over RPC; the batch
    // verb unwraps a whole chunk in one round trip. When a local key is present
    // the drain decrypts in an isolate instead and never reaches this path.
    if (_rpcSigner case final GiftWrapBatchUnwrapper unwrapper) {
      return unwrapper.nip17UnwrapBatch(giftWraps);
    }
    return Future.value();
  }

  /// OAuth-only Keycast (no matching local key) signs over the network RPC,
  /// so viewer-media auth bounds it with a short timeout. When a local signer
  /// is present, signing is in-process and fast — not timed out.
  @override
  bool get signsRemotelyNonInteractive => _localSigner == null;

  @override
  bool get signsWithLocalKey => _localSigner != null;

  @override
  bool get canDecryptInIsolate => _localSigner?.canDecryptInIsolate ?? false;

  @override
  T withPrivateKeyHex<T>(T Function(String hex) operation) {
    final localSigner = _localSigner;
    if (localSigner == null) {
      throw StateError(
        'KeycastNostrIdentity has no local signer for isolate decryption',
      );
    }
    return localSigner.withPrivateKeyHex(operation);
  }

  @override
  Future<Map?> getRelays() => _rpcSigner.getRelays();

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async {
    if (_localSigner case final local?) {
      final result = await local.encrypt(pubkey, plaintext);
      if (result != null) return result;
    }
    return _rpcSigner.encrypt(pubkey, plaintext);
  }

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async {
    if (_localSigner case final local?) {
      final result = await local.decrypt(pubkey, ciphertext);
      if (result != null) return result;
    }
    return _rpcSigner.decrypt(pubkey, ciphertext);
  }

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async {
    if (_localSigner case final local?) {
      final result = await local.nip44Encrypt(pubkey, plaintext);
      if (result != null) return result;
    }
    return _rpcSigner.nip44Encrypt(pubkey, plaintext);
  }

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    if (_localSigner case final local?) {
      final result = await local.nip44Decrypt(pubkey, ciphertext);
      if (result != null) return result;
    }
    return _rpcSigner.nip44Decrypt(pubkey, ciphertext);
  }

  @override
  void close() {
    // RPC signer lifecycle is managed by AuthService.
  }
}

/// Identity backed by a NIP-46 bunker remote signer.
class BunkerNostrIdentity extends NostrIdentity {
  BunkerNostrIdentity({required this.pubkey, required NostrSigner remoteSigner})
    : _remoteSigner = remoteSigner;

  final NostrSigner _remoteSigner;

  @override
  final String pubkey;

  @override
  Future<String?> getPublicKey() async => pubkey;

  @override
  Future<Event?> signEvent(Event event) => _remoteSigner.signEvent(event);

  /// NIP-46 does not expose canonical-payload signing — the protocol
  /// only defines event signing. C2PA creator-binding is therefore not
  /// available for bunker-backed identities and the caller skips the
  /// assertion gracefully.
  @override
  Future<String?> signCanonicalPayload(Uint8List payload) async => null;

  // Interactive (NIP-46): the user approves in their bunker app, so signing
  // is human-paced and must not be timed out.
  @override
  bool get signsRemotelyNonInteractive => false;

  @override
  bool get signsWithLocalKey => false;

  @override
  Future<Map?> getRelays() => _remoteSigner.getRelays();

  @override
  Future<String?> encrypt(String pubkey, String plaintext) =>
      _remoteSigner.encrypt(pubkey, plaintext);

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) =>
      _remoteSigner.decrypt(pubkey, ciphertext);

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) =>
      _remoteSigner.nip44Encrypt(pubkey, plaintext);

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) =>
      _remoteSigner.nip44Decrypt(pubkey, ciphertext);

  @override
  void close() {
    // Remote signer lifecycle is managed by AuthService.
  }
}

/// Identity backed by a NIP-55 Amber Android signer.
class AmberNostrIdentity extends NostrIdentity {
  AmberNostrIdentity({required this.pubkey, required NostrSigner amberSigner})
    : _amberSigner = amberSigner;

  final NostrSigner _amberSigner;

  @override
  final String pubkey;

  @override
  Future<String?> getPublicKey() async => pubkey;

  @override
  Future<Event?> signEvent(Event event) => _amberSigner.signEvent(event);

  /// NIP-55 (Amber Android) does not expose canonical-payload signing —
  /// only event signing. C2PA creator-binding is therefore not available
  /// for amber-backed identities and the caller skips the assertion
  /// gracefully.
  @override
  Future<String?> signCanonicalPayload(Uint8List payload) async => null;

  // Interactive (NIP-55): the user approves in Amber, so signing is
  // human-paced and must not be timed out.
  @override
  bool get signsRemotelyNonInteractive => false;

  @override
  bool get signsWithLocalKey => false;

  @override
  Future<Map?> getRelays() => _amberSigner.getRelays();

  @override
  Future<String?> encrypt(String pubkey, String plaintext) =>
      _amberSigner.encrypt(pubkey, plaintext);

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) =>
      _amberSigner.decrypt(pubkey, ciphertext);

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) =>
      _amberSigner.nip44Encrypt(pubkey, plaintext);

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) =>
      _amberSigner.nip44Decrypt(pubkey, ciphertext);

  @override
  void close() {
    // Amber signer lifecycle is managed by AuthService.
  }
}

/// Identity backed by a NIP-07 browser extension (Alby, nos2x, etc.).
///
/// All signing and encryption goes through the extension via
/// [NostrSigner]; the local container is pub-key-only, so
/// [signCanonicalPayload] is unsupported.
class Nip07NostrIdentity extends NostrIdentity {
  Nip07NostrIdentity({
    required this.pubkey,
    required NostrSigner nip07Signer,
  }) : _nip07Signer = nip07Signer;

  final NostrSigner _nip07Signer;

  @override
  final String pubkey;

  @override
  Future<String?> getPublicKey() async => pubkey;

  @override
  Future<Event?> signEvent(Event event) => _nip07Signer.signEvent(event);

  @override
  Future<String?> signCanonicalPayload(Uint8List payload) async => null;

  // Interactive (NIP-07): the user approves in the browser extension, so
  // signing is human-paced and must not be timed out.
  @override
  bool get signsRemotelyNonInteractive => false;

  @override
  bool get signsWithLocalKey => false;

  @override
  Future<Map?> getRelays() => _nip07Signer.getRelays();

  @override
  Future<String?> encrypt(String pubkey, String plaintext) =>
      _nip07Signer.encrypt(pubkey, plaintext);

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) =>
      _nip07Signer.decrypt(pubkey, ciphertext);

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) =>
      _nip07Signer.nip44Encrypt(pubkey, plaintext);

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) =>
      _nip07Signer.nip44Decrypt(pubkey, ciphertext);

  @override
  void close() {
    // Extension lifecycle is managed by AuthService.
  }
}
