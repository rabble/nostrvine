// ABOUTME: Gateway screen for existing users to choose their login method
// ABOUTME: Options: Login/Register with diVine, Import Nostr Key, Signer App, or Amber (Android)

import 'dart:io' show Platform;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show AndroidPlugin;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/screens/welcome_screen.dart';

class LoginOptionsScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const String routeName = 'login-options';

  /// Route path for this screen.
  static const String path = '/login-options';

  const LoginOptionsScreen({super.key});

  @override
  ConsumerState<LoginOptionsScreen> createState() => _LoginOptionsScreenState();
}

class _LoginOptionsScreenState extends ConsumerState<LoginOptionsScreen> {
  bool _isConnectingAmber = false;

  Future<void> _connectWithAmber() async {
    setState(() => _isConnectingAmber = true);

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.connectWithAmber();

      if (!mounted) return;

      if (result.success) {
        // Navigate to main app - router will handle auth state
        context.go('/');
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? 'Failed to connect with Amber',
            ),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnectingAmber = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable content fills entire safe area
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Space for back button overlay
                  const SizedBox(height: 72),

                  // Header
                  Text(
                    'Sign in',
                    style: VineTheme.headlineLargeFont(
                      color: VineTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how you want to sign in',
                    style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
                  ),
                  const SizedBox(height: 48),

                  // Primary: Login/Register with diVine
                  DivineButton(
                    label: 'Continue with email',
                    leadingIcon: DivineIconName.envelope,
                    expanded: true,
                    onPressed: () => context.push(WelcomeScreen.authNativePath),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Login or create a new account',
                      style: VineTheme.bodySmallFont(
                        color: VineTheme.onSurfaceMuted,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: VineTheme.outlineMuted,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or',
                          style: VineTheme.bodyMediumFont(
                            color: VineTheme.onSurfaceMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: VineTheme.outlineMuted,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Secondary: Import Nostr Key
                  DivineButton(
                    label: 'Enter Nostr key',
                    type: DivineButtonType.secondary,
                    leadingIcon: DivineIconName.key,
                    expanded: true,
                    onPressed: () => context.push(KeyImportScreen.path),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Already have an nsec? Import it here',
                      style: VineTheme.bodySmallFont(
                        color: VineTheme.onSurfaceMuted,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tertiary: Connect with Signer App (NIP-46)
                  DivineButton(
                    label: 'Connect with Signer App',
                    type: DivineButtonType.secondary,
                    leadingIcon: DivineIconName.linkSimple,
                    expanded: true,
                    onPressed: () => context.push(NostrConnectScreen.path),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Use Amber, nsecBunker, or other '
                      'NIP-46 signers',
                      style: VineTheme.bodySmallFont(
                        color: VineTheme.onSurfaceMuted,
                      ),
                    ),
                  ),

                  // Amber button (Android only)
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 24),
                    _AmberButton(
                      isConnecting: _isConnectingAmber,
                      onPressed: _connectWithAmber,
                    ),
                  ],
                ],
              ),
            ),

            // Back button overlays top-left
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: DivineIconButton(
                icon: DivineIconName.caretLeft,
                type: DivineIconButtonType.secondary,
                size: DivineIconButtonSize.small,
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Amber sign-in button that only appears when Amber is installed.
class _AmberButton extends StatelessWidget {
  const _AmberButton({required this.isConnecting, required this.onPressed});

  final bool isConnecting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool?>(
      future: AndroidPlugin.existAndroidNostrSigner(),
      builder: (context, snapshot) {
        // Don't show button if Amber is not installed
        if (snapshot.data != true) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            DivineButton(
              label: isConnecting ? 'Connecting...' : 'Sign with Amber',
              type: DivineButtonType.secondary,
              leadingIcon: DivineIconName.shieldCheck,
              expanded: true,
              isLoading: isConnecting,
              onPressed: onPressed,
            ),
            const SizedBox(height: 12),
            Text(
              'Use your Amber signer app',
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceMuted),
            ),
          ],
        );
      },
    );
  }
}
