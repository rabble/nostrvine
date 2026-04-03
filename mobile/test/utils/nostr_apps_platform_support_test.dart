import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/nostr_apps_platform_support.dart';

void main() {
  group('supportsNostrAppsSandbox', () {
    test('returns false on web', () {
      expect(supportsNostrAppsSandbox(isWeb: true), isFalse);
    });

    test('returns true on non-web platforms', () {
      expect(supportsNostrAppsSandbox(isWeb: false), isTrue);
    });
  });
}
