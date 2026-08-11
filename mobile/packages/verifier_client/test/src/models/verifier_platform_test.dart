// ABOUTME: VerifierPlatform tests — parsing, defaults and OAuth capability.

import 'package:test/test.dart';
import 'package:verifier_client/verifier_client.dart';

void main() {
  group(VerifierPlatform, () {
    test('parses label and supported from the platform entry', () {
      final platform = VerifierPlatform.fromJson('github', const {
        'label': 'GitHub',
        'supported': true,
      });

      expect(platform.key, equals('github'));
      expect(platform.label, equals('GitHub'));
      expect(platform.supported, isTrue);
    });

    test('falls back to the key and unsupported on a bare entry', () {
      final platform = VerifierPlatform.fromJson(
        'mystery',
        const <String, dynamic>{},
      );

      expect(platform.label, equals('mystery'));
      expect(platform.supported, isFalse);
    });

    test('reports OAuth capability per platform', () {
      const oauth = VerifierPlatform(
        key: 'twitter',
        label: 'Twitter / X',
        supported: true,
      );
      const proofOnly = VerifierPlatform(
        key: 'mastodon',
        label: 'Mastodon',
        supported: true,
      );

      expect(oauth.supportsOAuth, isTrue);
      expect(proofOnly.supportsOAuth, isFalse);
    });

    test('compares by value', () {
      const a = VerifierPlatform(
        key: 'github',
        label: 'GitHub',
        supported: true,
      );
      const b = VerifierPlatform(
        key: 'github',
        label: 'GitHub',
        supported: true,
      );
      const c = VerifierPlatform(
        key: 'github',
        label: 'GitHub',
        supported: false,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
