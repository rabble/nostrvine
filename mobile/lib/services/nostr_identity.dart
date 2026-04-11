import 'dart:typed_data';

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
  /// support deterministic local signing (remote-only signers).
  Future<String?> signCanonicalPayload(Uint8List payload);
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
    implements IsolateDecryptSigner {
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
    }
    return _rpcSigner.signEvent(event);
  }

  @override
  Future<String?> signCanonicalPayload(Uint8List payload) async {
    // Canonical signing requires deterministic local keys.
    return _localSigner?.signCanonicalPayload(payload);
  }

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
  BunkerNostrIdentity({
    required this.pubkey,
    required NostrSigner remoteSigner,
  }) : _remoteSigner = remoteSigner;

  final NostrSigner _remoteSigner;

  @override
  final String pubkey;

  @override
  Future<String?> getPublicKey() async => pubkey;

  @override
  Future<Event?> signEvent(Event event) => _remoteSigner.signEvent(event);

  @override
  Future<String?> signCanonicalPayload(Uint8List payload) async => null;

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
  AmberNostrIdentity({
    required this.pubkey,
    required NostrSigner amberSigner,
  }) : _amberSigner = amberSigner;

  final NostrSigner _amberSigner;

  @override
  final String pubkey;

  @override
  Future<String?> getPublicKey() async => pubkey;

  @override
  Future<Event?> signEvent(Event event) => _amberSigner.signEvent(event);

  @override
  Future<String?> signCanonicalPayload(Uint8List payload) async => null;

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
