// ABOUTME: Nostr settings hub screen for relays, media servers, keys, and account
// ABOUTME: Organizes network and account settings with danger zone actions

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyStorageException;
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';

class NostrSettingsScreen extends ConsumerWidget {
  static const routeName = 'nostr-settings';
  static const path = '/nostr-settings';

  const NostrSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeveloperMode = ref.watch(isDeveloperModeEnabledProvider);
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
      backgroundColor: VineTheme.backgroundColor,
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
                  style: const TextStyle(
                    color: VineTheme.lightText,
                    fontSize: 14,
                  ),
                ),
              ),

              // Network section
              _SectionHeader(title: context.l10n.nostrSettingsSectionNetwork),
              if (showAdvancedRelaySettings) ...[
                _SettingsTile(
                  icon: Icons.hub,
                  title: context.l10n.nostrSettingsRelays,
                  subtitle: context.l10n.nostrSettingsRelaysSubtitle,
                  onTap: () => context.push(RelaySettingsScreen.path),
                ),
                _SettingsTile(
                  icon: Icons.troubleshoot,
                  title: context.l10n.nostrSettingsRelayDiagnostics,
                  subtitle: context.l10n.nostrSettingsRelayDiagnosticsSubtitle,
                  onTap: () => context.push(RelayDiagnosticScreen.path),
                ),
              ],
              _SettingsTile(
                icon: Icons.cloud_upload,
                title: context.l10n.nostrSettingsMediaServers,
                subtitle: context.l10n.nostrSettingsMediaServersSubtitle,
                onTap: () => context.push(BlossomSettingsScreen.path),
              ),
              if (isDeveloperMode)
                _SettingsTile(
                  icon: Icons.developer_mode,
                  title: context.l10n.nostrSettingsDeveloperOptions,
                  subtitle: context.l10n.nostrSettingsDeveloperOptionsSubtitle,
                  onTap: () => context.push(DeveloperOptionsScreen.path),
                  iconColor: VineTheme.warning,
                ),
              _SettingsTile(
                icon: Icons.science,
                title: context.l10n.settingsExperimentalFeatures,
                subtitle:
                    context.l10n.nostrSettingsExperimentalFeaturesSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FeatureFlagScreen()),
                ),
              ),

              // Account section
              if (isAuthenticated) ...[
                _SectionHeader(title: context.l10n.nostrSettingsSectionAccount),
                _SettingsTile(
                  icon: Icons.key,
                  title: context.l10n.nostrSettingsKeyManagement,
                  subtitle: context.l10n.nostrSettingsKeyManagementSubtitle,
                  onTap: () => context.push(KeyManagementScreen.path),
                ),
                _RemoveKeysTile(ref: ref),
                _SectionHeader(
                  title: context.l10n.nostrSettingsSectionDangerZone,
                ),
                _DeleteAccountTile(ref: ref),
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
    return _SettingsTile(
      icon: Icons.key_off,
      title: context.l10n.nostrSettingsRemoveKeys,
      subtitle: context.l10n.nostrSettingsRemoveKeysSubtitle,
      onTap: () => _handleRemoveKeys(context, ref),
      iconColor: VineTheme.warning,
      titleColor: VineTheme.warning,
    );
  }

  Future<void> _handleRemoveKeys(BuildContext context, WidgetRef ref) async {
    final authService = ref.read(authServiceProvider);
    final couldNotRemoveKeysMessage =
        context.l10n.nostrSettingsCouldNotRemoveKeys;
    final failedToRemoveKeysFn = context.l10n.nostrSettingsFailedToRemoveKeys;

    await showRemoveKeysWarningDialog(
      context: context,
      onConfirm: () async {
        if (!context.mounted) return;

        unawaited(
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
          ),
        );

        try {
          await authService.signOut(
            deleteKeys: true,
            abortOnKeyDeletionFailure: true,
          );
        } on SecureKeyStorageException {
          // Platform key deletion failed — user stays signed in and can
          // retry without having to log back in.
          if (!context.mounted) return;
          context.pop();

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(
              couldNotRemoveKeysMessage,
              error: true,
            ),
          );
          return;
        } catch (e) {
          if (!context.mounted) return;
          context.pop();

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
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

class _DeleteAccountTile extends StatelessWidget {
  const _DeleteAccountTile({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.delete_forever,
      title: context.l10n.nostrSettingsDeleteAccount,
      subtitle: context.l10n.nostrSettingsDeleteAccountSubtitle,
      onTap: () => _handleDeleteAllContent(context, ref),
      iconColor: VineTheme.error,
      titleColor: VineTheme.error,
    );
  }

  Future<void> _handleDeleteAllContent(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final deletionService = ref.read(accountDeletionServiceProvider);
    final authService = ref.read(authServiceProvider);

    await showDeleteAllContentWarningDialog(
      context: context,
      onConfirm: () => executeAccountDeletion(
        context: context,
        deletionService: deletionService,
        authService: authService,
        screenName: 'NostrSettingsScreen',
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? VineTheme.vineGreen),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: VineTheme.lightText, fontSize: 14),
      ),
      trailing: const Icon(Icons.chevron_right, color: VineTheme.lightText),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: VineTheme.vineGreen,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
