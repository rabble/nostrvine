// ABOUTME: Resolves a NostrAppDirectoryEntry by ID and renders the
// ABOUTME: sandbox screen once the entry is available.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/widgets/missing_sandbox_app_screen.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';

class ResolvedSandboxRouteScreen extends ConsumerStatefulWidget {
  const ResolvedSandboxRouteScreen({
    required this.appId,
    this.initialApp,
    super.key,
  });

  final String appId;
  final NostrAppDirectoryEntry? initialApp;

  @override
  ConsumerState<ResolvedSandboxRouteScreen> createState() =>
      _ResolvedSandboxRouteScreenState();
}

class _ResolvedSandboxRouteScreenState
    extends ConsumerState<ResolvedSandboxRouteScreen> {
  late Future<NostrAppDirectoryEntry?> _appFuture;

  @override
  void initState() {
    super.initState();
    _appFuture = _loadApp();
  }

  @override
  void didUpdateWidget(
    covariant ResolvedSandboxRouteScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appId != widget.appId ||
        oldWidget.initialApp?.id != widget.initialApp?.id) {
      _appFuture = _loadApp();
    }
  }

  Future<NostrAppDirectoryEntry?> _loadApp() async {
    final initialApp = widget.initialApp;
    if (initialApp != null) {
      return initialApp;
    }

    final apps = await ref
        .read(nostrAppDirectoryServiceProvider)
        .fetchApprovedApps();
    for (final app in apps) {
      if (app.id == widget.appId) {
        return app;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NostrAppDirectoryEntry?>(
      future: _appFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: DiVineAppBar(
              title: 'Loading integration',
              showBackButton: true,
              onBackPressed: context.pop,
            ),
            backgroundColor: VineTheme.backgroundColor,
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final app = snapshot.data;
        if (app == null) {
          return const MissingSandboxAppScreen();
        }
        return NostrAppSandboxScreen(app: app);
      },
    );
  }
}
