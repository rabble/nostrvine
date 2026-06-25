// ABOUTME: Verifies upload backpressure activates only for visible playback
// ABOUTME: Covers home feed visibility and route-driven active video playback

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';

void main() {
  group('uploadBackpressureActiveProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [activeVideoIdProvider.overrideWithValue(null)],
      );
    });

    tearDown(() => container.dispose());

    test('is active for the visible home feed', () {
      container.read(activeBranchIndexProvider.notifier).state = 0;

      expect(container.read(uploadBackpressureActiveProvider), isTrue);
    });

    test('is inactive when the home feed is backgrounded', () {
      container.read(activeBranchIndexProvider.notifier).state = 1;

      expect(container.read(uploadBackpressureActiveProvider), isFalse);
    });

    test(
      'is inactive when the home feed is covered by a full-screen route',
      () {
        container.read(activeBranchIndexProvider.notifier).state = 0;
        container
            .read(shellObscuredProvider.notifier)
            .setObscured(obscured: true);

        expect(container.read(uploadBackpressureActiveProvider), isFalse);
      },
    );

    test('is inactive when an overlay pauses foreground playback', () {
      container.read(activeBranchIndexProvider.notifier).state = 0;
      container
          .read(overlayVisibilityProvider.notifier)
          .setBottomSheetOpen(true);

      expect(container.read(uploadBackpressureActiveProvider), isFalse);
    });

    test('is inactive when the app is backgrounded', () {
      container.read(activeBranchIndexProvider.notifier).state = 0;
      container.read(appForegroundProvider.notifier).setForeground(false);

      expect(container.read(uploadBackpressureActiveProvider), isFalse);
    });

    test('is active for route-driven playback outside the home feed', () {
      final container = ProviderContainer(
        overrides: [activeVideoIdProvider.overrideWithValue('video-1')],
      );
      addTearDown(container.dispose);
      container.read(activeBranchIndexProvider.notifier).state = 1;

      expect(container.read(uploadBackpressureActiveProvider), isTrue);
    });
  });
}
