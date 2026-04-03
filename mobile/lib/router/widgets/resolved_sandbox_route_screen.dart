// ABOUTME: Resolves a NostrAppDirectoryEntry by ID and renders the
// ABOUTME: sandbox screen once the entry is available.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/sandbox_route/sandbox_route_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/widgets/missing_sandbox_app_screen.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';

/// Resolves a [NostrAppDirectoryEntry] by ID and renders
/// the sandbox screen once the entry is available.
class ResolvedSandboxRouteScreen extends ConsumerWidget {
  /// Creates a [ResolvedSandboxRouteScreen].
  const ResolvedSandboxRouteScreen({
    required this.appId,
    this.initialApp,
    super.key,
  });

  /// The app ID to resolve.
  final String appId;

  /// An optional pre-loaded entry to avoid a network call.
  final NostrAppDirectoryEntry? initialApp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(
      nostrAppDirectoryServiceProvider,
    );
    return BlocProvider(
      create: (_) => SandboxRouteCubit(
        appId: appId,
        directoryService: service,
        initialApp: initialApp,
      )..load(),
      child: const _SandboxRouteContent(),
    );
  }
}

class _SandboxRouteContent extends StatelessWidget {
  const _SandboxRouteContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SandboxRouteCubit, SandboxRouteState>(
      builder: (context, state) {
        return switch (state) {
          SandboxRouteLoading() => Scaffold(
            appBar: DiVineAppBar(
              title: 'Loading integration',
              showBackButton: true,
              onBackPressed: context.pop,
            ),
            backgroundColor: VineTheme.backgroundColor,
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          SandboxRouteNotFound() => const MissingSandboxAppScreen(),
          SandboxRouteResolved(:final app) => NostrAppSandboxScreen(app: app),
        };
      },
    );
  }
}
