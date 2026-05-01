// ABOUTME: PKCE (Proof Key for Code Exchange) utilities for OAuth 2.0
// ABOUTME: Generates random verifiers and SHA256 challenges per RFC 7636

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class Pkce {
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
