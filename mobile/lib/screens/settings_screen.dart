// ABOUTME: Unified settings hub providing access to all app configuration
// ABOUTME: Central entry point for profile, relay, media server, and
// notification settings

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera_macos_plus/camera_macos.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/developer_mode_tap_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/relay_diagnostic_screen.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';
import 'package:openvine/widgets/settings/settings_screen_components.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'settings';

  /// Path for this route.
  static const path = '/settings';

  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadAppVersion());
    Log.debug(
      '👨‍💻 settingsService initState auth',
      name: 'SettingsScreen',
      category: LogCategory.ui,
    );
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
    // Use currentAuthStateProvider for synchronous access to auth state
    // This provider invalidates itself when auth state changes
    final authState = ref.watch(currentAuthStateProvider);
    final isAuthenticated = authState == AuthState.authenticated;

    return Scaffold(
      appBar: DiVineAppBar(
        title: 'Settings',
        showBackButton: true,
        onBackPressed: context.pop,
        backgroundColor: VineTheme.surfaceBackground,
      ),
      backgroundColor: VineTheme.surfaceBackground,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (isAuthenticated) ...[
                _buildAccountSummarySection(authService),
              ],

              const SettingsSectionHeading(
                title: 'Preferences',
                showTopDivider: false,
              ),
              SettingsNavigationRow(
                title: 'Notifications',
                subtitle: 'Manage notification preferences',
                onTap: () => context.push(NotificationSettingsScreen.path),
              ),
              SettingsNavigationRow(
                title: 'Safety & Privacy',
                subtitle: 'Blocked users, muted content, and report history',
                onTap: () => context.push(SafetySettingsScreen.path),
              ),
              _buildAudioSharingToggle(),
              _buildLanguageSetting(),
              if (!kIsWeb && Platform.isMacOS) _buildAudioDeviceSelector(),

              const SettingsSectionHeading(title: 'Nostr Settings'),
              SettingsNavigationRow(
                title: 'Relays',
                subtitle: 'Manage Nostr relay connections',
                onTap: () => context.push(RelaySettingsScreen.path),
              ),
              SettingsNavigationRow(
                title: 'Relay Diagnostics',
                subtitle: 'Debug relay connectivity and network issues',
                onTap: () => context.push(RelayDiagnosticScreen.path),
              ),
              SettingsNavigationRow(
                title: 'Media Servers',
                subtitle: 'Configure Blossom upload servers',
                onTap: () => context.push(BlossomSettingsScreen.path),
              ),
              SettingsNavigationRow(
                title: 'Developer Options',
                subtitle: 'Environment switcher and debug settings',
                onTap: () => context.push(DeveloperOptionsScreen.path),
              ),

              const SettingsSectionHeading(title: 'Support'),
              SettingsNavigationRow(
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
                      await _showSupportFallback(context, ref, authService);
                    }
                  } else {
                    // Zendesk not available, show fallback options
                    if (context.mounted) {
                      await _showSupportFallback(context, ref, authService);
                    }
                  }
                },
              ),
              SettingsNavigationRow(
                title: 'ProofMode Info',
                subtitle: 'Learn about ProofMode verification and authenticity',
                onTap: _openProofModeInfo,
              ),
              SettingsNavigationRow(
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
                        backgroundColor: VineTheme.error,
                      ),
                    );
                  }
                },
              ),

              if (isAuthenticated) ...[
                const SettingsSectionHeading(title: 'Account Tools'),
                SettingsNavigationRow(
                  title: 'Key Management',
                  subtitle: 'Export, backup, and restore your Nostr keys',
                  onTap: () => context.push(KeyManagementScreen.path),
                ),
                SettingsNavigationRow(
                  title: 'Remove Keys from Device',
                  subtitle:
                      'Delete your private key from this device only. '
                      "Your content stays on relays, but you'll need your "
                      'nsec backup to access your account again.',
                  onTap: () => _handleRemoveKeys(context, ref),
                  titleColor: VineTheme.warning,
                ),
                const SettingsSectionHeading(title: 'Danger Zone'),
                SettingsNavigationRow(
                  title: 'Delete Account and Data',
                  subtitle:
                      'PERMANENTLY delete your account and ALL content from Nostr relays. This cannot be undone.',
                  onTap: () => _handleDeleteAllContent(context, ref),
                  titleColor: VineTheme.error,
                ),
              ],

              _VersionTile(appVersion: _appVersion),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSummarySection(AuthService authService) {
    final userPubkey = authService.currentPublicKeyHex;
    final profile = userPubkey == null
        ? null
        : ref.watch(userProfileReactiveProvider(userPubkey)).value;
    final npub = userPubkey == null
        ? null
        : NostrKeyUtils.encodePubKey(userPubkey);
    final profileSubtitleParts = <String>[
      ...switch (profile?.nip05) {
        final nip05? when nip05.isNotEmpty => [nip05],
        _ => const <String>[],
      },
      ?npub,
    ];

    final title = switch ((
      authService.hasExpiredOAuthSession,
      authService.isAnonymous,
    )) {
      (true, _) => 'Session expired',
      (false, true) => 'Local account',
      _ => profile?.bestDisplayName ?? 'Currently logged in',
    };

    final subtitle = switch ((
      authService.hasExpiredOAuthSession,
      authService.isAnonymous,
    )) {
      (true, _) => 'Sign in again to restore full access.',
      (false, true) => [
        'Add email and password to recover this account on any device.',
        ?npub,
      ].join('\n'),
      _ => [
        ...profileSubtitleParts,
        if (profileSubtitleParts.isEmpty)
          'Your current account is ready on this device.',
      ].join('\n'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsAccountSummaryBlock(
          title: title,
          subtitle: subtitle,
          bottomMargin: EdgeInsets.zero,
        ),
        if (authService.hasExpiredOAuthSession)
          SettingsNavigationRow(
            title: 'Session Expired',
            subtitle: 'Sign in again to restore full access.',
            onTap: () async {
              final router = GoRouter.of(context);
              final refreshed = await authService.tryRefreshExpiredSession();
              if (!mounted) return;
              if (!refreshed) {
                router.go(WelcomeScreen.loginOptionsPath);
              }
            },
          ),
        if (authService.isAnonymous)
          SettingsNavigationRow(
            title: 'Secure Your Account',
            subtitle: 'Add email and password to recover your account.',
            onTap: () => context.push(SecureAccountScreen.path),
          ),
        SettingsNavigationRow(
          title: 'Switch Account',
          subtitle:
              'Use a different account without removing saved keys from this device.',
          onTap: _handleSwitchAccount,
        ),
      ],
    );
  }

  Widget _buildAudioSharingToggle() {
    final audioSharingService = ref.watch(
      audioSharingPreferenceServiceProvider,
    );
    final isEnabled = audioSharingService.isAudioSharingEnabled;

    return SettingsToggleRow(
      value: isEnabled,
      onChanged: (value) async {
        await audioSharingService.setAudioSharingEnabled(value);
        setState(() {});
      },
      title: 'Make my audio available for reuse',
      subtitle: 'When enabled, others can use audio from your videos',
    );
  }

  Widget _buildLanguageSetting() {
    final languageService = ref.watch(languagePreferenceServiceProvider);
    final currentCode = languageService.contentLanguage;
    final isCustom = languageService.isCustomLanguageSet;
    final displayName = LanguagePreferenceService.displayNameFor(currentCode);
    final subtitle = isCustom ? displayName : '$displayName (device default)';

    return SettingsNavigationRow(
      title: 'Content Language',
      subtitle: subtitle,
      onTap: _showLanguagePicker,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: VineTheme.onSurfaceVariant,
            size: 24,
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguagePicker() async {
    final languageService = ref.read(languagePreferenceServiceProvider);
    final currentCode = languageService.contentLanguage;
    final isCustom = languageService.isCustomLanguageSet;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Content Language',
                  style: TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Tag your videos with a language so viewers can filter content.',
                  style: TextStyle(color: VineTheme.lightText, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: VineTheme.lightText, height: 1),
              ListTile(
                leading: Icon(
                  !isCustom
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: VineTheme.vineGreen,
                ),
                title: const Text(
                  'Use device language (default)',
                  style: TextStyle(color: VineTheme.whiteText),
                ),
                subtitle: Text(
                  LanguagePreferenceService.displayNameFor(
                    PlatformDispatcher.instance.locale.languageCode,
                  ),
                  style: const TextStyle(
                    color: VineTheme.lightText,
                    fontSize: 12,
                  ),
                ),
                onTap: () async {
                  await languageService.clearContentLanguage();
                  if (context.mounted) {
                    setState(() {});
                    Navigator.pop(context);
                  }
                },
              ),
              const Divider(color: VineTheme.lightText, height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount:
                      LanguagePreferenceService.supportedLanguages.length,
                  itemBuilder: (context, index) {
                    final entry = LanguagePreferenceService
                        .supportedLanguages
                        .entries
                        .elementAt(index);
                    final code = entry.key;
                    final name = entry.value;
                    final isSelected = isCustom && currentCode == code;

                    return ListTile(
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: VineTheme.vineGreen,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(color: VineTheme.whiteText),
                      ),
                      subtitle: Text(
                        code.toUpperCase(),
                        style: const TextStyle(
                          color: VineTheme.lightText,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () async {
                        await languageService.setContentLanguage(code);
                        if (context.mounted) {
                          setState(() {});
                          Navigator.pop(context);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Audio input device selector for macOS.
  /// Shows available microphones and lets user choose one.
  Widget _buildAudioDeviceSelector() {
    final audioDevicePref = ref.watch(audioDevicePreferenceServiceProvider);

    return FutureBuilder<List<CameraMacOSDevice>>(
      future: CameraMacOS.instance.listDevices(
        deviceType: CameraMacOSDeviceType.audio,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.length <= 1) {
          return const SizedBox.shrink();
        }

        final devices = snapshot.data!;
        final currentDevice = audioDevicePref.preferredDeviceId;

        String currentDisplayName;
        if (currentDevice == null) {
          currentDisplayName = 'Auto (recommended)';
        } else {
          final device = devices.where((d) => d.deviceId == currentDevice);
          currentDisplayName = device.isNotEmpty
              ? _formatAudioDeviceName(device.first.deviceId)
              : 'Auto (recommended)';
        }

        return SettingsNavigationRow(
          title: 'Audio Input Device',
          subtitle: currentDisplayName,
          onTap: () => _showAudioDevicePicker(devices, currentDevice),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  currentDisplayName,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: VineTheme.onSurfaceVariant,
                size: 24,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Format device ID into a readable name
  String _formatAudioDeviceName(String deviceId) {
    // Common device ID patterns on macOS
    if (deviceId.toLowerCase().contains('builtinmicrophone')) {
      return 'Built-in Microphone';
    }
    if (deviceId.toLowerCase().contains('zoom')) {
      return 'Zoom Audio Device';
    }
    // Clean up other device IDs
    return deviceId
        .replaceAll('Device', '')
        .replaceAll('device', '')
        .replaceAll(RegExp('[0-9a-f]{8}-[0-9a-f]{4}-.*'), '')
        .trim();
  }

  /// Show bottom sheet picker for audio devices
  Future<void> _showAudioDevicePicker(
    List<CameraMacOSDevice> devices,
    String? currentDevice,
  ) async {
    final audioDevicePref = ref.read(audioDevicePreferenceServiceProvider);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Audio Input',
                style: TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: VineTheme.lightText, height: 1),
            // Auto option
            ListTile(
              leading: Icon(
                currentDevice == null
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: VineTheme.vineGreen,
              ),
              title: const Text(
                'Auto (recommended)',
                style: TextStyle(color: VineTheme.whiteText),
              ),
              subtitle: const Text(
                'Automatically selects the best microphone',
                style: TextStyle(color: VineTheme.lightText, fontSize: 12),
              ),
              onTap: () async {
                await audioDevicePref.setPreferredDeviceId(null);
                if (context.mounted) {
                  setState(() {});
                  Navigator.pop(context);
                }
              },
            ),
            const Divider(color: VineTheme.lightText, height: 1),
            // Device list
            ...devices.map(
              (device) => ListTile(
                leading: Icon(
                  currentDevice == device.deviceId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: VineTheme.vineGreen,
                ),
                title: Text(
                  _formatAudioDeviceName(device.deviceId),
                  style: const TextStyle(color: VineTheme.whiteText),
                ),
                subtitle: Text(
                  device.deviceId,
                  style: const TextStyle(
                    color: VineTheme.lightText,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () async {
                  await audioDevicePref.setPreferredDeviceId(device.deviceId);
                  if (context.mounted) {
                    setState(() {});
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSwitchAccount() async {
    // Check for existing drafts before showing switch account confirmation
    final draftService = ref.read(draftStorageServiceProvider);
    final draftCount = await draftService.getDraftCount();

    if (!mounted) return;

    // If drafts exist, show warning dialog first
    if (draftCount > 0) {
      final draftWord = draftCount == 1 ? 'draft' : 'drafts';
      final proceedWithWarning = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: VineTheme.cardBackground,
          title: const Text(
            'Unsaved Drafts',
            style: TextStyle(color: VineTheme.error),
          ),
          content: Text(
            'You have $draftCount unsaved $draftWord. '
            'Switching accounts will keep your $draftWord, but you may want to publish or review ${draftCount == 1 ? 'it' : 'them'} first.\n\n'
            'Do you want to switch accounts anyway?',
            style: const TextStyle(color: VineTheme.lightText),
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: VineTheme.lightText),
              ),
            ),
            TextButton(
              onPressed: () => context.pop(true),
              child: const Text(
                'Switch Anyway',
                style: TextStyle(color: VineTheme.error),
              ),
            ),
          ],
        ),
      );

      if (proceedWithWarning != true) return;
    }

    if (!mounted) return;

    // Show standard confirmation dialog
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Switch Account?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: const Text(
          'You will be taken to the sign in screen where you can:\n\n'
          '• Continue with your saved keys\n'
          '• Import a different account\n'
          '• Create a new identity\n\n'
          'Your current keys will stay saved on this device.',
          style: TextStyle(color: VineTheme.lightText),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: VineTheme.lightText),
            ),
          ),
          TextButton(
            onPressed: () {
              final authService = ref.read(authServiceProvider);
              authService.signOut();
              context.pop(true);
            },
            child: const Text(
              'Switch Account',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
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

        // show busy dialog, but don't await it as the code needs to continue
        // to signOut the user and deleteKeys. Changing the authentication state
        // will redirect the user away and cause this to close.
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
          // Sign out and delete keys (no relay broadcast)
          await authService.signOut(deleteKeys: true);

          // Router will automatically redirect to /welcome when auth state becomes unauthenticated
          // User can import their keys from the welcome screen
        } catch (e) {
          // Close loading indicator
          if (!context.mounted) return;
          context.pop();

          // Show error
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to remove keys: $e',
                style: const TextStyle(color: VineTheme.whiteText),
              ),
              backgroundColor: VineTheme.error,
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

    // Show confirmation dialog, then execute deletion
    await showDeleteAllContentWarningDialog(
      context: context,
      onConfirm: () => executeAccountDeletion(
        context: context,
        deletionService: deletionService,
        authService: authService,
        screenName: 'SettingsScreen',
      ),
    );
  }

  /// Open ProofMode info page at divine.video/proofmode
  Future<void> _openProofModeInfo() async {
    final url = Uri.parse('https://divine.video/proofmode');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open ProofMode info page'),
              backgroundColor: VineTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open URL: $e'),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }

  /// Show fallback support options when Zendesk is not available
  Future<void> _showSupportFallback(
    BuildContext context,
    WidgetRef ref,
    AuthService authService,
  ) async {
    final bugReportService = ref.read(bugReportServiceProvider);
    final userPubkey = authService.currentPublicKeyHex;

    // Set Zendesk user identity if we have a pubkey
    if (userPubkey != null) {
      try {
        // Get user's npub
        final npub = NostrKeyUtils.encodePubKey(userPubkey);

        // Try to get user profile for display name and NIP-05
        final profile = ref.read(userProfileReactiveProvider(userPubkey)).value;

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

    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => BugReportDialog(
          bugReportService: bugReportService,
          currentScreen: 'SettingsScreen',
          userPubkey: userPubkey,
        ),
      ),
    );
  }
}

class _VersionTile extends ConsumerWidget {
  const _VersionTile({required String appVersion}) : _appVersion = appVersion;

  final String _appVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDeveloperMode = ref.watch(isDeveloperModeEnabledProvider);
    final environmentService = ref.watch(environmentServiceProvider);

    // Read the new count after tapping
    final newCount = ref.watch(developerModeTapCounterProvider);

    return SettingsFooterRow(
      label: _appVersion.isEmpty
          ? 'Version loading...'
          : 'Version $_appVersion',
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
          '👨‍💻 Dev mode count: $newCount',
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
          return;
        }

        if (newCount >= 4) {
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
          return;
        }
      },
    );
  }
}
