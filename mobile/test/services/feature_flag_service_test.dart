// ABOUTME: Tests for FeatureFlagService managing feature flag state and persistence
// ABOUTME: Validates initialization, flag management, persistence, and state notifications

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  group('FeatureFlagService', () {
    late _MockSharedPreferences mockPrefs;
    late FeatureFlagService service;

    setUp(() {
      mockPrefs = _MockSharedPreferences();

      // Set up default stubs for all flags
      for (final flag in FeatureFlag.values) {
        when(() => mockPrefs.getBool('ff_${flag.name}')).thenReturn(null);
        when(
          () => mockPrefs.setBool('ff_${flag.name}', any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockPrefs.remove('ff_${flag.name}'),
        ).thenAnswer((_) async => true);
        when(() => mockPrefs.containsKey('ff_${flag.name}')).thenReturn(false);
      }

      service = FeatureFlagService(mockPrefs, const BuildConfiguration());
    });

    group('initialization', () {
      test('should load saved flags from preferences', () async {
        when(() => mockPrefs.getBool('ff_enhancedAnalytics')).thenReturn(true);

        await service.initialize();

        expect(service.isEnabled(FeatureFlag.enhancedAnalytics), isTrue);
        expect(service.isEnabled(FeatureFlag.accountSwitching), isFalse);
      });

      test('should use build defaults when no saved preference', () async {
        when(() => mockPrefs.getBool(any())).thenReturn(null);

        await service.initialize();

        expect(
          service.isEnabled(FeatureFlag.debugTools),
          equals(const BuildConfiguration().getDefault(FeatureFlag.debugTools)),
        );
      });

      test('should prefer user settings over build defaults', () async {
        // Build default is false, user set to true
        when(() => mockPrefs.getBool('ff_enhancedAnalytics')).thenReturn(true);

        await service.initialize();

        expect(service.isEnabled(FeatureFlag.enhancedAnalytics), isTrue);
      });

      test(
        'ignores persisted internal flag overrides when internal access is off',
        () async {
          when(() => mockPrefs.getBool('ff_lightMode')).thenReturn(true);
          when(() => mockPrefs.containsKey('ff_lightMode')).thenReturn(true);

          await service.initialize();

          expect(service.isEnabled(FeatureFlag.lightMode), isFalse);
          expect(service.hasUserOverride(FeatureFlag.lightMode), isFalse);
          // Ignored, not deleted — the choice is honoured again if the flag is
          // promoted back to a user audience or internal access is restored.
          verifyNever(() => mockPrefs.remove('ff_lightMode'));
        },
      );

      test(
        'preserves internal flag overrides when internal access is on',
        () async {
          service = FeatureFlagService(
            mockPrefs,
            const BuildConfiguration(),
            canOverrideInternalFlags: () => true,
          );
          when(() => mockPrefs.getBool('ff_lightMode')).thenReturn(true);
          when(() => mockPrefs.containsKey('ff_lightMode')).thenReturn(true);

          await service.initialize();

          expect(service.isEnabled(FeatureFlag.lightMode), isTrue);
          expect(service.hasUserOverride(FeatureFlag.lightMode), isTrue);
          verifyNever(() => mockPrefs.remove('ff_lightMode'));
        },
      );

      test(
        'keeps user-facing flag overrides when internal access is off',
        () async {
          when(
            () => mockPrefs.getBool('ff_enhancedAnalytics'),
          ).thenReturn(true);
          when(
            () => mockPrefs.containsKey('ff_enhancedAnalytics'),
          ).thenReturn(true);

          await service.initialize();

          expect(service.isEnabled(FeatureFlag.enhancedAnalytics), isTrue);
          expect(
            service.hasUserOverride(FeatureFlag.enhancedAnalytics),
            isTrue,
          );
          verifyNever(() => mockPrefs.remove('ff_enhancedAnalytics'));
        },
      );
    });

    group('flag management', () {
      test('should save flag changes to preferences', () async {
        await service.setFlag(FeatureFlag.enhancedAnalytics, true);

        verify(() => mockPrefs.setBool('ff_enhancedAnalytics', true)).called(1);
      });

      test(
        'should not persist internal flags when internal access is off',
        () async {
          await service.setFlag(FeatureFlag.lightMode, true);

          verifyNever(() => mockPrefs.setBool('ff_lightMode', true));
          verifyNever(() => mockPrefs.remove('ff_lightMode'));
          expect(service.isEnabled(FeatureFlag.lightMode), isFalse);
        },
      );

      test(
        'should persist internal flags when internal access is on',
        () async {
          service = FeatureFlagService(
            mockPrefs,
            const BuildConfiguration(),
            canOverrideInternalFlags: () => true,
          );

          await service.setFlag(FeatureFlag.lightMode, true);

          verify(() => mockPrefs.setBool('ff_lightMode', true)).called(1);
          expect(service.isEnabled(FeatureFlag.lightMode), isTrue);
        },
      );

      test('should notify listeners on flag change', () async {
        // SKIP: Service refactored to use Riverpod instead of ChangeNotifier
        // Listener notification is now handled by Riverpod providers
      }, skip: true);

      test('should reset flag to build default', () async {
        when(
          () => mockPrefs.remove('ff_enhancedAnalytics'),
        ).thenAnswer((_) async => true);

        await service.setFlag(FeatureFlag.enhancedAnalytics, true);
        await service.resetFlag(FeatureFlag.enhancedAnalytics);

        verify(() => mockPrefs.remove('ff_enhancedAnalytics')).called(1);
        expect(
          service.isEnabled(FeatureFlag.enhancedAnalytics),
          equals(
            const BuildConfiguration().getDefault(
              FeatureFlag.enhancedAnalytics,
            ),
          ),
        );
      });

      test('should reset all flags', () async {
        when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

        await service.setFlag(FeatureFlag.enhancedAnalytics, true);
        await service.setFlag(FeatureFlag.accountSwitching, true);

        await service.resetAllFlags();

        for (final flag in FeatureFlag.values) {
          verify(() => mockPrefs.remove('ff_${flag.name}')).called(1);
        }
      });
    });

    group('state queries', () {
      test('exposes light mode experiment metadata', () {
        final lightMode = service.getFlagMetadata(FeatureFlag.lightMode);
        final adaptiveMedia = service.getFlagMetadata(
          FeatureFlag.adaptiveMediaChrome,
        );

        expect(lightMode.flag.displayName, equals('Light Mode'));
        expect(adaptiveMedia.flag.displayName, equals('Adaptive Media Chrome'));
        expect(lightMode.isEnabled, isFalse);
        expect(adaptiveMedia.isEnabled, isFalse);
      });

      test('should identify user overrides', () async {
        when(
          () => mockPrefs.containsKey('ff_enhancedAnalytics'),
        ).thenReturn(true);

        expect(service.hasUserOverride(FeatureFlag.enhancedAnalytics), isTrue);
        expect(service.hasUserOverride(FeatureFlag.accountSwitching), isFalse);
      });

      test('should provide flag metadata', () {
        final metadata = service.getFlagMetadata(FeatureFlag.enhancedAnalytics);

        expect(metadata.flag, equals(FeatureFlag.enhancedAnalytics));
        expect(metadata.isEnabled, isNotNull);
        expect(metadata.hasUserOverride, isNotNull);
        expect(metadata.buildDefault, isNotNull);
      });
    });

    group('state management', () {
      test('should return current state', () {
        final state = service.currentState;
        expect(state, isNotNull);

        // Should have values for all flags
        for (final flag in FeatureFlag.values) {
          expect(state.allFlags.containsKey(flag), isTrue);
        }
      });

      test('should update state when flags change', () async {
        final initialState = service.currentState;

        await service.setFlag(FeatureFlag.enhancedAnalytics, true);

        final newState = service.currentState;
        expect(newState, isNot(equals(initialState)));
        expect(newState.isEnabled(FeatureFlag.enhancedAnalytics), isTrue);
      });
    });
  });
}
