// ABOUTME: Pins that curatedListsEnabledStreamProvider actually reports flag
// ABOUTME: flips through the real feature-flag provider chain — the app-shell
// ABOUTME: PeopleListsBloc has no other way to learn the flag turned off.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/curated_lists_gate.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  group('curatedListsEnabledStreamProvider', () {
    late _MockSharedPreferences prefs;

    setUp(() {
      prefs = _MockSharedPreferences();
      for (final flag in FeatureFlag.values) {
        when(() => prefs.getBool('ff_${flag.name}')).thenReturn(null);
        when(() => prefs.containsKey('ff_${flag.name}')).thenReturn(false);
        when(
          () => prefs.setBool('ff_${flag.name}', any()),
        ).thenAnswer((_) async => true);
        when(
          () => prefs.remove('ff_${flag.name}'),
        ).thenAnswer((_) async => true);
      }
    });

    // Nothing in the app `watch`es this provider — the bloc `ref.read`s it once
    // from BlocProvider.create. That is exactly the case where a listener
    // registered with `ref.listen` never fires (#6482), so the wiring is pinned
    // end to end rather than at the helper.
    test('seeds with the current value and emits on a flip', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final emitted = <bool>[];
      final subscription = container
          .read(curatedListsEnabledStreamProvider)
          .listen(emitted.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      // FF_CURATED_LISTS defaults to true.
      expect(emitted, equals([true]));

      await container
          .read(featureFlagServiceProvider)
          .setFlag(FeatureFlag.curatedLists, false);
      await pumpEventQueue();

      expect(emitted, equals([true, false]));

      await container
          .read(featureFlagServiceProvider)
          .setFlag(FeatureFlag.curatedLists, true);
      await pumpEventQueue();

      expect(emitted, equals([true, false, true]));
    });

    test('does not emit when an unrelated flag flips', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final emitted = <bool>[];
      final subscription = container
          .read(curatedListsEnabledStreamProvider)
          .listen(emitted.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await container
          .read(featureFlagServiceProvider)
          .setFlag(FeatureFlag.blueskyPublishing, true);
      await pumpEventQueue();

      expect(emitted, equals([true]));
    });
  });
}
