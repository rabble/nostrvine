// ABOUTME: Secure-account upgrade entry point. The key-importing upgrade was
// ABOUTME: removed (#3359); shows a paused notice until #3786 restores it.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/auth_back_button.dart';

/// Secure-account upgrade screen.
///
/// The email/password upgrade used to export the user's local nsec and send it
/// to Keycast over the wire — in the registration request body and embedded in
/// the PKCE `code_verifier` — leaking the private key (#3359). That path is
/// removed entirely.
///
/// Until the key-safe proof-of-possession registration lands (#3786), this
/// screen shows a notice instead of the registration form. Falling through to
/// the server's auto-generate path would silently re-create the user's
/// identity under a new server-managed key (and wipe their local social-graph
/// caches via `shouldClearDataForUser`), so the upgrade is paused rather than
/// regressed.
// TODO(#3786): restore the secure-account upgrade via proof-of-possession.
class SecureAccountScreen extends StatelessWidget {
  const SecureAccountScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'secure-account';

  /// Path for this route.
  static const path = '/secure-account';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const AuthBackButton(),
              const SizedBox(height: 32),
              Text(
                l10n.authSecureAccountTitle,
                style: VineTheme.headlineLargeFont(),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.authSecureAccountUnavailableMessage,
                style: VineTheme.bodyLargeFont(color: VineTheme.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
