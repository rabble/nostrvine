// ABOUTME: App detail screen for vetted Nostr apps
// ABOUTME: Shows app metadata and capability summary before sandbox launch wiring exists

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';

class AppDetailScreen extends ConsumerStatefulWidget {
  static const routeName = 'app-detail';
  static const path = '/apps/:slug';

  const AppDetailScreen({
    required this.slug,
    this.initialEntry,
    super.key,
  });

  final String slug;
  final NostrAppDirectoryEntry? initialEntry;

  static String pathForSlug(String slug) => '/apps/$slug';

  @override
  ConsumerState<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends ConsumerState<AppDetailScreen> {
  late Future<NostrAppDirectoryEntry?> _entryFuture;

  @override
  void initState() {
    super.initState();
    _entryFuture = _loadEntry();
  }

  @override
  void didUpdateWidget(covariant AppDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug ||
        oldWidget.initialEntry?.id != widget.initialEntry?.id) {
      _entryFuture = _loadEntry();
    }
  }

  Future<NostrAppDirectoryEntry?> _loadEntry() async {
    if (widget.initialEntry != null) {
      return widget.initialEntry;
    }

    final apps = await ref
        .read(nostrAppDirectoryServiceProvider)
        .fetchApprovedApps();
    for (final app in apps) {
      if (app.slug == widget.slug) {
        return app;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NostrAppDirectoryEntry?>(
      future: _entryFuture,
      builder: (context, snapshot) {
        final app = snapshot.data;
        return Scaffold(
          appBar: DiVineAppBar(
            title: app?.name ?? 'App',
            showBackButton: true,
            onBackPressed: context.pop,
          ),
          backgroundColor: VineTheme.backgroundColor,
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: snapshot.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : app == null
                  ? const _AppDetailMessage(
                      title: 'App not found',
                      subtitle:
                          'This vetted app is no longer in the directory.',
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: VineTheme.cardBackground,
                          child: Icon(Icons.apps, color: VineTheme.vineGreen),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          app.name,
                          style: const TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          app.tagline,
                          style: const TextStyle(
                            color: VineTheme.lightText,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _AppDetailSection(
                          title: 'About',
                          child: Text(
                            app.description,
                            style: const TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ),
                        _AppDetailSection(
                          title: 'Launch URL',
                          child: Text(
                            app.launchUrl,
                            style: const TextStyle(
                              color: VineTheme.vineGreen,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _AppDetailSection(
                          title: 'Allowed origins',
                          child: _PillList(items: app.allowedOrigins),
                        ),
                        _AppDetailSection(
                          title: 'Allowed methods',
                          child: _PillList(items: app.allowedMethods),
                        ),
                        _AppDetailSection(
                          title: 'Runtime prompts',
                          child: _PillList(items: app.promptRequiredFor),
                        ),
                        const SizedBox(height: 8),
                        DivineButton(
                          label: 'Open In Sandbox',
                          onPressed: () {
                            context.push(
                              NostrAppSandboxScreen.pathForAppId(app.id),
                              extra: app,
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _AppDetailSection extends StatelessWidget {
  const _AppDetailSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: VineTheme.lightText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PillList extends StatelessWidget {
  const _PillList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'None declared yet',
        style: TextStyle(color: VineTheme.lightText, fontSize: 14),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: VineTheme.backgroundColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: VineTheme.vineGreen.withAlpha(80)),
              ),
              child: Text(
                item,
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 13,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AppDetailMessage extends StatelessWidget {
  const _AppDetailMessage({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VineTheme.whiteText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: VineTheme.lightText,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
