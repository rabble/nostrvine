// ABOUTME: Tests for PKCE (Proof Key for Code Exchange) utilities
// ABOUTME: Verifies verifier generation, challenge computation, and BYOK embedding

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

    group('generateVerifier with BYOK', () {
      test('embeds nsec in format {random}.{nsec}', () {
        const nsec = 'nsec1test123';
        final verifier = Pkce.generateVerifier(nsec: nsec);
        expect(verifier, contains('.'));
        expect(verifier, endsWith('.nsec1test123'));
      });

      test('random part is base64url without padding', () {
        const nsec = 'nsec1abc';
        final verifier = Pkce.generateVerifier(nsec: nsec);
        final parts = verifier.split('.');
        expect(parts.length, 2);
        final randomPart = parts[0];
        expect(randomPart, isNot(contains('=')));
        expect(randomPart, isNot(contains('+')));
        expect(randomPart, isNot(contains('/')));
      });

      test('without nsec, returns plain verifier (no dot)', () {
        final verifier = Pkce.generateVerifier();
        expect(verifier, isNot(contains('.')));
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

    group('BYOK verifier with challenge', () {
      test('challenge is computed on full verifier including nsec', () {
        const nsec = 'nsec1secret';
        final verifier = Pkce.generateVerifier(nsec: nsec);
        final challenge = Pkce.generateChallenge(verifier);

        final expectedHash = sha256.convert(utf8.encode(verifier));
        final expectedChallenge = base64Url
            .encode(expectedHash.bytes)
            .replaceAll('=', '');

        expect(challenge, equals(expectedChallenge));
      });
    });
  });
}
