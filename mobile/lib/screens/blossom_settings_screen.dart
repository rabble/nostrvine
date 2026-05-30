// ABOUTME: Settings screen for configuring Blossom media server uploads
// ABOUTME: Allows users to enable Blossom uploads and configure their preferred server

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/blossom_settings/blossom_settings_cubit.dart';
import 'package:openvine/blocs/blossom_settings/blossom_settings_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';

/// Page: bridges `BlossomUploadService` into [BlossomSettingsCubit].
class BlossomSettingsScreen extends ConsumerWidget {
  const BlossomSettingsScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'blossom-settings';

  /// Path for this route.
  static const path = '/blossom-settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blossomUploadService = ref.watch(blossomUploadServiceProvider);
    return BlocProvider(
      key: ValueKey(blossomUploadService),
      create: (_) =>
          BlossomSettingsCubit(blossomUploadService: blossomUploadService)
            ..load(),
      child: const BlossomSettingsView(),
    );
  }
}

/// View: renders blossom settings from the Cubit state. The server-URL
/// `TextEditingController` is owned here (the "first hybrid" pattern —
/// controllers are UI plumbing, not Cubit state).
class BlossomSettingsView extends StatefulWidget {
  @visibleForTesting
  const BlossomSettingsView({super.key});

  @override
  State<BlossomSettingsView> createState() => _BlossomSettingsViewState();
}

class _BlossomSettingsViewState extends State<BlossomSettingsView> {
  final _serverController = TextEditingController();
  bool _seededFromState = false;

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  /// Seeds the server-URL field exactly once, on the first `ready`/`saving`
  /// state. After the first seed the [TextEditingController] owns the value;
  /// later state emissions intentionally do not overwrite the user's input.
  void _seedControllerIfNeeded(BlossomSettingsState state) {
    if (_seededFromState) return;
    if (state.status == BlossomSettingsStatus.ready ||
        state.status == BlossomSettingsStatus.saving) {
      _serverController.text = state.initialServerUrl;
      _seededFromState = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BlossomSettingsCubit, BlossomSettingsState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == BlossomSettingsStatus.saveSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.blossomSettingsSaved,
                style: const TextStyle(color: VineTheme.whiteText),
              ),
              backgroundColor: VineTheme.vineGreen,
            ),
          );
          context.pop();
        } else if (state.status == BlossomSettingsStatus.saveFailure) {
          final messenger = ScaffoldMessenger.of(context);
          final message = switch (state.saveFailureMessageKey) {
            BlossomSaveFailureKey.invalidServerUrl =>
              context.l10n.blossomValidServerUrl,
            BlossomSaveFailureKey.mustUseHttps =>
              context.l10n.blossomServerUrlMustUseHttps,
            BlossomSaveFailureKey.genericFailure ||
            null => context.l10n.blossomFailedToSaveSettings(''),
          };
          messenger.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: VineTheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        _seedControllerIfNeeded(state);
        final isLoading =
            state.status == BlossomSettingsStatus.loading ||
            state.status == BlossomSettingsStatus.initial;
        final isSaving = state.status == BlossomSettingsStatus.saving;
        return Scaffold(
          appBar: DiVineAppBar(
            title: context.l10n.nostrSettingsMediaServers,
            showBackButton: true,
            onBackPressed: context.pop,
            actions: isLoading
                ? const []
                : [
                    DiVineAppBarAction(
                      icon: SvgIconSource(DivineIconName.check.assetPath),
                      onPressed: isSaving
                          ? null
                          : () => context.read<BlossomSettingsCubit>().save(
                              _serverController.text,
                            ),
                      tooltip: context.l10n.blossomSaveTooltip,
                    ),
                  ],
          ),
          backgroundColor: VineTheme.backgroundColor,
          body: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: VineTheme.vineGreen),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const _AboutCard(),
                        const SizedBox(height: 20),
                        const _EnableToggle(),
                        const SizedBox(height: 20),
                        if (state.isBlossomEnabled)
                          _ServerUrlSection(
                            controller: _serverController,
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

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VineTheme.backgroundColor.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: VineTheme.vineGreen.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DivineIcon(
                  icon: DivineIconName.info,
                  color: VineTheme.vineGreen.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.blossomAboutTitle,
                  style: const TextStyle(
                    color: VineTheme.vineGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.blossomAboutDescription,
              style: const TextStyle(color: VineTheme.onSurface, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnableToggle extends StatelessWidget {
  const _EnableToggle();

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select(
      (BlossomSettingsCubit cubit) => cubit.state.isBlossomEnabled,
    );
    return SwitchListTile(
      title: Text(
        context.l10n.blossomUseCustomServer,
        style: const TextStyle(color: VineTheme.whiteText, fontSize: 16),
      ),
      subtitle: Text(
        isEnabled
            ? context.l10n.blossomCustomServerEnabledSubtitle
            : context.l10n.blossomCustomServerDisabledSubtitle,
        style: const TextStyle(color: VineTheme.onSurfaceMuted),
      ),
      value: isEnabled,
      onChanged: (value) =>
          context.read<BlossomSettingsCubit>().setEnabled(value),
      activeThumbColor: VineTheme.vineGreen,
      inactiveThumbColor: VineTheme.lightText,
      inactiveTrackColor: VineTheme.lightText.withValues(alpha: 0.3),
    );
  }
}

class _ServerUrlSection extends StatelessWidget {
  const _ServerUrlSection({required this.controller});

  final TextEditingController controller;

  static const _popularServers = <(String url, String name)>[
    ('https://blossom.band', 'Blossom Band'),
    ('https://cdn.satellite.earth', 'Satellite Earth'),
    ('https://blossom.primal.net', 'Primal'),
    ('https://nostr.download', 'Nostr Download'),
    ('https://cdn.nostrcheck.me', 'NostrCheck'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.blossomCustomServerUrl,
          style: const TextStyle(
            color: VineTheme.whiteText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: InputDecoration(
            hintText: 'https://blossom.band',
            hintStyle: const TextStyle(color: VineTheme.onSurfaceDisabled),
            filled: true,
            fillColor: VineTheme.whiteText.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: VineTheme.vineGreen.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: VineTheme.vineGreen.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: VineTheme.vineGreen),
            ),
            prefixIcon: const Icon(
              Icons.cloud_upload,
              color: VineTheme.vineGreen,
            ),
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.blossomCustomServerHelper,
          style: const TextStyle(
            color: VineTheme.onSurfaceMuted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 30),
        Text(
          context.l10n.blossomPopularServers,
          style: const TextStyle(
            color: VineTheme.whiteText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in _popularServers)
          _ServerOption(
            url: entry.$1,
            name: entry.$2,
            onSelect: () => controller.text = entry.$1,
          ),
      ],
    );
  }
}

class _ServerOption extends StatelessWidget {
  const _ServerOption({
    required this.url,
    required this.name,
    required this.onSelect,
  });

  final String url;
  final String name;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VineTheme.whiteText.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(name, style: const TextStyle(color: VineTheme.whiteText)),
        subtitle: Text(
          url,
          style: const TextStyle(
            color: VineTheme.onSurfaceMuted,
            fontSize: 12,
          ),
        ),
        trailing: const DivineIcon(
          icon: DivineIconName.arrowRight,
          color: VineTheme.vineGreen,
        ),
        onTap: onSelect,
      ),
    );
  }
}
