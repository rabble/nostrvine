// ABOUTME: Tests for PKCE (Proof Key for Code Exchange) utilities
// ABOUTME: Verifies verifier generation and challenge computation per RFC 7636

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

      test('never embeds an nsec — leak-prevention regression guard', () {
        // Phase 1 of divinevideo/divine-mobile#3359 strips the legacy BYOK
        // embedding (`<random>.<nsec1...>`). The verifier must never contain
        // an `nsec1` substring or the `.` separator regardless of input.
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
