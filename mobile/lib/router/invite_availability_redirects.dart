import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';

/// Redirects the signup invite gate to create-account when invites are off.
String? inviteGateRedirectIfDisabled(
  BuildContext context,
  GoRouterState state,
) {
  final availability = context.read<InviteAvailabilityCubit?>()?.state;
  if (availability != null &&
      availability.hasResolved &&
      !availability.isEnabled) {
    return WelcomeScreen.createAccountPath;
  }
  return null;
}

/// Redirects the signed-in invites screen to Settings when invites are off.
String? invitesScreenRedirectIfDisabled(
  BuildContext context,
  GoRouterState state,
) {
  final availability = context.read<InviteAvailabilityCubit?>()?.state;
  if (availability != null &&
      availability.hasResolved &&
      !availability.isEnabled) {
    return SettingsScreen.path;
  }
  return null;
}
