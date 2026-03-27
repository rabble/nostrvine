// ABOUTME: Represents the current user's signing identity, bundling pubkey
// ABOUTME: and signing method (local, keycast, bunker, amber) into one unit

import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer, SecureKeyStorage;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// The mechanism used for signing Nostr events.
enum SigningMethod {
  /// Local nsec stored in SecureKeyStorage.
  local,

  /// Keycast OAuth RPC signer.
  keycastRpc,

  /// NIP-46 bunker remote signer.
  bunker,

  /// NIP-55 Android Amber signer.
  amber,
}

/// A unified signing identity for the current user.
///
/// Bundles the user's public key and the active signing method into a single
/// atomic unit. Callers ask it to sign — it handles the how.
///
/// Implements [NostrSigner] so it can be passed directly to [NostrClient] or
/// any other consumer that needs to sign, encrypt, or decrypt events.
class NostrIdentity implements NostrSigner {
  /// Creates a [NostrIdentity] backed by a remote signer (keycast, bunker, or
  /// amber). The [signer] handles all cryptographic operations.
  NostrIdentity.remote({
    required this.publicKeyHex,
    required this.npub,
    required NostrSigner signer,
    required this.signingMethod,
    required this.authSource,
    this.keyContainer,
  }) : _remoteSigner = signer;

  /// Creates a [NostrIdentity] backed by local key storage.
  ///
  /// The [keyContainer] provides the public key, and [keyStorage] handles
  /// private key access for signing operations.
  NostrIdentity.local({
    required SecureKeyContainer this.keyContainer,
    required SecureKeyStorage keyStorage,
    required this.authSource,
  }) : publicKeyHex = keyContainer.publicKeyHex,
       npub = keyContainer.npub,
       signingMethod = SigningMethod.local,
       _remoteSigner = null,
       _keyStorage = keyStorage;

  /// The user's public key in hex format.
  final String publicKeyHex;

  /// The user's public key in npub (bech32) format.
  final String npub;

  /// How events are signed.
  final SigningMethod signingMethod;

  /// The authentication source that produced this identity.
  final AuthenticationSource authSource;

  /// The key container, if available (local signing or public-key reference).
  final SecureKeyContainer? keyContainer;

  final NostrSigner? _remoteSigner;
  SecureKeyStorage? _keyStorage;

  /// Whether this identity uses a remote signer.
  bool get isRemote => _remoteSigner != null;

  @override
  Future<String?> getPublicKey() async => publicKeyHex;

  @override
  Future<Event?> signEvent(Event event) async {
    if (_remoteSigner case final signer?) {
      return signer.signEvent(event);
    }
    return _signLocally(event);
  }

  @override
  Future<Map?> getRelays() async {
    if (_remoteSigner case final signer?) {
      return signer.getRelays();
    }
    return null;
  }

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async {
    if (_remoteSigner case final signer?) {
      return signer.encrypt(pubkey, plaintext);
    }
    return _withLocalKey((privateKeyHex) {
      final agreement = NIP04.getAgreement(privateKeyHex);
      return NIP04.encrypt(plaintext, agreement, pubkey);
    });
  }

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async {
    if (_remoteSigner case final signer?) {
      return signer.decrypt(pubkey, ciphertext);
    }
    return _withLocalKey((privateKeyHex) {
      final agreement = NIP04.getAgreement(privateKeyHex);
      return NIP04.decrypt(ciphertext, agreement, pubkey);
    });
  }

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async {
    if (_remoteSigner case final signer?) {
      return signer.nip44Encrypt(pubkey, plaintext);
    }
    return _withLocalKeyAsync((privateKeyHex) async {
      final conversationKey = NIP44V2.shareSecret(privateKeyHex, pubkey);
      return NIP44V2.encrypt(plaintext, conversationKey);
    });
  }

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    if (_remoteSigner case final signer?) {
      return signer.nip44Decrypt(pubkey, ciphertext);
    }
    return _withLocalKeyAsync((privateKeyHex) async {
      final sealKey = NIP44V2.shareSecret(privateKeyHex, pubkey);
      return NIP44V2.decrypt(ciphertext, sealKey);
    });
  }

  @override
  void close() {
    _remoteSigner?.close();
  }

  Future<Event?> _signLocally(Event event) async {
    final keyStorage = _keyStorage;
    if (keyStorage == null) return null;
    try {
      return await keyStorage.withPrivateKey<Event?>((privateKey) {
        event.sign(privateKey);
        return event;
      });
    } on Exception catch (e) {
      Log.error(
        'Local signing failed: $e',
        name: 'NostrIdentity',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  Future<T?> _withLocalKey<T>(T Function(String privateKeyHex) callback) async {
    final keyStorage = _keyStorage;
    if (keyStorage == null) return null;
    try {
      return await keyStorage.withPrivateKey<T?>(
        (privateKeyHex) => callback(privateKeyHex),
      );
    } on Exception catch (e) {
      Log.error(
        'Local key operation failed: $e',
        name: 'NostrIdentity',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  Future<T?> _withLocalKeyAsync<T>(
    Future<T> Function(String privateKeyHex) callback,
  ) async {
    final keyStorage = _keyStorage;
    if (keyStorage == null) return null;
    try {
      return await keyStorage.withPrivateKey<Future<T?>>(
        (privateKeyHex) => callback(privateKeyHex),
      );
    } on Exception catch (e) {
      Log.error(
        'Local key operation failed: $e',
        name: 'NostrIdentity',
        category: LogCategory.auth,
      );
      return null;
    }
  }
}
