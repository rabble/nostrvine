// ABOUTME: Bluesky crosspost settings screen with toggle switch
// ABOUTME: Allows users to enable/disable publishing videos to Bluesky

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/crosspost_settings/crosspost_settings_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

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
        backgroundColor: context.vineColors.background,
        body: Center(
          child: Text(
            context.l10n.blueskySignInRequired,
            style: VineTheme.bodyLargeFont(color: context.vineColors.mutedText),
          ),
        ),
      );
    }

    final apiClient = ref.watch(crosspostApiClientProvider);
    final profileRepository = ref.watch(profileRepositoryProvider);
    if (profileRepository == null) {
      return Scaffold(
        appBar: DiVineAppBar(
          title: context.l10n.settingsBlueskyPublishing,
          showBackButton: true,
          onBackPressed: context.pop,
        ),
        backgroundColor: context.vineColors.background,
        body: const Center(child: BrandedLoadingIndicator(size: 60)),
      );
    }

    return BlocProvider(
      create: (_) => CrosspostSettingsCubit(
        apiClient: apiClient,
        profileRepository: profileRepository,
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
        title: context.l10n.settingsBlueskyPublishing,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: BlocConsumer<CrosspostSettingsCubit, CrosspostSettingsState>(
            listener: _onStateChanged,
            builder: (context, state) {
              if (state.status == CrosspostSettingsStatus.loading) {
                return const Center(child: BrandedLoadingIndicator(size: 60));
              }

              return ListView(
                children: [
                  const SizedBox(height: 16),
                  if (state.usernameClaimStatus ==
                      UsernameClaimStatus.notClaimed)
                    const _UsernameRequiredNotice(),
                  if (state.usernameClaimStatus == UsernameClaimStatus.unknown)
                    const _UsernameLookupUnavailableNotice(),
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

  void _onStateChanged(BuildContext context, CrosspostSettingsState state) {
    if (state.status != CrosspostSettingsStatus.failure) return;

    final messenger = ScaffoldMessenger.of(context);
    // Captured here, while the route is still mounted. The root
    // ScaffoldMessenger lives above the Navigator, so this snackbar outlives a
    // pop — reading the cubit off [context] inside the action would then hit a
    // defunct element, whose inherited-widget map the framework has already
    // cleared.
    final cubit = context.read<CrosspostSettingsCubit>();
    final router = GoRouter.of(context);
    switch (state.error) {
      case CrosspostSettingsError.usernameNotClaimed:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.blueskyUsernameRequired,
            error: true,
            actionLabel: context.l10n.blueskySetUpHandle,
            onActionPressed: () {
              // DivineSnackbarContainer's action is a plain button, so unlike
              // SnackBarAction it does not dismiss the banner for us.
              messenger.hideCurrentSnackBar();
              // BlocProvider closes the cubit when the route pops, so this
              // tracks whether the screen the action refers to still exists.
              if (cubit.isClosed) return;
              cubit.acknowledgeError();
              unawaited(_openClaimFlowAndRefresh(router, cubit));
            },
          ),
        );
      case CrosspostSettingsError.unavailable:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.blueskyTemporarilyUnavailable,
            error: true,
          ),
        );
      case CrosspostSettingsError.usernameNotSynced:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.blueskyUsernameSyncPending,
            error: true,
          ),
        );
      case CrosspostSettingsError.generic:
      case null:
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.blueskyFailedToUpdateCrosspost,
            error: true,
          ),
        );
    }
  }
}

class _UsernameLookupUnavailableNotice extends StatelessWidget {
  const _UsernameLookupUnavailableNotice();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const DivineIcon(
        icon: DivineIconName.info,
        color: VineTheme.accentOrange,
      ),
      title: Text(
        context.l10n.blueskyStatusUnavailableRetry,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      trailing: DivineButton(
        label: context.l10n.commonRetry,
        onPressed: () => context.read<CrosspostSettingsCubit>().loadStatus(),
        type: DivineButtonType.link,
        size: DivineButtonSize.small,
      ),
    );
  }
}

class _UsernameRequiredNotice extends StatelessWidget {
  const _UsernameRequiredNotice();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const DivineIcon(
        icon: DivineIconName.sealCheck,
        color: VineTheme.accentOrange,
      ),
      title: Text(
        context.l10n.blueskyUsernameRequired,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      subtitle: Text(
        context.l10n.blueskyUsernameRequiredSubtitle,
        style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
      ),
      trailing: DivineButton(
        label: context.l10n.blueskySetUpHandle,
        type: DivineButtonType.link,
        size: DivineButtonSize.small,
        onPressed: () => unawaited(
          _openClaimFlowAndRefresh(
            GoRouter.of(context),
            context.read<CrosspostSettingsCubit>(),
          ),
        ),
      ),
    );
  }
}

Future<void> _openClaimFlowAndRefresh(
  GoRouter router,
  CrosspostSettingsCubit cubit,
) async {
  await router.push(Nip05SettingsScreen.path);
  if (cubit.isClosed) return;
  await cubit.loadStatus();
}

class _CrosspostToggle extends StatelessWidget {
  const _CrosspostToggle({required this.state});

  final CrosspostSettingsState state;

  @override
  Widget build(BuildContext context) {
    final isToggling = state.status == CrosspostSettingsStatus.toggling;

    return DivineSwitchTile(
      leadingIcon: DivineIconName.arrowUpRight,
      title: context.l10n.blueskyPublishVideos,
      subtitle: state.enabled
          ? context.l10n.blueskyEnabledSubtitle
          : context.l10n.blueskyDisabledSubtitle,
      value: state.enabled,
      onChanged: isToggling
          ? null
          : (value) => context.read<CrosspostSettingsCubit>().toggleCrosspost(
              enabled: value,
            ),
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
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      subtitle: Text(
        handle,
        style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
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
      _ => context.vineColors.mutedText,
    };

    return ListTile(
      leading: DivineIcon(icon: DivineIconName.info, color: statusColor),
      title: Text(
        context.l10n.blueskyStatus,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      subtitle: Text(
        statusText,
        style: VineTheme.bodyMediumFont(color: statusColor),
      ),
    );
  }
}
