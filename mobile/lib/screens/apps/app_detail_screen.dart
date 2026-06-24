// ABOUTME: App detail screen for approved third-party integrations in Divine
// ABOUTME: Explains the bounded access model before launching an integration

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/app_detail/app_detail_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/apps/nostr_app_launch_mode.dart';

/// Displays detailed information about a single approved
/// third-party integration.
class AppDetailScreen extends ConsumerWidget {
  /// Route name used by GoRouter.
  static const routeName = 'app-detail';

  /// Route path used by GoRouter.
  static const path = '/apps/:slug';

  /// Creates an [AppDetailScreen].
  const AppDetailScreen({required this.slug, this.initialEntry, super.key});

  /// The slug of the app to display.
  final String slug;

  /// An optional pre-loaded entry to avoid a network call.
  final NostrAppDirectoryEntry? initialEntry;

  /// Returns the path for a given [slug].
  static String pathForSlug(String slug) => '/apps/$slug';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(nostrAppDirectoryServiceProvider);
    return BlocProvider(
      create: (_) => AppDetailCubit(
        slug: slug,
        directoryService: service,
        initialEntry: initialEntry,
      )..load(),
      child: const _AppDetailContent(),
    );
  }
}

class _AppDetailContent extends StatelessWidget {
  const _AppDetailContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppDetailCubit, AppDetailState>(
      builder: (context, state) {
        final app = switch (state) {
          AppDetailLoaded(:final app) => app,
          _ => null,
        };

        return Scaffold(
          appBar: DiVineAppBar(
            title: app?.name ?? context.l10n.appsDetailDefaultTitle,
            showBackButton: true,
            onBackPressed: context.pop,
          ),
          backgroundColor: VineTheme.backgroundColor,
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: switch (state) {
                AppDetailLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                AppDetailNotFound() => _AppDetailMessage(
                  title: context.l10n.appsDetailNotFoundTitle,
                  subtitle: context.l10n.appsDetailNotFoundSubtitle,
                ),
                AppDetailLoaded(:final app) => ListView(
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
                      title: context.l10n.appsDetailHowItWorksTitle,
                      child: Text(
                        context.l10n.appsDetailHowItWorksBody,
                        style: const TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                    _AppDetailSection(
                      title: context.l10n.appsDetailAboutTitle,
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
                      title: context.l10n.appsDetailPrimaryOriginTitle,
                      child: Text(
                        app.primaryOrigin,
                        style: const TextStyle(
                          color: VineTheme.vineGreen,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    _AppDetailSection(
                      title: context.l10n.appsDetailApprovedOriginsTitle,
                      child: _PillList(items: app.allowedOrigins),
                    ),
                    _AppDetailSection(
                      title: context.l10n.appsDetailCapabilitiesTitle,
                      child: _PillList(items: app.allowedMethods),
                    ),
                    _AppDetailSection(
                      title: context.l10n.appsDetailAskBeforeTitle,
                      child: _PillList(items: app.promptRequiredFor),
                    ),
                    const SizedBox(height: 8),
                    DivineButton(
                      label: context.l10n.appsDetailOpenButton,
                      onPressed: () => launchNostrApp(context, app),
                    ),
                  ],
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

class _AppDetailSection extends StatelessWidget {
  const _AppDetailSection({required this.title, required this.child});

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
      return Text(
        context.l10n.appsDetailNoneDeclared,
        style: const TextStyle(color: VineTheme.lightText, fontSize: 14),
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
  const _AppDetailMessage({required this.title, required this.subtitle});

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
