import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/apps/sandbox_route_cubit.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';

class ResolvedSandboxRouteScreen extends ConsumerWidget {
  const ResolvedSandboxRouteScreen({
    required this.appId,
    this.initialApp,
    super.key,
  });

  final String appId;
  final NostrAppDirectoryEntry? initialApp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider(
      key: ValueKey('$appId:${initialApp?.id ?? ''}'),
      create: (_) => SandboxRouteCubit(
        directoryService: initialApp == null
            ? ref.read(nostrAppDirectoryServiceProvider)
            : null,
        appId: appId,
        initialApp: initialApp,
      )..load(),
      child: const _ResolvedSandboxRouteView(),
    );
  }
}

class _ResolvedSandboxRouteView extends StatelessWidget {
  const _ResolvedSandboxRouteView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SandboxRouteCubit, SandboxRouteState>(
      builder: (context, state) {
        return switch (state.status) {
          SandboxRouteStatus.initial || SandboxRouteStatus.loading => Scaffold(
            appBar: DiVineAppBar(
              title: 'Loading integration',
              showBackButton: true,
              onBackPressed: context.pop,
            ),
            backgroundColor: VineTheme.backgroundColor,
            body: const Center(child: CircularProgressIndicator()),
          ),
          SandboxRouteStatus.missing => const _MissingSandboxAppScreen(),
          SandboxRouteStatus.resolved => NostrAppSandboxScreen(app: state.app!),
        };
      },
    );
  }
}

class _MissingSandboxAppScreen extends StatelessWidget {
  const _MissingSandboxAppScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: 'Integration unavailable',
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Open approved integrations from the Integrated Apps tab so Divine can apply the right access policy.',
            textAlign: TextAlign.center,
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
