// ABOUTME: Tests for SubtitleVisibility provider.
// ABOUTME: Verifies toggle behavior and per-video visibility state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/subtitle_providers.dart';

void main() {
  const videoId1 =
      'video-1-0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';
  const videoId2 =
      'video-2-0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab';

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('SubtitleVisibility', () {
    test('starts with empty map', () {
      final state = container.read(subtitleVisibilityProvider);
      expect(state, isEmpty);
    });

    test('isVisible returns false for unknown video', () {
      final notifier = container.read(subtitleVisibilityProvider.notifier);
      expect(notifier.isVisible(videoId1), isFalse);
    });

    test('toggle sets visibility to true for a video', () {
      final notifier = container.read(subtitleVisibilityProvider.notifier);
      notifier.toggle(videoId1);

      final state = container.read(subtitleVisibilityProvider);
      expect(state[videoId1], isTrue);
      expect(notifier.isVisible(videoId1), isTrue);
    });

    test('toggle twice sets visibility back to false', () {
      final notifier = container.read(subtitleVisibilityProvider.notifier);
      notifier.toggle(videoId1);
      notifier.toggle(videoId1);

      expect(notifier.isVisible(videoId1), isFalse);
    });

    test('toggles are independent per video', () {
      final notifier = container.read(subtitleVisibilityProvider.notifier);
      notifier.toggle(videoId1);

      expect(notifier.isVisible(videoId1), isTrue);
      expect(notifier.isVisible(videoId2), isFalse);

      notifier.toggle(videoId2);
      expect(notifier.isVisible(videoId1), isTrue);
      expect(notifier.isVisible(videoId2), isTrue);

      notifier.toggle(videoId1);
      expect(notifier.isVisible(videoId1), isFalse);
      expect(notifier.isVisible(videoId2), isTrue);
    });
  });
}
