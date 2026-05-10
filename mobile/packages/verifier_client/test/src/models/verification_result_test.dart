// ABOUTME: Tests for the VerificationResult model — JSON parsing.

import 'package:test/test.dart';
import 'package:verifier_client/verifier_client.dart';

void main() {
  group(VerificationResult, () {
    test('parses a verified result from JSON', () {
      final json = <String, dynamic>{
        'platform': 'github',
        'identity': 'octocat',
        'verified': true,
        'checked_at': 1700000000,
        'cached': true,
      };
      final result = VerificationResult.fromJson(json);
      expect(result.verified, isTrue);
      expect(result.platform, equals('github'));
      expect(result.identity, equals('octocat'));
      expect(result.cached, isTrue);
      expect(result.checkedAt, equals(1700000000));
      expect(result.error, isNull);
    });

    test('parses a failed result from JSON', () {
      final json = <String, dynamic>{
        'platform': 'twitter',
        'identity': 'fake',
        'verified': false,
        'error': 'proof not found',
        'checked_at': 1700000000,
        'cached': false,
      };
      final result = VerificationResult.fromJson(json);
      expect(result.verified, isFalse);
      expect(result.error, equals('proof not found'));
    });

    test('defaults cached to false when missing', () {
      final json = <String, dynamic>{
        'platform': 'github',
        'identity': 'octocat',
        'verified': true,
        'checked_at': 1700000000,
      };
      final result = VerificationResult.fromJson(json);
      expect(result.cached, isFalse);
    });
  });
}
