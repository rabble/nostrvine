// ABOUTME: Key utilities for Keycast - nsec parsing and public key derivation
// ABOUTME: Wraps nostr_sdk to provide convenient key operations for OAuth flow

import 'package:nostr_sdk/nostr_sdk.dart' as nostr;

class KeyUtils {
  static String? parseNsec(String nsec) {
    if (!nostr.Nip19.isPrivateKey(nsec)) {
      return null;
    }
    final hex = nostr.Nip19.decode(nsec);
    if (hex.isEmpty || hex.length != 64) {
      return null;
    }
    return hex;
  }

  static String? derivePublicKey(String privateKeyHex) {
    if (!isValidHexKey(privateKeyHex)) {
      return null;
    }
    try {
      return nostr.getPublicKey(privateKeyHex);
    } catch (_) {
      return null;
    }
  }

  static String? derivePublicKeyFromNsec(String nsec) {
    final privateKeyHex = parseNsec(nsec);
    if (privateKeyHex == null) {
      return null;
    }
    return derivePublicKey(privateKeyHex);
  }

  static bool isValidHexKey(String key) {
    return nostr.keyIsValid(key);
  }

  static String? encodeToPubkey(String hexPubkey) {
    if (!isValidHexKey(hexPubkey)) {
      return null;
    }
    try {
      return nostr.Nip19.encodePubKey(hexPubkey);
    } catch (_) {
      return null;
    }
  }

  static String generatePrivateKey() {
    return nostr.generatePrivateKey();
  }

  static String? encodeToNsec(String hexPrivateKey) {
    if (!isValidHexKey(hexPrivateKey)) {
      return null;
    }
    try {
      return nostr.Nip19.encodePrivateKey(hexPrivateKey);
    } catch (_) {
      return null;
    }
  }
}
