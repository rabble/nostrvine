// ABOUTME: Tests for SubtitleVisibility provider.
// ABOUTME: Verifies global toggle behavior for subtitle visibility.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/subtitle_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group(SubtitleVisibility, () {
    test('starts with subtitles disabled', () {
      final state = container.read(subtitleVisibilityProvider);
      expect(state, isFalse);
    });

    test('toggle enables subtitles globally', () {
      final notifier = container.read(subtitleVisibilityProvider.notifier);
      notifier.toggle();

      final state = container.read(subtitleVisibilityProvider);
      expect(state, isTrue);
    });

    test('toggle twice disables subtitles again', () {
      final notifier = container.read(subtitleVisibilityProvider.notifier);
      notifier.toggle();
      notifier.toggle();

      final state = container.read(subtitleVisibilityProvider);
      expect(state, isFalse);
    });
  });
}
