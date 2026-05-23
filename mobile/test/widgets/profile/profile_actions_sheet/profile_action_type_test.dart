// ABOUTME: Unit tests for ProfileActionType.pending() logic
// ABOUTME: Verifies correct action list for all flag combinations

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_action_type.dart';

void main() {
  group(ProfileActionType, () {
    group('pending', () {
      test('returns both actions when anonymous without profile info', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAnonymous: true,
          hasExpiredSession: false,
          hasAnyProfileInfo: false,
        );

        expect(actions, hasLength(2));
        expect(actions[0], equals(ProfileActionType.secureAccount));
        expect(actions[1], equals(ProfileActionType.completeProfile));
      });

      test('returns only secureAccount when anonymous with profile info', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAnonymous: true,
          hasExpiredSession: false,
          hasAnyProfileInfo: true,
        );

        expect(actions, equals([ProfileActionType.secureAccount]));
      });

      test(
        'returns only completeProfile when not anonymous without profile info',
        () {
          final actions = ProfileActionType.pending(
            isOwnProfile: true,
            isAnonymous: false,
            hasExpiredSession: false,
            hasAnyProfileInfo: false,
          );

          expect(actions, equals([ProfileActionType.completeProfile]));
        },
      );

      test('returns empty when not anonymous and has profile info', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAnonymous: false,
          hasExpiredSession: false,
          hasAnyProfileInfo: true,
        );

        expect(actions, isEmpty);
      });

      test('returns empty for other profiles', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: false,
          isAnonymous: true,
          hasExpiredSession: false,
          hasAnyProfileInfo: false,
        );

        expect(actions, isEmpty);
      });

      test('shows secureAccount for anonymous even with expired session', () {
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAnonymous: true,
          hasExpiredSession: true,
          hasAnyProfileInfo: false,
        );

        expect(actions, hasLength(2));
        expect(actions[0], equals(ProfileActionType.secureAccount));
        expect(actions[1], equals(ProfileActionType.completeProfile));
      });

      test(
        'returns only secureAccount when session expired and has profile info',
        () {
          final actions = ProfileActionType.pending(
            isOwnProfile: true,
            isAnonymous: true,
            hasExpiredSession: true,
            hasAnyProfileInfo: true,
          );

          expect(actions, equals([ProfileActionType.secureAccount]));
        },
      );
    });
  });
}
