// ABOUTME: Tests for the IdentityClaim model — JSON shape and equality.

import 'package:test/test.dart';
import 'package:verifier_client/verifier_client.dart';

const _hex64 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group(IdentityClaim, () {
    test('encodes to verifier API JSON shape', () {
      const claim = IdentityClaim(
        pubkey: _hex64,
        platform: 'github',
        identity: 'octocat',
        proof: 'abc123',
      );
      expect(claim.toJson(), {
        'pubkey': _hex64,
        'platform': 'github',
        'identity': 'octocat',
        'proof': 'abc123',
      });
    });

    test('two claims with the same fields are equal', () {
      const a = IdentityClaim(
        pubkey: _hex64,
        platform: 'github',
        identity: 'octocat',
        proof: 'abc123',
      );
      const b = IdentityClaim(
        pubkey: _hex64,
        platform: 'github',
        identity: 'octocat',
        proof: 'abc123',
      );
      expect(a, equals(b));
    });

    test('claims with different fields are not equal', () {
      const a = IdentityClaim(
        pubkey: _hex64,
        platform: 'github',
        identity: 'octocat',
        proof: 'abc123',
      );
      const b = IdentityClaim(
        pubkey: _hex64,
        platform: 'twitter',
        identity: 'octocat',
        proof: 'abc123',
      );
      expect(a, isNot(equals(b)));
    });

    test('accepts claims matching the verifier contract', () {
      const claim = IdentityClaim(
        pubkey: _hex64,
        platform: 'github',
        identity: 'octocat',
        proof: 'abc123',
      );
      expect(claim.isServerValid, isTrue);
    });

    test('accepts bluesky claims with a blank proof', () {
      const claim = IdentityClaim(
        pubkey: _hex64,
        platform: 'bluesky',
        identity: 'octocat.bsky.social',
        proof: '',
      );
      expect(claim.isServerValid, isTrue);
    });

    test('rejects invalid pubkeys', () {
      for (final pubkey in ['short', '${_hex64}a', 'g${_hex64.substring(1)}']) {
        final claim = IdentityClaim(
          pubkey: pubkey,
          platform: 'github',
          identity: 'octocat',
          proof: 'abc123',
        );
        expect(claim.isServerValid, isFalse);
      }
    });

    test('rejects unsupported platforms', () {
      const claim = IdentityClaim(
        pubkey: _hex64,
        platform: 'reddit',
        identity: 'octocat',
        proof: 'abc123',
      );
      expect(claim.isServerValid, isFalse);
    });

    test('rejects identities the verifier would reject', () {
      for (final identity in [
        'bad"identity',
        "bad'identity",
        'bad<identity',
        'bad${String.fromCharCode(1)}identity',
        List.filled(IdentityClaim.maxServerTextLength + 1, 'a').join(),
      ]) {
        final claim = IdentityClaim(
          pubkey: _hex64,
          platform: 'github',
          identity: identity,
          proof: 'abc123',
        );
        expect(claim.isServerValid, isFalse);
      }
    });

    test('rejects non-bluesky proofs the verifier would reject', () {
      for (final proof in [
        '',
        'bad>proof',
        'bad${String.fromCharCode(1)}proof',
        List.filled(IdentityClaim.maxServerTextLength + 1, 'a').join(),
      ]) {
        final claim = IdentityClaim(
          pubkey: _hex64,
          platform: 'github',
          identity: 'octocat',
          proof: proof,
        );
        expect(claim.isServerValid, isFalse);
      }
    });
  });
}
