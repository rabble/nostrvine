// ABOUTME: Lists vetted Nostr apps fetched from the remote directory service
// ABOUTME: Provides a simple settings-entry browse surface before the sandbox launches

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';

class AppsDirectoryScreen extends ConsumerStatefulWidget {
  static const routeName = 'apps-directory';
  static const path = '/apps';

  const AppsDirectoryScreen({super.key});

  @override
  ConsumerState<AppsDirectoryScreen> createState() =>
      _AppsDirectoryScreenState();
}

class _AppsDirectoryScreenState extends ConsumerState<AppsDirectoryScreen> {
  late Future<List<NostrAppDirectoryEntry>> _appsFuture;

  @override
  void initState() {
    super.initState();
    _appsFuture = _loadApps();
  }

  Future<List<NostrAppDirectoryEntry>> _loadApps() {
    return ref.read(nostrAppDirectoryServiceProvider).fetchApprovedApps();
  }

  Future<void> _refreshApps() async {
    final future = _loadApps();
    setState(() {
      _appsFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: 'Apps',
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: FutureBuilder<List<NostrAppDirectoryEntry>>(
            future: _appsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _AppsDirectoryMessage(
                  title: 'Could not load apps',
                  subtitle: 'Pull to try the vetted directory again.',
                  actionLabel: 'Retry',
                  onAction: _refreshApps,
                );
              }

              final apps = snapshot.data ?? const <NostrAppDirectoryEntry>[];
              if (apps.isEmpty) {
                return _AppsDirectoryMessage(
                  title: 'No vetted apps yet',
                  subtitle: 'Check back after the directory refreshes.',
                  actionLabel: 'Refresh',
                  onAction: _refreshApps,
                );
              }

              return RefreshIndicator(
                onRefresh: _refreshApps,
                child: ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: VineTheme.cardBackground,
                        child: Icon(Icons.apps, color: VineTheme.vineGreen),
                      ),
                      title: Text(
                        app.name,
                        style: const TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        app.tagline,
                        style: const TextStyle(
                          color: VineTheme.lightText,
                          fontSize: 14,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: VineTheme.lightText,
                      ),
                      onTap: () => context.push(
                        AppDetailScreen.pathForSlug(app.slug),
                        extra: app,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
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
  final Future<void> Function() onAction;

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
              style: const TextStyle(
                color: VineTheme.lightText,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            DivineButton(
              label: actionLabel,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}
