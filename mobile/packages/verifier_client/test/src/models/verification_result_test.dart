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

    group('code', () {
      test('parses the verifier rejection code when one is sent', () {
        final result = VerificationResult.fromJson(const {
          'platform': 'discord',
          'identity': 'alice',
          'verified': false,
          'checked_at': 1,
          'cached': false,
          'error': 'Message not found — check the message link or ID',
          'code': 'discord_message_not_found',
        });

        expect(result.code, 'discord_message_not_found');
      });

      test('is null when the verifier omits it', () {
        final result = VerificationResult.fromJson(const {
          'platform': 'discord',
          'identity': 'alice',
          'verified': false,
          'checked_at': 1,
          'cached': false,
        });

        expect(result.code, isNull);
      });

      test('is part of equality, so a changed reason is a changed result', () {
        VerificationResult withCode(String? code) => VerificationResult(
          platform: 'discord',
          identity: 'alice',
          verified: false,
          checkedAt: 1,
          cached: false,
          code: code,
        );

        expect(
          withCode('discord_bot_no_access'),
          withCode('discord_bot_no_access'),
        );
        expect(
          withCode('discord_bot_no_access'),
          isNot(withCode('discord_message_not_found')),
        );
      });
    });
  });
}
