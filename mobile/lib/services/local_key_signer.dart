// ABOUTME: NostrSigner implementation backed by a local SecureKeyContainer
// ABOUTME: Provides secure event signing and encryption using locally stored keys

import 'dart:typed_data';

import 'package:bip340/bip340.dart' as schnorr;
import 'package:crypto/crypto.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:unified_logger/unified_logger.dart';

const _canonicalPayloadAux =
    '00000000000000000000000000000000'
    '00000000000000000000000000000000';

/// NostrSigner implementation backed by a local [SecureKeyContainer].
///
/// Used internally by [LocalNostrIdentity] and [KeycastNostrIdentity]'s
/// local signing optimization. Not used directly by consumers.
class LocalKeySigner implements IsolateDecryptSigner {
  /// Creates a [LocalKeySigner] with the given key container.
  LocalKeySigner(this._keyContainer);

  final SecureKeyContainer? _keyContainer;

  /// Returns the current public key for creator-bound signing flows.
  Future<String> currentPubkey() async {
    return _keyContainer?.publicKeyHex ?? '';
  }

  /// Whether this signer can expose its private key bytes to a
  /// [compute()] isolate for batch decryption. True only for local
  /// signers that already keep the key in memory.
  @override
  bool get canDecryptInIsolate =>
      _keyContainer != null && _keyContainer.hasPrivateKey;

  /// Runs [operation] with the raw private key hex. Mirrors
  /// [SecureKeyContainer.withPrivateKey] but scoped to this signer so
  /// callers never need to reach into the container directly.
  @override
  T withPrivateKeyHex<T>(T Function(String hex) operation) {
    final container = _keyContainer;
    if (container == null) {
      throw StateError('LocalKeySigner has no key container');
    }
    return container.withPrivateKey(operation);
  }

  @override
  Future<String?> getPublicKey() async {
    return _keyContainer?.publicKeyHex ?? '';
  }

  /// Signs an arbitrary canonical payload by first hashing it with SHA-256.
  ///
  /// Uses deterministic auxiliary data so repeated signing of the same payload
  /// produces the same signature, which keeps creator-binding assertions stable.
  Future<String?> signCanonicalPayload(Uint8List payload) async {
    if (_keyContainer == null) return null;
    try {
      final digest = sha256.convert(payload).toString();
      return _keyContainer.withPrivateKey<String>((privateKeyHex) {
        return schnorr.sign(privateKeyHex, digest, _canonicalPayloadAux);
      });
    } on Exception catch (e) {
      Log.error(
        'Failed to sign canonical payload: $e',
        name: 'LocalKeySigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<Event?> signEvent(Event event) async {
    if (_keyContainer == null) return null;
    try {
      return _keyContainer.withPrivateKey<Event>((privateKeyHex) {
        event.sign(privateKeyHex);
        return event;
      });
    } on Exception catch (e) {
      Log.error(
        'Failed to sign event: $e',
        name: 'LocalKeySigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<Map?> getRelays() async => null;

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async {
    if (_keyContainer == null) return null;
    try {
      return _keyContainer.withPrivateKey<String?>((privateKeyHex) {
        final agreement = NIP04.getAgreement(privateKeyHex);
        return NIP04.encrypt(plaintext, agreement, pubkey);
      });
    } on Exception catch (e) {
      Log.error(
        'NIP-04 encryption failed: $e',
        name: 'LocalKeySigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async {
    if (_keyContainer == null) return null;
    try {
      return _keyContainer.withPrivateKey<String?>((privateKeyHex) {
        final agreement = NIP04.getAgreement(privateKeyHex);
        return NIP04.decrypt(ciphertext, agreement, pubkey);
      });
    } on Exception catch (e) {
      Log.error(
        'NIP-04 decryption failed: $e',
        name: 'LocalKeySigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async {
    if (_keyContainer == null) return null;
    try {
      return _keyContainer.withPrivateKey<Future<String?>>((
        privateKeyHex,
      ) async {
        final conversationKey = NIP44V2.shareSecret(privateKeyHex, pubkey);
        return NIP44V2.encrypt(plaintext, conversationKey);
      });
    } on Exception catch (e) {
      Log.error(
        'NIP-44 encryption failed: $e',
        name: 'LocalKeySigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    if (_keyContainer == null) return null;
    try {
      return _keyContainer.withPrivateKey<Future<String?>>((
        privateKeyHex,
      ) async {
        final sealKey = NIP44V2.shareSecret(privateKeyHex, pubkey);
        return NIP44V2.decrypt(ciphertext, sealKey);
      });
    } on Exception catch (e) {
      Log.error(
        'NIP-44 decryption failed: $e',
        name: 'LocalKeySigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  void close() {
    // Key container is managed by AuthService, not disposed here
  }
}
