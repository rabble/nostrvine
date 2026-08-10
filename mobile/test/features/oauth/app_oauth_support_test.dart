// ABOUTME: Tests the iOS floor for Divine's HTTPS OAuth callback.
// ABOUTME: Below 17.4 a completed session can report as a cancel.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';

void main() {
  group('iosVersionSupportsAppOAuth', () {
    test('accepts the first version with the HTTPS callback API', () {
      expect(iosVersionSupportsAppOAuth('17.4'), isTrue);
      expect(iosVersionSupportsAppOAuth('17.4.1'), isTrue);
    });

    test('accepts every later major', () {
      expect(iosVersionSupportsAppOAuth('18.0'), isTrue);
      expect(iosVersionSupportsAppOAuth('26.1'), isTrue);
    });

    test('rejects versions below the floor', () {
      expect(iosVersionSupportsAppOAuth('17.3.1'), isFalse);
      expect(iosVersionSupportsAppOAuth('16.0'), isFalse);
    });

    test('treats a bare major as .0', () {
      expect(iosVersionSupportsAppOAuth('17'), isFalse);
      expect(iosVersionSupportsAppOAuth('18'), isTrue);
    });

    test('fails closed on an unreadable version', () {
      expect(iosVersionSupportsAppOAuth(''), isFalse);
      expect(iosVersionSupportsAppOAuth('not-a-version'), isFalse);
      expect(iosVersionSupportsAppOAuth('17.x'), isFalse);
    });
  });
}
