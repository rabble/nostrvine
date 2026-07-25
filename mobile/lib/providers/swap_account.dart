// ABOUTME: Orchestrates an in-place account switch — build a container, sign it
// ABOUTME: in as the target account, then swap; roll back on failure.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';

/// Signs [container]'s fresh [AuthService] in as [account].
///
/// Reuses the existing `signInForAccount` — the container gets its own
/// `AuthService` instance, so the sign-in's global-session mutation lands on
/// the new instance, never the live one. That is what lets the in-place swap
/// skip the side-effect-free `activate()` refactor (design §8.2 correction).
typedef AccountSignIn =
    Future<void> Function(ProviderContainer container, KnownAccount account);

Future<void> _defaultSignIn(
  ProviderContainer container,
  KnownAccount account,
) async {
  // A swapped-in container does not run the startup coordinator, so give it the
  // same per-container prerequisites a fresh launch establishes before auth.
  // EnvironmentService defaults to production and applies any persisted
  // override here, so the new account's signer and relays target the right
  // environment rather than whatever an uninitialised service would default to.
  // (NostrService / relay connections still come up lazily once
  // signInForAccount authenticates — same as a cold launch.)
  await container
      .read(environmentServiceProvider)
      .initialize(sharedPreferences: container.read(sharedPreferencesProvider));
  await container
      .read(authServiceProvider)
      .signInForAccount(account.pubkeyHex, account.authSource);
}

/// Switches the live app to [account] in place: builds a new container on the
/// shared [deviceScope], signs it in, and swaps it in via [controller].
///
/// Prove-then-commit: nothing user-visible changes until the new account's
/// sign-in succeeds. On failure the half-built container is disposed and the
/// current account's container is left untouched — the rollback the previous
/// welcome-bounce flow could not guarantee (#4623). Rethrows so the caller can
/// surface a "couldn't switch" affordance.
///
/// [signIn] is injectable for testing; production uses [signInForAccount].
Future<void> swapAccount({
  required DeviceScope deviceScope,
  required AccountSwitchController controller,
  required KnownAccount account,
  AccountSignIn signIn = _defaultSignIn,
}) async {
  final container = buildAccountContainer(deviceScope);
  try {
    await signIn(container, account);
  } catch (_) {
    container.dispose();
    rethrow;
  }
  await controller.swapTo(container);
}
