// ABOUTME: Create-account route guard that enforces invite approval

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_event.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/create_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';

class InviteProtectedCreateAccountScreen extends ConsumerStatefulWidget {
  const InviteProtectedCreateAccountScreen({super.key});

  @override
  ConsumerState<InviteProtectedCreateAccountScreen> createState() =>
      _InviteProtectedCreateAccountScreenState();
}

class _InviteProtectedCreateAccountScreenState
    extends ConsumerState<InviteProtectedCreateAccountScreen> {
  @override
  void initState() {
    super.initState();
    context.read<InviteGateBloc>().add(const InviteGateConfigRequested());
  }

  void _redirectToInvite(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context.go(WelcomeScreen.inviteGatePath);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(currentAuthStateProvider);
    return BlocBuilder<InviteGateBloc, InviteGateState>(
      builder: (context, state) {
        if (authState == AuthState.authenticated && state.hasAccessGrant) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<InviteGateBloc>().add(const InviteGateAccessCleared());
          });
        }

        switch (state.configStatus) {
          case InviteGateConfigStatus.initial:
          case InviteGateConfigStatus.loading:
            return const _InviteGuardLoadingPage();
          case InviteGateConfigStatus.failure:
            if (state.hasAccessGrant) {
              return const CreateAccountScreen();
            }

            _redirectToInvite(context);
            return const _InviteGuardLoadingPage();
          case InviteGateConfigStatus.success:
            final mode = state.config?.mode;
            if (mode == OnboardingMode.open || state.hasAccessGrant) {
              return const CreateAccountScreen();
            }

            _redirectToInvite(context);
            return const _InviteGuardLoadingPage();
        }
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
