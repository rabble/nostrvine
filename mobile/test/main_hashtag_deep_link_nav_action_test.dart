// ABOUTME: Regression tests for resolveHashtagDeepLinkNavAction routing decision
// ABOUTME: Verifies hashtag deep links push (keeping the stack), go (replacing
// ABOUTME: an existing hashtag route), or skip (dedup) instead of always
// ABOUTME: calling router.go() which obliterated the navigation stack.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/screens/hashtag_screen_router.dart';

void main() {
  final targetPath = HashtagScreenRouter.pathForTag('cats');

  group('resolveHashtagDeepLinkNavAction', () {
    group('same route (currentLocation == targetPath)', () {
      test(
        'returns skip when already on the hashtag — duplicate link event, '
        'nothing new to do',
        () {
          final action = app.resolveHashtagDeepLinkNavAction(
            currentLocation: targetPath,
            targetPath: targetPath,
          );
          expect(action, equals(app.HashtagDeepLinkNavAction.skip));
        },
      );

      test(
        'returns skip when already on a percent-encoded hashtag route',
        () {
          // pathForTag percent-encodes, so both sides carry the encoded form.
          final encodedPath = HashtagScreenRouter.pathForTag('çay keyfi');
          final action = app.resolveHashtagDeepLinkNavAction(
            currentLocation: encodedPath,
            targetPath: encodedPath,
          );
          expect(action, equals(app.HashtagDeepLinkNavAction.skip));
        },
      );
    });

    group('a different hashtag is already showing (replacing in-place)', () {
      test(
        'returns go when another hashtag is currently visible',
        () {
          final otherPath = HashtagScreenRouter.pathForTag('dogs');

          final action = app.resolveHashtagDeepLinkNavAction(
            currentLocation: otherPath,
            targetPath: targetPath,
          );
          expect(action, equals(app.HashtagDeepLinkNavAction.go));
        },
      );

      test(
        'returns go when a percent-encoded hashtag is currently visible',
        () {
          final otherPath = HashtagScreenRouter.pathForTag('çay keyfi');

          final action = app.resolveHashtagDeepLinkNavAction(
            currentLocation: otherPath,
            targetPath: targetPath,
          );
          expect(action, equals(app.HashtagDeepLinkNavAction.go));
        },
      );
    });

    group('coming from a non-hashtag route', () {
      // Regression: a hashtag deep link from the home feed used to call
      // router.go(), wiping the navigation stack and leaving no way back.
      test(
        'returns push from the home feed so back returns to the main screen',
        () {
          final action = app.resolveHashtagDeepLinkNavAction(
            currentLocation: '/home/0',
            targetPath: targetPath,
          );
          expect(action, equals(app.HashtagDeepLinkNavAction.push));
        },
      );

      test(
        'returns push from a settings / mid-flow route so back returns there',
        () {
          final action = app.resolveHashtagDeepLinkNavAction(
            currentLocation: '/settings',
            targetPath: targetPath,
          );
          expect(action, equals(app.HashtagDeepLinkNavAction.push));
        },
      );

      test(
        'returns push from a video route (cross-type navigation)',
        () {
          final action = app.resolveHashtagDeepLinkNavAction(
            currentLocation:
                '/video/abc123def456abc123def456abc123def456abc123def456abc123def456ab',
            targetPath: targetPath,
          );
          expect(action, equals(app.HashtagDeepLinkNavAction.push));
        },
      );
    });
  });
}
