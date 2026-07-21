// ABOUTME: Tests for FeatureFlagState model managing flag values
// ABOUTME: Validates immutable state management and flag value storage

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/models/feature_flag_state.dart';

void main() {
  group('FeatureFlagState', () {
    test('should store flag values', () {
      const state = FeatureFlagState({
        FeatureFlag.enhancedAnalytics: true,
      });

      expect(state.isEnabled(FeatureFlag.enhancedAnalytics), isTrue);
    });

    test('should return false for undefined flags', () {
      const state = FeatureFlagState({});
      expect(state.isEnabled(FeatureFlag.enhancedAnalytics), isFalse);
      expect(state.isEnabled(FeatureFlag.debugTools), isFalse);
    });

    test('should be immutable', () {
      const state1 = FeatureFlagState({});
      final state2 = state1.copyWith(FeatureFlag.enhancedAnalytics, true);

      expect(state1.isEnabled(FeatureFlag.enhancedAnalytics), isFalse);
      expect(state2.isEnabled(FeatureFlag.enhancedAnalytics), isTrue);
    });

    test('should provide all flag values', () {
      const state = FeatureFlagState({
        FeatureFlag.enhancedAnalytics: true,
        FeatureFlag.debugTools: true,
      });

      final allFlags = state.allFlags;
      expect(allFlags[FeatureFlag.enhancedAnalytics], isTrue);
      expect(allFlags[FeatureFlag.debugTools], isTrue);
    });

    test('should handle copyWith for multiple flags', () {
      const state1 = FeatureFlagState({FeatureFlag.enhancedAnalytics: false});

      final state2 = state1.copyWith(FeatureFlag.enhancedAnalytics, true);
      final state3 = state2.copyWith(FeatureFlag.accountSwitching, true);

      expect(state3.isEnabled(FeatureFlag.enhancedAnalytics), isTrue);
      expect(state3.isEnabled(FeatureFlag.accountSwitching), isTrue);

      // Original states should remain unchanged
      expect(state1.isEnabled(FeatureFlag.enhancedAnalytics), isFalse);
      expect(state2.isEnabled(FeatureFlag.accountSwitching), isFalse);
    });

    test('should support equality comparison', () {
      const state1 = FeatureFlagState({
        FeatureFlag.enhancedAnalytics: true,
        FeatureFlag.debugTools: false,
      });

      const state2 = FeatureFlagState({
        FeatureFlag.enhancedAnalytics: true,
        FeatureFlag.debugTools: false,
      });

      const state3 = FeatureFlagState({
        FeatureFlag.enhancedAnalytics: false,
        FeatureFlag.debugTools: false,
      });

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });
  });
}
