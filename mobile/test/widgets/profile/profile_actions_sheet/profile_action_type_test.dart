// ABOUTME: Unit tests for ProfileActionType.pending() logic
// ABOUTME: Verifies correct action list for all flag combinations

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/profile_actions_sheet/profile_action_type.dart';

void main() {
  group(ProfileActionType, () {
    group('pending', () {
      test('never emits secureAccount while the upgrade is paused (#3359)', () {
        // The secureAccount prompt is paused until the key-safe
        // proof-of-possession upgrade lands (#3786), so pending() never emits
        // it regardless of anonymity / profile / session state.
        for (final hasProfileInfo in [false, true]) {
          for (final expired in [false, true]) {
            final actions = ProfileActionType.pending(
              isOwnProfile: true,
              isAnonymous: true,
              hasExpiredSession: expired,
              hasAnyProfileInfo: hasProfileInfo,
            );
            expect(actions, isNot(contains(ProfileActionType.secureAccount)));
          }
        }
      });

      test(
        'emits only completeProfile for an anonymous user without profile info',
        () {
          // Was [secureAccount, completeProfile] before #3359.
          final actions = ProfileActionType.pending(
            isOwnProfile: true,
            isAnonymous: true,
            hasExpiredSession: false,
            hasAnyProfileInfo: false,
          );

          expect(actions, equals([ProfileActionType.completeProfile]));
        },
      );

      test('is empty for an anonymous user who has profile info (#3359)', () {
        // Was [secureAccount] before #3359 paused the upgrade prompt.
        final actions = ProfileActionType.pending(
          isOwnProfile: true,
          isAnonymous: true,
          hasExpiredSession: false,
          hasAnyProfileInfo: true,
        );

        expect(actions, isEmpty);
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

      test(
        'is empty for an anonymous user with profile info and expired session '
        '(#3359)',
        () {
          // Was [secureAccount] before #3359 paused the upgrade prompt.
          final actions = ProfileActionType.pending(
            isOwnProfile: true,
            isAnonymous: true,
            hasExpiredSession: true,
            hasAnyProfileInfo: true,
          );

          expect(actions, isEmpty);
        },
      );
    });
  });
}
