// ABOUTME: NostrSigner implementation that bridges AuthService's SecureKeyContainer
// ABOUTME: Provides secure event signing and encryption using the auth service's keys

import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Callback type for lazily getting the current key container
typedef KeyContainerGetter = SecureKeyContainer? Function();

/// NostrSigner implementation that uses SecureKeyContainer from AuthService
///
/// This signer checks for the key container at signing time via a getter callback.
/// This allows the NostrClient to be created before authentication completes,
/// and signing will work automatically once auth is ready.
class AuthServiceSigner implements NostrSigner {
  /// Creates an AuthServiceSigner with a callback to get the current key container
  AuthServiceSigner(this._getKeyContainer);

  final KeyContainerGetter _getKeyContainer;

  @override
  Future<String?> getPublicKey() async {
    return _getKeyContainer()?.publicKeyHex ?? '';
  }

  @override
  Future<Event?> signEvent(Event event) async {
    final keyContainer = _getKeyContainer();
    if (keyContainer == null) return null;
    try {
      return keyContainer.withPrivateKey<Event>((privateKeyHex) {
        event.sign(privateKeyHex);
        return event;
      });
    } on Exception catch (e) {
      Log.error(
        'Failed to sign event: $e',
        name: 'AuthServiceSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<Map?> getRelays() async => null;

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async {
    final keyContainer = _getKeyContainer();
    if (keyContainer == null) return null;
    try {
      return keyContainer.withPrivateKey<String?>((privateKeyHex) {
        final agreement = NIP04.getAgreement(privateKeyHex);
        return NIP04.encrypt(plaintext, agreement, pubkey);
      });
    } on Exception catch (e) {
      Log.error(
        'NIP-04 encryption failed: $e',
        name: 'AuthServiceSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async {
    final keyContainer = _getKeyContainer();
    if (keyContainer == null) return null;
    try {
      return keyContainer.withPrivateKey<String?>((privateKeyHex) {
        final agreement = NIP04.getAgreement(privateKeyHex);
        return NIP04.decrypt(ciphertext, agreement, pubkey);
      });
    } on Exception catch (e) {
      Log.error(
        'NIP-04 decryption failed: $e',
        name: 'AuthServiceSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async {
    final keyContainer = _getKeyContainer();
    if (keyContainer == null) return null;
    try {
      return keyContainer.withPrivateKey<Future<String?>>((
        privateKeyHex,
      ) async {
        final conversationKey = NIP44V2.shareSecret(privateKeyHex, pubkey);
        return NIP44V2.encrypt(plaintext, conversationKey);
      });
    } on Exception catch (e) {
      Log.error(
        'NIP-44 encryption failed: $e',
        name: 'AuthServiceSigner',
        category: LogCategory.relay,
      );
      return null;
    }
  }

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    final keyContainer = _getKeyContainer();
    if (keyContainer == null) return null;
    try {
      return keyContainer.withPrivateKey<Future<String?>>((
        privateKeyHex,
      ) async {
        final sealKey = NIP44V2.shareSecret(privateKeyHex, pubkey);
        return NIP44V2.decrypt(ciphertext, sealKey);
      });
    } on Exception catch (e) {
      Log.error(
        'NIP-44 decryption failed: $e',
        name: 'AuthServiceSigner',
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
