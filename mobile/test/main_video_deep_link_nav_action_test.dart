// ABOUTME: Regression tests for resolveVideoDeepLinkNavAction routing decision
// ABOUTME: Verifies the same-route + autoOpenComments case that previously
// ABOUTME: caused reply notification taps to no-op when already on the video.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/screens/video_detail_screen.dart';

void main() {
  const videoId =
      'abc123def456abc123def456abc123def456abc123def456abc123def456abc123';
  final targetPath = VideoDetailScreen.pathForId(videoId);

  group('resolveVideoDeepLinkNavAction', () {
    group('same route (currentLocation == targetPath)', () {
      test(
        'returns skip when already on the video and autoOpenComments is false '
        '— duplicate link event, nothing new to do',
        () {
          final action = app.resolveVideoDeepLinkNavAction(
            currentLocation: targetPath,
            targetPath: targetPath,
            autoOpenComments: false,
          );
          expect(action, equals(app.VideoDeepLinkNavAction.skip));
        },
      );

      // Regression: a reply notification tap while already on /video/<id>
      // used to break early (skip) before the action `autoOpenComments: true`
      // could be forwarded to the route.  The comments sheet never opened.
      test(
        'returns goSameRouteWithComments when already on the video and '
        'autoOpenComments is true — reply notification tap must open sheet',
        () {
          final action = app.resolveVideoDeepLinkNavAction(
            currentLocation: targetPath,
            targetPath: targetPath,
            autoOpenComments: true,
          );
          expect(
            action,
            equals(app.VideoDeepLinkNavAction.goSameRouteWithComments),
          );
        },
      );
    });

    group('different video already showing (replacing video route)', () {
      test(
        'returns go when a different video is currently visible',
        () {
          const otherId =
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
          final otherPath = VideoDetailScreen.pathForId(otherId);

          final action = app.resolveVideoDeepLinkNavAction(
            currentLocation: otherPath,
            targetPath: targetPath,
            autoOpenComments: false,
          );
          expect(action, equals(app.VideoDeepLinkNavAction.go));
        },
      );

      test(
        'returns go with autoOpenComments when a different video is showing',
        () {
          const otherId =
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
          final otherPath = VideoDetailScreen.pathForId(otherId);

          final action = app.resolveVideoDeepLinkNavAction(
            currentLocation: otherPath,
            targetPath: targetPath,
            autoOpenComments: true,
          );
          expect(action, equals(app.VideoDeepLinkNavAction.go));
        },
      );
    });

    group('coming from a non-video route', () {
      test(
        'returns push from the home feed so back returns to the main screen',
        () {
          final action = app.resolveVideoDeepLinkNavAction(
            currentLocation: '/home/0',
            targetPath: targetPath,
            autoOpenComments: false,
          );
          expect(action, equals(app.VideoDeepLinkNavAction.push));
        },
      );

      test(
        'returns push even when autoOpenComments is true',
        () {
          final action = app.resolveVideoDeepLinkNavAction(
            currentLocation: '/home/0',
            targetPath: targetPath,
            autoOpenComments: true,
          );
          expect(action, equals(app.VideoDeepLinkNavAction.push));
        },
      );

      test(
        'returns push from welcome / unauthenticated route',
        () {
          final action = app.resolveVideoDeepLinkNavAction(
            currentLocation: '/welcome',
            targetPath: targetPath,
            autoOpenComments: false,
          );
          expect(action, equals(app.VideoDeepLinkNavAction.push));
        },
      );
    });
  });
}
