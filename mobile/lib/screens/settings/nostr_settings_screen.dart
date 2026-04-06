// ABOUTME: Nostr settings hub screen for relays, media servers, keys, and account
// ABOUTME: Organizes network and account settings with danger zone actions

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyStorageException;
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
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
    final authState = ref.watch(currentAuthStateProvider);
    final isAuthenticated = authState == AuthState.authenticated;

    return Scaffold(
      appBar: DiVineAppBar(
        title: 'Nostr Settings',
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Divine uses the Nostr protocol for decentralized '
                  'publishing. Your content lives on relays you choose, '
                  'and your keys are your identity.',
                  style: TextStyle(color: VineTheme.lightText, fontSize: 14),
                ),
              ),

              // Network section
              const _SectionHeader(title: 'Network'),
              _SettingsTile(
                icon: Icons.hub,
                title: 'Relays',
                subtitle: 'Manage Nostr relay connections',
                onTap: () => context.push(RelaySettingsScreen.path),
              ),
              _SettingsTile(
                icon: Icons.troubleshoot,
                title: 'Relay Diagnostics',
                subtitle: 'Debug relay connectivity and network issues',
                onTap: () => context.push(RelayDiagnosticScreen.path),
              ),
              _SettingsTile(
                icon: Icons.cloud_upload,
                title: 'Media Servers',
                subtitle: 'Configure Blossom upload servers',
                onTap: () => context.push(BlossomSettingsScreen.path),
              ),
              if (isDeveloperMode)
                _SettingsTile(
                  icon: Icons.developer_mode,
                  title: 'Developer Options',
                  subtitle: 'Environment switcher and debug settings',
                  onTap: () => context.push(DeveloperOptionsScreen.path),
                  iconColor: VineTheme.warning,
                ),
              _SettingsTile(
                icon: Icons.science,
                title: 'Experimental Features',
                subtitle: 'Toggle feature flags that may hiccup.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FeatureFlagScreen(),
                  ),
                ),
              ),

              // Account section
              if (isAuthenticated) ...[
                const _SectionHeader(title: 'Account'),
                _SettingsTile(
                  icon: Icons.key,
                  title: 'Key Management',
                  subtitle: 'Export, backup, and restore your Nostr keys',
                  onTap: () => context.push(KeyManagementScreen.path),
                ),
                _RemoveKeysTile(ref: ref),
                const _SectionHeader(title: 'Danger Zone'),
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
      title: 'Remove Keys from Device',
      subtitle:
          'Delete your private key from this device only. '
          "Your content stays on relays, but you'll need your "
          'nsec backup to access your account again.',
      onTap: () => _handleRemoveKeys(context, ref),
      iconColor: VineTheme.warning,
      titleColor: VineTheme.warning,
    );
  }

  Future<void> _handleRemoveKeys(BuildContext context, WidgetRef ref) async {
    final authService = ref.read(authServiceProvider);

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
              'Could not remove keys from this device. '
              'Please try again.',
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
              'Failed to remove keys: $e',
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
      title: 'Delete Account and Data',
      subtitle:
          'PERMANENTLY delete your account and ALL content from Nostr '
          'relays. This cannot be undone.',
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
