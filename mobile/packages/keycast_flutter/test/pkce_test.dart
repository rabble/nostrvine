// ABOUTME: Tests for PKCE (Proof Key for Code Exchange) utilities
// ABOUTME: Verifies verifier generation and challenge computation

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/src/oauth/pkce.dart';

void main() {
  group('Pkce', () {
    group('generateVerifier', () {
      test('generates base64url encoded string', () {
        final verifier = Pkce.generateVerifier();
        expect(verifier, isNotEmpty);
        expect(verifier, isNot(contains('=')));
        expect(verifier, isNot(contains('+')));
        expect(verifier, isNot(contains('/')));
      });

      test('generates different values on each call', () {
        final verifier1 = Pkce.generateVerifier();
        final verifier2 = Pkce.generateVerifier();
        expect(verifier1, isNot(equals(verifier2)));
      });

      test('has sufficient length for security', () {
        final verifier = Pkce.generateVerifier();
        expect(verifier.length, greaterThanOrEqualTo(43));
      });
    });

    group('leak-prevention regression guard (#3359)', () {
      test('never embeds an nsec — no nsec1 substring, no dot separator', () {
        // Pre-fix code built the verifier as `<random>.<nsec1...>`, leaking
        // the user's private key into the OAuth challenge. The nsec parameter
        // is removed; the verifier must always be pure random with no embedded
        // material. Loop to make an accidental reintroduction fail loudly.
        for (var i = 0; i < 64; i++) {
          final verifier = Pkce.generateVerifier();
          expect(verifier, isNot(contains('nsec1')));
          expect(verifier, isNot(contains('.')));
        }
      });
    });

    group('generateChallenge', () {
      test('generates SHA256 hash of verifier', () {
        const verifier = 'test_verifier_string';
        final challenge = Pkce.generateChallenge(verifier);

        final expectedHash = sha256.convert(utf8.encode(verifier));
        final expectedChallenge = base64Url
            .encode(expectedHash.bytes)
            .replaceAll('=', '');

        expect(challenge, equals(expectedChallenge));
      });

      test('is base64url encoded without padding', () {
        final verifier = Pkce.generateVerifier();
        final challenge = Pkce.generateChallenge(verifier);

        expect(challenge, isNot(contains('=')));
        expect(challenge, isNot(contains('+')));
        expect(challenge, isNot(contains('/')));
      });

      test('has 43 character length (256 bits / 6 bits per char)', () {
        final verifier = Pkce.generateVerifier();
        final challenge = Pkce.generateChallenge(verifier);
        expect(challenge.length, 43);
      });

      test('same verifier produces same challenge', () {
        const verifier = 'consistent_verifier';
        final challenge1 = Pkce.generateChallenge(verifier);
        final challenge2 = Pkce.generateChallenge(verifier);
        expect(challenge1, equals(challenge2));
      });

      test('different verifiers produce different challenges', () {
        final challenge1 = Pkce.generateChallenge('verifier1');
        final challenge2 = Pkce.generateChallenge('verifier2');
        expect(challenge1, isNot(equals(challenge2)));
      });
    });
  });
}
