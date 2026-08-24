import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:openvine/models/invite_availability.dart';

void main() {
  group(InviteAvailabilityState, () {
    test('defaults to disabled before the server value resolves', () {
      const state = InviteAvailabilityState();
      expect(state.hasResolved, isFalse);
      expect(state.isEnabled, isFalse);
    });

    test('enables invites for invite_code_required', () {
      const state = InviteAvailabilityState(
        hasResolved: true,
        serverMode: OnboardingMode.inviteCodeRequired,
      );
      expect(state.isEnabled, isTrue);
    });

    test('disables invites for open', () {
      const state = InviteAvailabilityState(
        hasResolved: true,
        serverMode: OnboardingMode.open,
      );
      expect(state.isEnabled, isFalse);
    });

    test('defaults unknown or missing server values to disabled', () {
      const unknown = InviteAvailabilityState(hasResolved: true);
      expect(unknown.isEnabled, isFalse);
    });

    test('defaults resolved config to open when server mode is missing', () {
      const state = InviteAvailabilityState(hasResolved: true);
      expect(state.resolvedConfig.mode, OnboardingMode.open);
    });

    test('force enabled wins over a disabled server value', () {
      const state = InviteAvailabilityState(
        hasResolved: true,
        serverMode: OnboardingMode.open,
        developerOverride: InviteAvailabilityOverride.forceEnabled,
      );
      expect(state.isEnabled, isTrue);
    });

    test('force disabled wins over an enabled server value', () {
      const state = InviteAvailabilityState(
        hasResolved: true,
        serverMode: OnboardingMode.inviteCodeRequired,
        developerOverride: InviteAvailabilityOverride.forceDisabled,
      );
      expect(state.isEnabled, isFalse);
    });

    test('use server follows the loaded onboarding mode', () {
      const enabled = InviteAvailabilityState(
        hasResolved: true,
        serverMode: OnboardingMode.inviteCodeRequired,
      );
      const disabled = InviteAvailabilityState(
        hasResolved: true,
        serverMode: OnboardingMode.open,
      );
      expect(enabled.isEnabled, isTrue);
      expect(disabled.isEnabled, isFalse);
    });
  });
}
