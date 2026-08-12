import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';

/// Redirects the signup invite gate to create-account when invites are off.
String? inviteGateRedirectIfDisabled(
  InviteAvailabilityCubit cubit,
  GoRouterState state,
) {
  final availability = cubit.state;
  if (availability.hasResolved && !availability.isEnabled) {
    return WelcomeScreen.createAccountPath;
  }
  return null;
}

/// Redirects the signed-in invites screen to Settings when invites are off.
String? invitesScreenRedirectIfDisabled(
  InviteAvailabilityCubit cubit,
  GoRouterState state,
) {
  final availability = cubit.state;
  if (availability.hasResolved && !availability.isEnabled) {
    return SettingsScreen.path;
  }
  return null;
}
