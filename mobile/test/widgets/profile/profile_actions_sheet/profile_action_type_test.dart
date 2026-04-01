// ABOUTME: Unit tests for ProfileActionType.pending() logic
// ABOUTME: Verifies correct action list for all flag combinations

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_action_type.dart';

void main() {
  group(ProfileActionType, () {
    group('pending', () {
      test('returns both actions when anonymous without custom name', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAnonymous: true,
          hasExpiredSession: false,
          hasProfile: true,
          hasCustomName: false,
        );

        expect(actions, hasLength(2));
        expect(actions[0], equals(ProfileActionType.secureAccount));
        expect(actions[1], equals(ProfileActionType.completeProfile));
      });

      test('returns only secureAccount when anonymous with custom name', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAnonymous: true,
          hasExpiredSession: false,
          hasProfile: true,
          hasCustomName: true,
        );

        expect(actions, equals([ProfileActionType.secureAccount]));
      });

      test('returns only completeProfile when not anonymous without name', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAnonymous: false,
          hasExpiredSession: false,
          hasProfile: true,
          hasCustomName: false,
        );

        expect(actions, equals([ProfileActionType.completeProfile]));
      });

      test('returns empty when not anonymous and has custom name', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAnonymous: false,
          hasExpiredSession: false,
          hasProfile: true,
          hasCustomName: true,
        );

        expect(actions, isEmpty);
      });

      test('returns empty for other profiles', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: false,
          isAnonymous: true,
          hasExpiredSession: false,
          hasProfile: true,
          hasCustomName: false,
        );

        expect(actions, isEmpty);
      });

      test('excludes secureAccount when session is expired', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAnonymous: true,
          hasExpiredSession: true,
          hasProfile: true,
          hasCustomName: false,
        );

        expect(actions, equals([ProfileActionType.completeProfile]));
      });

      test('shows completeProfile even when profile is not loaded', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAnonymous: true,
          hasExpiredSession: false,
          hasProfile: false,
          hasCustomName: false,
        );

        expect(actions, hasLength(2));
        expect(actions[0], equals(ProfileActionType.secureAccount));
        expect(actions[1], equals(ProfileActionType.completeProfile));
      });

      test(
        'returns empty when session expired and profile has custom name',
        () {
          final actions = ProfileActionType.pending(
            isOwnProfile: true,
            isAnonymous: true,
            hasExpiredSession: true,
            hasProfile: true,
            hasCustomName: true,
          );

          expect(actions, isEmpty);
        },
      );
    });
  });
}
