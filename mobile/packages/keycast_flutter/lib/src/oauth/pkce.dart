// ABOUTME: PKCE (Proof Key for Code Exchange) utilities for OAuth 2.0
// ABOUTME: Generates verifiers and challenges, with optional BYOK nsec embedding

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class Pkce {
  static String generateVerifier({String? nsec}) {
    final random = _generateRandomPart();
    return nsec != null ? '$random.$nsec' : random;
  }

  static String generateChallenge(String verifier) {
    final hash = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(hash.bytes).replaceAll('=', '');
  }

  static String _generateRandomPart() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
