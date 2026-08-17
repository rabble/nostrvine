// ABOUTME: Tests for the shared Divine User-Agent builder.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('buildDivineUserAgent', () {
    test('includes app version and platform', () {
      expect(
        buildDivineUserAgent(appVersion: '1.0.20', platform: 'iOS'),
        'Divine-Mobile/1.0.20 (iOS)',
      );
      expect(
        buildDivineUserAgent(appVersion: '1.0.20', platform: 'Android'),
        'Divine-Mobile/1.0.20 (Android)',
      );
    });

    test('falls back to the detected platform when none is given', () {
      final userAgent = buildDivineUserAgent(appVersion: '1.0.20');
      expect(
        userAgent,
        matches(RegExp(r'^Divine-Mobile/1\.0\.20 \(\w[\w.]*\)$')),
      );
    });

    test('falls back to an unknown marker when no version is given', () {
      expect(
        buildDivineUserAgent(platform: 'iOS'),
        'Divine-Mobile/unknown (iOS)',
      );
    });

    test('never returns the historical hardcoded literals', () {
      for (final platform in ['iOS', 'Android', 'Web']) {
        final userAgent = buildDivineUserAgent(
          appVersion: '1.0.20',
          platform: platform,
        );
        expect(userAgent, isNot('OpenVine-Mobile/1.0'));
        expect(userAgent, isNot('divine-Mobile/1.0'));
      }
    });
  });
}
