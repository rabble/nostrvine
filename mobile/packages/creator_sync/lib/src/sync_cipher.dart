// ABOUTME: AES-256-GCM sealing of sync index payloads under the vault key.
// ABOUTME: Keeps bulk crypto off the Nostr signer for NIP-46/Amber users.

import 'dart:convert';
import 'dart:typed_data';

import 'package:creator_sync/src/exceptions.dart';
import 'package:cryptography/cryptography.dart';

/// Seals and opens sync index payloads with the account's vault key.
///
/// Index payloads are encrypted with the vault key rather than NIP-44 so
/// that a remote signer (NIP-46 bunker, NIP-55 Amber) is consulted exactly
/// once per device — to unwrap the vault key — instead of once per synced
/// item.
class SyncCipher {
  /// Creates a [SyncCipher] bound to the given vault key.
  SyncCipher(this._vaultKey);

  final SecretKey _vaultKey;

  static final AesGcm _algorithm = AesGcm.with256bits();

  /// Nonce length in bytes for AES-GCM.
  static const int nonceLength = 12;

  /// MAC length in bytes for AES-GCM.
  static const int macLength = 16;

  /// Encrypts [plaintext], returning base64 of `nonce || ciphertext || mac`.
  Future<String> seal(String plaintext) async {
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: _vaultKey,
    );
    return base64Encode(secretBox.concatenation());
  }

  /// Decrypts a payload produced by [seal].
  ///
  /// Throws [SyncDecryptException] if the input is malformed, truncated,
  /// tampered with, or sealed under a different key.
  Future<String> open(String sealed) async {
    final Uint8List bytes;
    try {
      bytes = base64Decode(sealed);
    } on FormatException catch (e) {
      throw SyncDecryptException('payload is not valid base64: ${e.message}');
    }

    if (bytes.length < nonceLength + macLength) {
      throw SyncDecryptException(
        'payload is ${bytes.length} bytes, shorter than the minimum '
        '${nonceLength + macLength}',
      );
    }

    try {
      final secretBox = SecretBox.fromConcatenation(
        bytes,
        nonceLength: nonceLength,
        macLength: macLength,
      );
      final clear = await _algorithm.decrypt(
        secretBox,
        secretKey: _vaultKey,
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw SyncDecryptException('payload failed authentication');
    } on FormatException catch (e) {
      throw SyncDecryptException('payload is malformed: ${e.message}');
    }
  }
}
