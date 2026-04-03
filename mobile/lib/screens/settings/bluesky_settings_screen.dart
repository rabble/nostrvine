// ABOUTME: Bluesky crosspost settings screen with toggle switch
// ABOUTME: Allows users to enable/disable publishing videos to Bluesky

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/crosspost_settings/crosspost_settings_cubit.dart';
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
          title: 'Bluesky Publishing',
          showBackButton: true,
          onBackPressed: context.pop,
        ),
        backgroundColor: VineTheme.backgroundColor,
        body: const Center(
          child: Text(
            'Sign in to manage Bluesky settings',
            style: TextStyle(color: VineTheme.lightText),
          ),
        ),
      );
    }

    final apiClient = ref.watch(crosspostApiClientProvider);

    return BlocProvider(
      create: (_) => CrosspostSettingsCubit(
        apiClient: apiClient,
        pubkey: pubkey,
      ),
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
        title: 'Bluesky Publishing',
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
                  const SnackBar(
                    content: Text('Failed to update crosspost setting'),
                    backgroundColor: VineTheme.error,
                  ),
                );
              }
            },
            builder: (context, state) {
              if (state.status == CrosspostSettingsStatus.loading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: VineTheme.vineGreen,
                  ),
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
      title: const Text(
        'Publish videos to Bluesky',
        style: TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        state.enabled
            ? 'Your videos will be published to Bluesky'
            : 'Your videos will not be published to Bluesky',
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
      title: const Text(
        'Bluesky Handle',
        style: TextStyle(
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
      'ready' => 'Account provisioned and ready',
      'pending' => 'Account provisioning in progress...',
      'failed' => 'Account provisioning failed',
      'disabled' => 'Account disabled',
      _ => 'No Bluesky account linked',
    };

    final statusColor = switch (state.provisioningState) {
      'ready' => VineTheme.vineGreen,
      'pending' => VineTheme.accentOrange,
      'failed' => VineTheme.error,
      _ => VineTheme.lightText,
    };

    return ListTile(
      leading: Icon(Icons.info_outline, color: statusColor),
      title: const Text(
        'Status',
        style: TextStyle(
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
