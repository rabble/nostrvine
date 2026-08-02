// ABOUTME: Nostr settings hub screen for relays, media servers, keys, and account
// ABOUTME: Organizes network and account settings with danger zone actions

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_client/nostr_client.dart' show Nip89ClientTag;
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyStorageException;
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/nostr_signature_verification_preference_service.dart';
import 'package:openvine/widgets/delete_account_action.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';
import 'package:openvine/widgets/modal_progress_overlay.dart';

class NostrSettingsScreen extends ConsumerWidget {
  static const routeName = 'nostr-settings';
  static const path = '/nostr-settings';

  const NostrSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showAdvancedRelaySettings = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.advancedRelaySettings),
    );
    final authState = ref.watch(currentAuthStateProvider);
    final isAuthenticated = authState == AuthState.authenticated;

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.settingsNostrSettings,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  context.l10n.nostrSettingsIntro,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.mutedText,
                  ),
                ),
              ),

              // Network section
              DivineSectionHeader(context.l10n.nostrSettingsSectionNetwork),
              if (showAdvancedRelaySettings) ...[
                DivineListTile(
                  leading: const Icon(Icons.hub, color: VineTheme.vineGreen),
                  title: context.l10n.nostrSettingsRelays,
                  subtitle: context.l10n.nostrSettingsRelaysSubtitle,
                  onTap: () => context.push(RelaySettingsScreen.path),
                ),
                DivineListTile(
                  leading: const Icon(
                    Icons.troubleshoot,
                    color: VineTheme.vineGreen,
                  ),
                  title: context.l10n.nostrSettingsRelayDiagnostics,
                  subtitle: context.l10n.nostrSettingsRelayDiagnosticsSubtitle,
                  onTap: () => context.push(RelayDiagnosticScreen.path),
                ),
              ],
              DivineListTile(
                leading: const Icon(
                  Icons.cloud_upload,
                  color: VineTheme.vineGreen,
                ),
                title: context.l10n.nostrSettingsMediaServers,
                subtitle: context.l10n.nostrSettingsMediaServersSubtitle,
                onTap: () => context.push(BlossomSettingsScreen.path),
              ),
              const _SignatureVerificationTile(),

              // Account section
              if (isAuthenticated) ...[
                DivineSectionHeader(context.l10n.nostrSettingsSectionAccount),
                DivineListTile(
                  icon: DivineIconName.key,
                  iconColor: VineTheme.vineGreen,
                  title: context.l10n.nostrSettingsKeyManagement,
                  subtitle: context.l10n.nostrSettingsKeyManagementSubtitle,
                  onTap: () => context.push(KeyManagementScreen.path),
                ),
                const _ClientAttributionToggle(),
                DivineListTile(
                  leading: const Icon(
                    Icons.alternate_email,
                    color: VineTheme.vineGreen,
                  ),
                  title: context.l10n.nostrSettingsNip05Address,
                  subtitle: context.l10n.nostrSettingsNip05AddressSubtitle,
                  onTap: () => context.pushNamed(Nip05SettingsScreen.routeName),
                ),
                _RemoveKeysTile(ref: ref),
                DivineSectionHeader(
                  context.l10n.nostrSettingsSectionDangerZone,
                ),
                DivineListTile(
                  icon: DivineIconName.trash,
                  title: context.l10n.nostrSettingsDeleteAccount,
                  subtitle: context.l10n.nostrSettingsDeleteAccountSubtitle,
                  iconColor: VineTheme.error,
                  titleColor: VineTheme.error,
                  onTap: () => startAccountDeletionFlow(
                    context: context,
                    ref: ref,
                    screenName: 'NostrSettingsScreen',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RemoveKeysTile extends StatelessWidget {
  const _RemoveKeysTile({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return DivineListTile(
      leading: const Icon(Icons.key_off, color: VineTheme.warning),
      title: context.l10n.nostrSettingsRemoveKeys,
      subtitle: context.l10n.nostrSettingsRemoveKeysSubtitle,
      onTap: () => _handleRemoveLocalAccount(context, ref),
      titleColor: VineTheme.warning,
    );
  }

  Future<void> _handleRemoveLocalAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final authService = ref.read(authServiceProvider);
    final couldNotRemoveKeysMessage =
        context.l10n.nostrSettingsCouldNotRemoveKeys;
    final failedToRemoveKeysFn = context.l10n.nostrSettingsFailedToRemoveKeys;

    await showRemoveKeysWarningDialog(
      context: context,
      onConfirm: () async {
        if (!context.mounted) return;

        // Resolved before the await: the spinner is an overlay entry, not a
        // route, so a back press during sign-out pops this screen instead of
        // the spinner. The app-level messenger outlives that pop; a
        // post-await `ScaffoldMessenger.of(context)` would not, and the user
        // would be left with no word on a key deletion that failed.
        final messenger = ScaffoldMessenger.of(context);
        final progressOverlay = ModalProgressOverlay.show(context);

        try {
          await authService.signOut(
            deleteKeys: true,
            abortOnKeyDeletionFailure: true,
          );
          progressOverlay.dismiss();
          if (!context.mounted) return;
          context.go(WelcomeScreen.path);
        } on SecureKeyStorageException {
          progressOverlay.dismiss();
          // Platform key deletion failed — user stays signed in and can
          // retry without having to log back in.
          if (!messenger.mounted) return;
          messenger.showSnackBar(
            DivineSnackbarContainer.snackBar(
              couldNotRemoveKeysMessage,
              error: true,
            ),
          );
        } catch (e) {
          progressOverlay.dismiss();
          if (!messenger.mounted) return;
          messenger.showSnackBar(
            DivineSnackbarContainer.snackBar(
              failedToRemoveKeysFn('$e'),
              error: true,
            ),
          );
        }
      },
    );
  }
}

class _ClientAttributionToggle extends ConsumerWidget {
  const _ClientAttributionToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync = ref.watch(nip89ClientTagEnabledProvider);
    final enabled = enabledAsync.value ?? true;

    return DivineSwitchTile(
      leadingIcon: DivineIconName.globe,
      title: context.l10n.nostrSettingsClientAttribution,
      subtitle: context.l10n.nostrSettingsClientAttributionSubtitle,
      value: enabled,
      onChanged: enabledAsync.isLoading
          ? null
          : (value) async {
              await Nip89ClientTag.setEnabled(enabled: value);
              ref.invalidate(nip89ClientTagEnabledProvider);
            },
    );
  }
}

class _SignatureVerificationTile extends ConsumerWidget {
  const _SignatureVerificationTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(nostrSignatureVerificationPolicyProvider);

    return DivineListTile(
      icon: DivineIconName.shieldCheck,
      iconColor: VineTheme.vineGreen,
      title: context.l10n.nostrSettingsSignatureVerification,
      subtitle: _policySubtitle(context, policy),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const _SignatureVerificationPolicyScreen(),
        ),
      ),
    );
  }
}

class _SignatureVerificationPolicyScreen extends ConsumerWidget {
  const _SignatureVerificationPolicyScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(nostrSignatureVerificationPolicyProvider);

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.nostrSettingsSignatureVerification,
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).pop(),
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  context.l10n.nostrSettingsSignatureVerificationIntro,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.mutedText,
                  ),
                ),
              ),
              for (final policy in NostrSignatureVerificationPolicy.values)
                DivineSelectableRow(
                  title: _policyTitle(context, policy),
                  subtitle: _policySubtitle(context, policy),
                  isSelected: policy == current,
                  onTap: () {
                    if (policy == current) return;
                    unawaited(_setPolicy(ref, policy));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setPolicy(
    WidgetRef ref,
    NostrSignatureVerificationPolicy value,
  ) async {
    final service = ref.read(
      nostrSignatureVerificationPreferenceServiceProvider,
    );
    await service.setPolicy(value);
    ref.invalidate(nostrSignatureVerificationPolicyProvider);
  }
}

String _policyTitle(
  BuildContext context,
  NostrSignatureVerificationPolicy policy,
) {
  switch (policy) {
    case NostrSignatureVerificationPolicy.all:
      return context.l10n.nostrSettingsSignatureVerificationAll;
    case NostrSignatureVerificationPolicy.untrustedRelays:
      return context.l10n.nostrSettingsSignatureVerificationUntrusted;
    case NostrSignatureVerificationPolicy.nonDivineRelays:
      return context.l10n.nostrSettingsSignatureVerificationNonDivine;
  }
}

String _policySubtitle(
  BuildContext context,
  NostrSignatureVerificationPolicy policy,
) {
  switch (policy) {
    case NostrSignatureVerificationPolicy.all:
      return context.l10n.nostrSettingsSignatureVerificationAllSubtitle;
    case NostrSignatureVerificationPolicy.untrustedRelays:
      return context.l10n.nostrSettingsSignatureVerificationUntrustedSubtitle;
    case NostrSignatureVerificationPolicy.nonDivineRelays:
      return context.l10n.nostrSettingsSignatureVerificationNonDivineSubtitle;
  }
}
