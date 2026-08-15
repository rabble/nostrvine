// ABOUTME: Tests the route predicate that decides whether the user is
// ABOUTME: standing on their own profile.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/route_paths.dart';

const _npub =
    'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwx';
const _otherNpub =
    'npub1zyxwvutsrqponmlkjihgfedcba9876543210zyxwvutsrqponmlkjihgfedc';

void main() {
  group('isOwnProfileLocation', () {
    test('is true on the profile grid', () {
      expect(
        isOwnProfileLocation(RoutePaths.profileForNpub(_npub), _npub),
        isTrue,
      );
    });

    test('is true on the profile feed at an index', () {
      // Tapping a thumbnail pushes /profile/<npub>/<index>; the user is
      // still standing on their own profile.
      expect(
        isOwnProfileLocation(RoutePaths.profileForIndex(_npub, 3), _npub),
        isTrue,
      );
    });

    test("is false on someone else's profile", () {
      expect(
        isOwnProfileLocation(RoutePaths.profileForNpub(_otherNpub), _npub),
        isFalse,
      );
    });

    test('is false on the home feed', () {
      expect(
        isOwnProfileLocation(RoutePaths.videoFeedForIndex(0), _npub),
        isFalse,
      );
    });

    test('is false on an unknown location', () {
      // parseRoute falls back to home for anything it cannot model, which
      // must not read as "on my profile".
      expect(isOwnProfileLocation('/definitely-not-a-route', _npub), isFalse);
    });

    test('ignores a query string on the profile location', () {
      expect(
        isOwnProfileLocation(
          '${RoutePaths.profileForNpub(_npub)}?tab=likes',
          _npub,
        ),
        isTrue,
      );
    });
  });
}
