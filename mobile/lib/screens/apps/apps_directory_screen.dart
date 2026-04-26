// ABOUTME: Lists approved third-party app integrations surfaced inside Divine
// ABOUTME: Keeps the framing explicitly bounded instead of reading like a browser

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/apps_directory/apps_directory_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:openvine/utils/nostr_apps_platform_support.dart';

/// Displays the directory of approved third-party apps.
class AppsDirectoryScreen extends ConsumerWidget {
  /// Route name used by GoRouter.
  static const routeName = 'apps-directory';

  /// Route path used by GoRouter.
  static const path = '/apps';

  /// Creates an [AppsDirectoryScreen].
  const AppsDirectoryScreen({super.key, this.embedded = false});

  /// When true the screen omits its own app bar.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!nostrAppsSandboxSupported) {
      return _AppsDirectoryFrame(
        embedded: embedded,
        child: const _AppsDirectoryUnsupportedMessage(),
      );
    }

    final service = ref.read(nostrAppDirectoryServiceProvider);
    return BlocProvider(
      create: (_) => AppsDirectoryCubit(directoryService: service)..loadApps(),
      child: _AppsDirectoryFrame(
        embedded: embedded,
        child: const _AppsDirectoryContent(),
      ),
    );
  }
}

class _AppsDirectoryContent extends StatelessWidget {
  const _AppsDirectoryContent();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VineTheme.backgroundColor,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocBuilder<AppsDirectoryCubit, AppsDirectoryState>(
            builder: (context, state) {
              return switch (state.status) {
                AppsDirectoryStatus.initial || AppsDirectoryStatus.loading =>
                  const Center(child: CircularProgressIndicator()),
                AppsDirectoryStatus.error => _AppsDirectoryMessage(
                  title: 'Could not load integrated apps',
                  subtitle: 'Pull to try the approved integrations again.',
                  actionLabel: 'Retry',
                  onAction: () =>
                      context.read<AppsDirectoryCubit>().refreshApps(),
                ),
                AppsDirectoryStatus.loaded when state.apps.isEmpty =>
                  _AppsDirectoryMessage(
                    title: 'No approved integrations yet',
                    subtitle:
                        'Approved third-party apps will appear here as Divine adds them.',
                    actionLabel: 'Refresh',
                    onAction: () =>
                        context.read<AppsDirectoryCubit>().refreshApps(),
                  ),
                AppsDirectoryStatus.loaded => RefreshIndicator(
                  onRefresh: () =>
                      context.read<AppsDirectoryCubit>().refreshApps(),
                  child: ListView.builder(
                    itemCount: state.apps.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const _AppsDirectoryIntro();
                      }

                      final app = state.apps[index - 1];
                      return _AppsDirectoryRow(
                        app: app,
                        onTap: () => context.push(
                          NostrAppSandboxScreen.pathForAppId(app.id),
                          extra: app,
                        ),
                      );
                    },
                  ),
                ),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _AppsDirectoryFrame extends StatelessWidget {
  const _AppsDirectoryFrame({required this.embedded, required this.child});

  final bool embedded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return child;
    }

    return Scaffold(
      appBar: DiVineAppBar(
        title: 'Integrated Apps',
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: child,
    );
  }
}

class _AppsDirectoryRow extends StatelessWidget {
  const _AppsDirectoryRow({required this.app, required this.onTap});

  final NostrAppDirectoryEntry app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: VineTheme.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: VineTheme.outlineMuted),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AppsDirectoryIcon(iconUrl: app.iconUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        app.tagline,
                        style: const TextStyle(
                          color: VineTheme.vineGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        app.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: VineTheme.lightText,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.chevron_right, color: VineTheme.lightText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppsDirectoryIcon extends StatelessWidget {
  const _AppsDirectoryIcon({required this.iconUrl});

  final String iconUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.apps, color: VineTheme.vineGreen),
    );

    if (iconUrl.isEmpty) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        iconUrl,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _AppsDirectoryMessage extends StatelessWidget {
  const _AppsDirectoryMessage({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: VineTheme.lightText, fontSize: 15),
            ),
            const SizedBox(height: 16),
            DivineButton(label: actionLabel, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}

class _AppsDirectoryIntro extends StatelessWidget {
  const _AppsDirectoryIntro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VineTheme.outlineMuted),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approved third-party apps',
              style: VineTheme.headlineSmallFont(color: VineTheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Approved third-party apps that run inside Divine',
              style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppsDirectoryUnsupportedMessage extends StatelessWidget {
  const _AppsDirectoryUnsupportedMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Integrated Apps run in Divine mobile',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Approved integrations are only available on mobile for now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: VineTheme.lightText, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
