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
  });
}
