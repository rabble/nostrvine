// ABOUTME: App detail screen for approved third-party integrations in Divine
// ABOUTME: Explains the bounded access model before launching an integration

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/apps/app_detail_cubit.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';

class AppDetailScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider(
      key: ValueKey('$slug:${initialEntry?.id ?? ''}'),
      create: (_) => AppDetailCubit(
        directoryService: initialEntry == null
            ? ref.read(nostrAppDirectoryServiceProvider)
            : null,
        slug: slug,
        initialEntry: initialEntry,
      )..load(),
      child: const _AppDetailView(),
    );
  }
}

class _AppDetailView extends StatelessWidget {
  const _AppDetailView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppDetailCubit, AppDetailState>(
      builder: (context, state) {
        final app = state.app;
        return Scaffold(
          appBar: DiVineAppBar(
            title: app?.name ?? 'Integrated App',
            showBackButton: true,
            onBackPressed: context.pop,
          ),
          backgroundColor: VineTheme.backgroundColor,
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: switch (state.status) {
                AppDetailStatus.initial || AppDetailStatus.loading =>
                  const Center(child: CircularProgressIndicator()),
                AppDetailStatus.notFound => const _AppDetailMessage(
                  title: 'Integration not found',
                  subtitle:
                      'This approved integration is no longer available in Divine.',
                ),
                AppDetailStatus.loaded => _AppDetailContent(app: app!),
              },
            ),
          ),
        );
      },
    );
  }
}

class _AppDetailContent extends StatelessWidget {
  const _AppDetailContent({required this.app});

  final NostrAppDirectoryEntry app;

  @override
  Widget build(BuildContext context) {
    return ListView(
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
        const _AppDetailSection(
          title: 'How it works',
          child: Text(
            'This is an approved third-party app that runs inside Divine. Divine only grants reviewed capabilities for this integration, and blocks navigation outside its approved origins.',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
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
          title: 'Primary origin',
          child: Text(
            _displayPrimaryOrigin(app.launchUrl),
            style: const TextStyle(
              color: VineTheme.vineGreen,
              fontSize: 15,
            ),
          ),
        ),
        _AppDetailSection(
          title: 'Approved origins',
          child: _PillList(items: app.allowedOrigins),
        ),
        _AppDetailSection(
          title: 'Available capabilities',
          child: _PillList(items: app.allowedMethods),
        ),
        _AppDetailSection(
          title: 'Ask before',
          child: _PillList(items: app.promptRequiredFor),
        ),
        const SizedBox(height: 8),
        DivineButton(
          label: 'Open Integration',
          onPressed: () {
            context.push(
              NostrAppSandboxScreen.pathForAppId(app.id),
              extra: app,
            );
          },
        ),
      ],
    );
  }
}

String _displayPrimaryOrigin(String launchUrl) {
  final uri = Uri.tryParse(launchUrl);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    return launchUrl;
  }
  return uri.origin;
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
