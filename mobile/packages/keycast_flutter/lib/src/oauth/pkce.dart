// ABOUTME: PKCE (Proof Key for Code Exchange) utilities for OAuth 2.0
// ABOUTME: Generates RFC 7636 random verifiers and their S256 challenges

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class Pkce {
  /// Generates a high-entropy RFC 7636 `code_verifier`: 32 cryptographically
  /// random bytes, base64url-encoded with padding stripped.
  ///
  /// The verifier never carries caller-supplied material. Embedding the user's
  /// nsec here used to leak the private key into the OAuth challenge — see
  /// divinevideo/divine-mobile#3359.
  static String generateVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String generateChallenge(String verifier) {
    final hash = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(hash.bytes).replaceAll('=', '');
  }
}
