// ABOUTME: Create-account route guard that enforces invite approval

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/invite_guard_providers.dart';
import 'package:openvine/screens/auth/create_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';

class InviteProtectedCreateAccountScreen extends ConsumerWidget {
  const InviteProtectedCreateAccountScreen({super.key});

  void _redirectToInvite(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context.go(WelcomeScreen.inviteGatePath);
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(inviteClientConfigProvider);
    final inviteAccessGrant = ref.watch(inviteAccessGrantProvider);
    final authState = ref.watch(currentAuthStateProvider);

    if (authState == AuthState.authenticated && inviteAccessGrant != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(inviteAccessGrantProvider.notifier).clear();
      });
    }

    return configAsync.when(
      loading: () => const _InviteGuardLoadingPage(),
      error: (_, _) {
        if (inviteAccessGrant != null) {
          return const CreateAccountScreen();
        }

        _redirectToInvite(context);
        return const _InviteGuardLoadingPage();
      },
      data: (config) {
        final mode = config.mode;
        if (mode == OnboardingMode.open || inviteAccessGrant != null) {
          return const CreateAccountScreen();
        }

        _redirectToInvite(context);
        return const _InviteGuardLoadingPage();
      },
    );
  }
}

class _InviteGuardLoadingPage extends StatelessWidget {
  const _InviteGuardLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      body: Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
    );
  }
}
