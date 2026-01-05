// ABOUTME: Unified settings hub providing access to all app configuration
// ABOUTME: Central entry point for profile, relay, media server, and notification settings

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/developer_mode_tap_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';
  // Store notifier reference to safely call in deactivate
  OverlayVisibility? _overlayNotifier;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    // Mark settings as open to pause video playback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayNotifier = ref.read(overlayVisibilityProvider.notifier);
      _overlayNotifier?.setSettingsOpen(true);
    });
  }

  @override
  void dispose() {
    // Mark settings as closed when leaving
    // Use cached notifier reference since ref is invalid during dispose
    _overlayNotifier?.setSettingsOpen(false);
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final isAuthenticated = authService.isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leadingWidth: 80,
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: VineTheme.navGreen,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VineTheme.iconButtonBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SvgPicture.asset(
              'assets/icon/CaretLeft.svg',
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: Text('Settings', style: VineTheme.titleFont()),
      ),
      backgroundColor: Colors.black,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              // Profile Section
              if (isAuthenticated) ...[
                _buildSectionHeader('Profile'),
                _buildSettingsTile(
                  context,
                  icon: Icons.person,
                  title: 'Edit Profile',
                  subtitle: 'Update your display name, bio, and avatar',
                  onTap: () => context.push('/edit-profile'),
                ),
              ],

              // Preferences - most used settings near the top
              _buildSectionHeader('Preferences'),
              _buildSettingsTile(
                context,
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Manage notification preferences',
                onTap: () => context.push('/notification-settings'),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.shield,
                title: 'Safety & Privacy',
                subtitle: 'Blocked users, muted content, and report history',
                onTap: () => context.push('/safety-settings'),
              ),
              _buildAudioSharingToggle(),

              // Network Configuration
              _buildSectionHeader('Network'),
              _buildSettingsTile(
                context,
                icon: Icons.hub,
                title: 'Relays',
                subtitle: 'Manage Nostr relay connections',
                onTap: () => context.push('/relay-settings'),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.troubleshoot,
                title: 'Relay Diagnostics',
                subtitle: 'Debug relay connectivity and network issues',
                onTap: () => context.push('/relay-diagnostic'),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.cloud_upload,
                title: 'Media Servers',
                subtitle: 'Configure Blossom upload servers',
                onTap: () => context.push('/blossom-settings'),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.developer_mode,
                title: 'Developer Options',
                subtitle: 'Environment switcher and debug settings',
                onTap: () => context.push('/developer-options'),
                iconColor: Colors.orange,
              ),

              // About
              _buildSectionHeader('About'),
              _buildVersionTile(context, ref),

              // Support
              _buildSectionHeader('Support'),
              _buildSettingsTile(
                context,
                icon: Icons.verified_user,
                title: 'ProofMode Info',
                subtitle: 'Learn about ProofMode verification and authenticity',
                onTap: () => _openProofModeInfo(context),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.support_agent,
                title: 'Contact Support',
                subtitle: 'Get help or report an issue',
                onTap: () async {
                  // Try Zendesk first, fallback to email if not available
                  if (ZendeskSupportService.isAvailable) {
                    final success =
                        await ZendeskSupportService.showNewTicketScreen(
                          subject: 'Support Request',
                          tags: ['mobile', 'support'],
                        );

                    if (!success && context.mounted) {
                      // Zendesk failed, show fallback options
                      _showSupportFallback(context, ref, authService);
                    }
                  } else {
                    // Zendesk not available, show fallback options
                    if (context.mounted) {
                      _showSupportFallback(context, ref, authService);
                    }
                  }
                },
              ),
              _buildSettingsTile(
                context,
                icon: Icons.save,
                title: 'Save Logs',
                subtitle: 'Export logs to file for manual sending',
                onTap: () async {
                  final bugReportService = ref.read(bugReportServiceProvider);
                  final userPubkey = authService.currentPublicKeyHex;

                  // Show loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Exporting logs...'),
                      duration: Duration(seconds: 2),
                    ),
                  );

                  final success = await bugReportService.exportLogsToFile(
                    currentScreen: 'SettingsScreen',
                    userPubkey: userPubkey,
                  );

                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to export logs'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),

              // Account and key management actions at the bottom
              if (isAuthenticated) ...[
                _buildSectionHeader('Account'),
                _buildSettingsTile(
                  context,
                  icon: Icons.logout,
                  title: 'Log Out',
                  subtitle:
                      'Sign out of your account. Your keys stay on this device and you can log back in later. Your content remains on relays.',
                  onTap: () => _handleLogout(context, ref),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.key,
                  title: 'Key Management',
                  subtitle: 'Export, backup, and restore your Nostr keys',
                  onTap: () => context.push('/key-management'),
                ),
                _buildSettingsTile(
                  context,
                  icon: Icons.key_off,
                  title: 'Remove Keys from Device',
                  subtitle:
                      'Delete your private key from this device only. Your content stays on relays, but you\'ll need your nsec backup to access your account again.',
                  onTap: () => _handleRemoveKeys(context, ref),
                  iconColor: Colors.orange,
                  titleColor: Colors.orange,
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Danger Zone'),
                _buildSettingsTile(
                  context,
                  icon: Icons.delete_forever,
                  title: 'Delete Account and Data',
                  subtitle:
                      'PERMANENTLY delete your account and ALL content from Nostr relays. This cannot be undone.',
                  onTap: () => _handleDeleteAllContent(context, ref),
                  iconColor: Colors.red,
                  titleColor: Colors.red,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
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

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) => ListTile(
    leading: Icon(icon, color: iconColor ?? VineTheme.vineGreen),
    title: Text(
      title,
      style: TextStyle(
        color: titleColor ?? Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: Colors.grey, fontSize: 14),
    ),
    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    onTap: onTap,
  );

  Widget _buildAudioSharingToggle() {
    final audioSharingService = ref.watch(
      audioSharingPreferenceServiceProvider,
    );
    final isEnabled = audioSharingService.isAudioSharingEnabled;

    return SwitchListTile(
      value: isEnabled,
      onChanged: (value) async {
        await audioSharingService.setAudioSharingEnabled(value);
        // Force rebuild to reflect the new state
        setState(() {});
      },
      title: const Text(
        'Make my audio available for reuse',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: const Text(
        'When enabled, others can use audio from your videos',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
      activeThumbColor: VineTheme.vineGreen,
      secondary: const Icon(Icons.music_note, color: VineTheme.vineGreen),
    );
  }

  Widget _buildVersionTile(BuildContext context, WidgetRef ref) {
    final isDeveloperMode = ref.watch(isDeveloperModeEnabledProvider);
    final environmentService = ref.watch(environmentServiceProvider);

    // Read the new count after tapping
    final newCount = ref.watch(developerModeTapCounterProvider);

    return ListTile(
      leading: const Icon(Icons.info, color: VineTheme.vineGreen),
      title: const Text(
        'Version',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _appVersion.isEmpty ? 'Loading...' : _appVersion,
        style: const TextStyle(color: Colors.grey, fontSize: 14),
      ),
      onTap: () async {
        if (isDeveloperMode) {
          // Already unlocked - show message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Developer mode is already enabled'),
              backgroundColor: VineTheme.vineGreen,
            ),
          );
          return;
        }

        // Increment tap counter
        ref.read(developerModeTapCounterProvider.notifier).tap();

        Log.debug(
          '👨‍💻 Dev mode count: ${newCount}',
          name: 'SettingsScreen',
          category: LogCategory.ui,
        );

        if (newCount >= 7) {
          // Unlock developer mode
          await environmentService.enableDeveloperMode();
          ref.read(developerModeTapCounterProvider.notifier).reset();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Developer mode enabled!'),
                backgroundColor: VineTheme.vineGreen,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else if (newCount >= 4) {
          // Show hint message
          final remaining = 7 - newCount;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$remaining more taps to enable developer mode'),
                duration: const Duration(milliseconds: 500),
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final authService = ref.read(authServiceProvider);

    // Check for existing drafts before showing logout confirmation
    final prefs = await SharedPreferences.getInstance();
    final draftService = DraftStorageService(prefs);
    final drafts = await draftService.getAllDrafts();
    final draftCount = drafts.length;

    if (!context.mounted) return;

    // If drafts exist, show warning dialog first
    if (draftCount > 0) {
      final draftWord = draftCount == 1 ? 'draft' : 'drafts';
      final proceedWithWarning = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: VineTheme.cardBackground,
          title: const Text(
            'Unsaved Drafts',
            style: TextStyle(color: Colors.red),
          ),
          content: Text(
            'You have $draftCount unsaved $draftWord. '
            'Logging out will keep your $draftWord, but you may want to publish or review ${draftCount == 1 ? 'it' : 'them'} first.\n\n'
            'Do you want to log out anyway?',
            style: const TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Log Out Anyway',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );

      if (proceedWithWarning != true) return;
    }

    if (!context.mounted) return;

    // Show standard confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Log Out?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: const Text(
          'Are you sure you want to log out? Your keys will be saved and you can log back in later.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Sign out (keeps keys for re-login)
    // Router will automatically redirect to /welcome when auth state becomes unauthenticated
    await authService.signOut(deleteKeys: false);
  }

  /// Handle removing keys from device only (no relay broadcast)
  Future<void> _handleRemoveKeys(BuildContext context, WidgetRef ref) async {
    final authService = ref.read(authServiceProvider);

    // Show warning dialog
    await showRemoveKeysWarningDialog(
      context: context,
      onConfirm: () async {
        // Show loading indicator
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
        );

        try {
          // Sign out and delete keys (no relay broadcast)
          await authService.signOut(deleteKeys: true);

          // Close loading indicator
          if (!context.mounted) return;
          Navigator.of(context).pop();

          // Router will automatically redirect to /welcome when auth state becomes unauthenticated
          // User can import their keys from the welcome screen
        } catch (e) {
          // Close loading indicator
          if (!context.mounted) return;
          Navigator.of(context).pop();

          // Show error
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to remove keys: $e',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  /// Handle deleting ALL content from Nostr relays (nuclear option)
  Future<void> _handleDeleteAllContent(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final deletionService = ref.read(accountDeletionServiceProvider);
    final authService = ref.read(authServiceProvider);

    // Get current user's public key for nsec verification
    final currentPublicKeyHex = authService.currentPublicKeyHex;
    if (currentPublicKeyHex == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to verify identity. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show nsec verification dialog first, then standard delete dialog
    await showDeleteAllContentWarningDialog(
      context: context,
      currentPublicKeyHex: currentPublicKeyHex,
      onConfirm: () async {
        // Show loading indicator
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
        );

        // Execute NIP-62 deletion request
        final result = await deletionService.deleteAccount();

        // Close loading indicator
        if (!context.mounted) return;
        Navigator.of(context).pop();

        if (result.success) {
          // Sign out and delete keys
          // Router will automatically redirect to /welcome when auth state becomes unauthenticated
          await authService.signOut(deleteKeys: true);

          // Show completion dialog
          if (!context.mounted) return;
          await showDeleteAccountCompletionDialog(
            context: context,
            onCreateNewAccount: () => Navigator.of(context).pop(),
          );
        } else {
          // Show error
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.error ?? 'Failed to delete content from relays',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  /// Open ProofMode info page at divine.video/proofmode
  Future<void> _openProofModeInfo(BuildContext context) async {
    final url = Uri.parse('https://divine.video/proofmode');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open ProofMode info page'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show fallback support options when Zendesk is not available
  Future<void> _showSupportFallback(
    BuildContext context,
    WidgetRef ref,
    dynamic authService, // Type inferred from authServiceProvider
  ) async {
    final bugReportService = ref.read(bugReportServiceProvider);
    final userPubkey = authService.currentPublicKeyHex;

    // Set Zendesk user identity if we have a pubkey
    if (userPubkey != null) {
      try {
        // Get user's npub
        final npub = NostrKeyUtils.encodePubKey(userPubkey);

        // Try to get user profile for display name and NIP-05
        final userProfileService = ref.read(userProfileServiceProvider);
        final profile = userProfileService.getCachedProfile(userPubkey);

        await ZendeskSupportService.setUserIdentity(
          displayName: profile?.bestDisplayName,
          nip05: profile?.nip05,
          npub: npub,
        );
      } catch (e) {
        Log.warning(
          'Failed to set Zendesk identity: $e',
          category: LogCategory.system,
        );
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => BugReportDialog(
        bugReportService: bugReportService,
        currentScreen: 'SettingsScreen',
        userPubkey: userPubkey,
      ),
    );
  }
}
