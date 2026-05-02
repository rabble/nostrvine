// ABOUTME: Bluesky crosspost settings screen with toggle switch
// ABOUTME: Allows users to enable/disable publishing videos to Bluesky

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/crosspost_settings/crosspost_settings_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';

class BlueskySettingsScreen extends ConsumerWidget {
  static const routeName = 'bluesky-settings';
  static const path = '/bluesky-settings';

  const BlueskySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final pubkey = authService.currentPublicKeyHex;

    if (pubkey == null) {
      return Scaffold(
        appBar: DiVineAppBar(
          title: context.l10n.settingsBlueskyPublishing,
          showBackButton: true,
          onBackPressed: context.pop,
        ),
        backgroundColor: VineTheme.backgroundColor,
        body: Center(
          child: Text(
            context.l10n.blueskySignInRequired,
            style: const TextStyle(color: VineTheme.lightText),
          ),
        ),
      );
    }

    final apiClient = ref.watch(crosspostApiClientProvider);

    return BlocProvider(
      create: (_) =>
          CrosspostSettingsCubit(apiClient: apiClient, pubkey: pubkey),
      child: const _BlueskySettingsView(),
    );
  }
}

class _BlueskySettingsView extends StatelessWidget {
  const _BlueskySettingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.settingsBlueskyPublishing,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocConsumer<CrosspostSettingsCubit, CrosspostSettingsState>(
            listener: (context, state) {
              if (state.status == CrosspostSettingsStatus.failure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.blueskyFailedToUpdateCrosspost),
                    backgroundColor: VineTheme.error,
                  ),
                );
              }
            },
            builder: (context, state) {
              if (state.status == CrosspostSettingsStatus.loading) {
                return const Center(
                  child: CircularProgressIndicator(color: VineTheme.vineGreen),
                );
              }

              return ListView(
                children: [
                  const SizedBox(height: 16),
                  _CrosspostToggle(state: state),
                  if (state.handle != null) _HandleInfo(handle: state.handle!),
                  _ProvisioningStatus(state: state),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CrosspostToggle extends StatelessWidget {
  const _CrosspostToggle({required this.state});

  final CrosspostSettingsState state;

  @override
  Widget build(BuildContext context) {
    final isToggling = state.status == CrosspostSettingsStatus.toggling;

    return SwitchListTile(
      secondary: const Icon(Icons.cloud_upload, color: VineTheme.vineGreen),
      title: Text(
        context.l10n.blueskyPublishVideos,
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        state.enabled
            ? context.l10n.blueskyEnabledSubtitle
            : context.l10n.blueskyDisabledSubtitle,
        style: const TextStyle(color: VineTheme.lightText, fontSize: 14),
      ),
      value: state.enabled,
      onChanged: isToggling
          ? null
          : (value) => context.read<CrosspostSettingsCubit>().toggleCrosspost(
              enabled: value,
            ),
      activeTrackColor: VineTheme.vineGreen,
      inactiveThumbColor: VineTheme.lightText,
    );
  }
}

class _HandleInfo extends StatelessWidget {
  const _HandleInfo({required this.handle});

  final String handle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.alternate_email, color: VineTheme.vineGreen),
      title: Text(
        context.l10n.blueskyHandle,
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        handle,
        style: const TextStyle(color: VineTheme.lightText, fontSize: 14),
      ),
    );
  }
}

class _ProvisioningStatus extends StatelessWidget {
  const _ProvisioningStatus({required this.state});

  final CrosspostSettingsState state;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (state.provisioningState) {
      'ready' => context.l10n.blueskyStatusReady,
      'pending' => context.l10n.blueskyStatusPending,
      'failed' => context.l10n.blueskyStatusFailed,
      'disabled' => context.l10n.blueskyStatusDisabled,
      _ => context.l10n.blueskyStatusNotLinked,
    };

    final statusColor = switch (state.provisioningState) {
      'ready' => VineTheme.vineGreen,
      'pending' => VineTheme.accentOrange,
      'failed' => VineTheme.error,
      _ => VineTheme.lightText,
    };

    return ListTile(
      leading: Icon(Icons.info_outline, color: statusColor),
      title: Text(
        context.l10n.blueskyStatus,
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        statusText,
        style: TextStyle(color: statusColor, fontSize: 14),
      ),
    );
  }
}
