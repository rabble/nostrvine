// ABOUTME: Thin private/public key pair wrapper backed by nostr_sdk key ops.

import 'package:nostr_sdk/client_utils/keys.dart';

/// Simple key pair wrapper using nostr_sdk for key operations.
///
/// This is a convenience class that wraps a private/public key pair.
/// All key generation and derivation uses nostr_sdk's functions:
/// - generatePrivateKey() for key generation
/// - getPublicKey() for public key derivation
class Keychain {
  /// Creates a keychain from a private key.
  ///
  /// The public key is automatically derived using nostr_sdk's getPublicKey().
  Keychain(this.private) : public = getPublicKey(private);

  /// Generate a new key pair using nostr_sdk's secure key generation.
  ///
  /// Returns a new [Keychain] with a randomly generated private key.
  factory Keychain.generate() {
    final privateKey = generatePrivateKey();
    return Keychain(privateKey);
  }

  /// The private key in hex format (64 characters).
  final String private;

  /// The public key in hex format (64 characters), derived from [private].
  final String public;
}
