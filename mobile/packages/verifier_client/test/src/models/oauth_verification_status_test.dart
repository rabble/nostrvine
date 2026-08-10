// ABOUTME: OAuthVerificationStatus tests — parsing and value equality.

import 'package:test/test.dart';
import 'package:verifier_client/verifier_client.dart';

void main() {
  group(OAuthVerificationStatus, () {
    test('parses a verified status', () {
      final status = OAuthVerificationStatus.fromJson(const {
        'platform': 'twitter',
        'identity': 'jack',
        'verified': true,
        'checked_at': 1700000000,
      });

      expect(status.platform, equals('twitter'));
      expect(status.identity, equals('jack'));
      expect(status.verified, isTrue);
      expect(status.checkedAt, equals(1700000000));
    });

    test('defaults verified to false when the field is absent', () {
      final status = OAuthVerificationStatus.fromJson(const {
        'platform': 'tiktok',
        'identity': 'someone',
      });

      expect(status.verified, isFalse);
      expect(status.checkedAt, isNull);
    });

    test('compares by value', () {
      const a = OAuthVerificationStatus(
        platform: 'twitter',
        identity: 'jack',
        verified: true,
        checkedAt: 1,
      );
      const b = OAuthVerificationStatus(
        platform: 'twitter',
        identity: 'jack',
        verified: true,
        checkedAt: 1,
      );
      const c = OAuthVerificationStatus(
        platform: 'twitter',
        identity: 'jack',
        verified: false,
        checkedAt: 1,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
