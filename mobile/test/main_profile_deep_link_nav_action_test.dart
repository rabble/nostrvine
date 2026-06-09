// ABOUTME: Regression tests for resolveProfileDeepLinkNavAction routing decision
// ABOUTME: Verifies profile deep links push (keeping the stack), go (replacing
// ABOUTME: an existing profile route), or skip (dedup) instead of always
// ABOUTME: calling router.go() which obliterated the navigation stack.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/screens/profile_screen_router.dart';

void main() {
  const npub =
      'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwx';
  final targetPath = ProfileScreenRouter.pathForNpub(npub);

  group('resolveProfileDeepLinkNavAction', () {
    group('same route (currentLocation == targetPath)', () {
      test(
        'returns skip when already on the profile — duplicate link event, '
        'nothing new to do',
        () {
          final action = app.resolveProfileDeepLinkNavAction(
            currentLocation: targetPath,
            targetPath: targetPath,
          );
          expect(action, equals(app.ProfileDeepLinkNavAction.skip));
        },
      );

      test(
        'returns skip when already on the feed-mode profile route',
        () {
          final feedPath = ProfileScreenRouter.pathForIndex(npub, 2);
          final action = app.resolveProfileDeepLinkNavAction(
            currentLocation: feedPath,
            targetPath: feedPath,
          );
          expect(action, equals(app.ProfileDeepLinkNavAction.skip));
        },
      );
    });

    group('a different profile is already showing (replacing in-place)', () {
      test(
        'returns go when another profile is currently visible',
        () {
          const otherNpub =
              'npub1zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz';
          final otherPath = ProfileScreenRouter.pathForNpub(otherNpub);

          final action = app.resolveProfileDeepLinkNavAction(
            currentLocation: otherPath,
            targetPath: targetPath,
          );
          expect(action, equals(app.ProfileDeepLinkNavAction.go));
        },
      );

      test(
        'returns go when moving from another profile feed route to a profile',
        () {
          const otherNpub =
              'npub1zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz';
          final otherFeedPath = ProfileScreenRouter.pathForIndex(otherNpub, 1);

          final action = app.resolveProfileDeepLinkNavAction(
            currentLocation: otherFeedPath,
            targetPath: targetPath,
          );
          expect(action, equals(app.ProfileDeepLinkNavAction.go));
        },
      );
    });

    group('coming from a non-profile route', () {
      // Regression: a profile deep link from the home feed used to call
      // router.go(), wiping the navigation stack and leaving no way back.
      test(
        'returns push from the home feed so back returns to the main screen',
        () {
          final action = app.resolveProfileDeepLinkNavAction(
            currentLocation: '/home/0',
            targetPath: targetPath,
          );
          expect(action, equals(app.ProfileDeepLinkNavAction.push));
        },
      );

      test(
        'returns push from a settings / mid-flow route so back returns there',
        () {
          final action = app.resolveProfileDeepLinkNavAction(
            currentLocation: '/settings',
            targetPath: targetPath,
          );
          expect(action, equals(app.ProfileDeepLinkNavAction.push));
        },
      );

      test(
        'returns push from a video route (cross-type navigation)',
        () {
          final action = app.resolveProfileDeepLinkNavAction(
            currentLocation: '/video/abc123',
            targetPath: targetPath,
          );
          expect(action, equals(app.ProfileDeepLinkNavAction.push));
        },
      );
    });
  });
}
