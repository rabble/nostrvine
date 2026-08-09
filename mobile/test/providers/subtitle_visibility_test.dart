// ABOUTME: Tests for SubtitleVisibility provider.
// ABOUTME: Verifies default-on and persisted global subtitle visibility.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const videoA =
      'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
  const videoB =
      'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a1';

  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group(SubtitleVisibility, () {
    test('defaults to captions enabled when no preference is stored', () {
      final state = container.read(subtitleVisibilityProvider);
      expect(state, isTrue);
    });

    test('restores a stored disabled preference on initialization', () async {
      await prefs.setBool('subtitle_visibility_enabled', false);
      container.dispose();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      final state = container.read(subtitleVisibilityProvider);
      expect(state, isFalse);
    });

    test('toggle persists disabling captions globally', () {
      final notifier = container.read(subtitleVisibilityProvider.notifier);
      notifier.toggle();

      final state = container.read(subtitleVisibilityProvider);
      expect(state, isFalse);
      expect(prefs.getBool('subtitle_visibility_enabled'), isFalse);
    });

    test('toggle persists enabling captions globally', () async {
      await prefs.setBool('subtitle_visibility_enabled', false);
      container.dispose();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      final notifier = container.read(subtitleVisibilityProvider.notifier);
      notifier.toggle();
      final state = container.read(subtitleVisibilityProvider);
      expect(state, isTrue);
      expect(prefs.getBool('subtitle_visibility_enabled'), isTrue);
    });
  });

  group(SubtitleVisibilityOverrideNotifier, () {
    test('defaults each video to the persisted global preference', () async {
      await prefs.setBool('subtitle_visibility_enabled', false);
      container.dispose();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      expect(
        container.read(subtitleVisibilityForVideoProvider(videoA)),
        isFalse,
      );
      expect(
        container.read(subtitleVisibilityForVideoProvider(videoB)),
        isFalse,
      );
    });

    test('sets a non-persisted visibility override for one video', () {
      container
          .read(subtitleVisibilityOverrideProvider.notifier)
          .setForVideo(videoA, false);

      expect(
        container.read(subtitleVisibilityForVideoProvider(videoA)),
        isFalse,
      );
      expect(
        container.read(subtitleVisibilityForVideoProvider(videoB)),
        isTrue,
      );
      expect(container.read(subtitleVisibilityProvider), isTrue);
      expect(prefs.getBool('subtitle_visibility_enabled'), isNull);
    });

    test('replaces the active override when another video is toggled', () {
      final notifier = container.read(
        subtitleVisibilityOverrideProvider.notifier,
      );

      notifier.setForVideo(videoA, false);
      notifier.toggleForVideo(videoB);

      expect(container.read(subtitleVisibilityOverrideProvider), (
        videoId: videoB,
        visible: false,
      ));
      expect(
        container.read(subtitleVisibilityForVideoProvider(videoA)),
        isTrue,
      );
      expect(
        container.read(subtitleVisibilityForVideoProvider(videoB)),
        isFalse,
      );
      expect(prefs.getBool('subtitle_visibility_enabled'), isNull);
    });

    test('clears overrides when the active video changes or exits', () {
      final notifier = container.read(
        subtitleVisibilityOverrideProvider.notifier,
      );

      notifier.setForVideo(videoA, false);
      notifier.clearUnlessVideo(videoA);
      expect(
        container.read(subtitleVisibilityForVideoProvider(videoA)),
        isFalse,
      );

      notifier.clearUnlessVideo(videoB);
      expect(container.read(subtitleVisibilityOverrideProvider), isNull);
      expect(
        container.read(subtitleVisibilityForVideoProvider(videoA)),
        isTrue,
      );

      notifier.setForVideo(videoB, false);
      notifier.clear();
      expect(container.read(subtitleVisibilityOverrideProvider), isNull);
      expect(
        container.read(subtitleVisibilityForVideoProvider(videoB)),
        isTrue,
      );
    });
  });
}
