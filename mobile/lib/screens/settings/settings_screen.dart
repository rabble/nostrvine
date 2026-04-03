// ABOUTME: New settings hub screen matching Figma design
// ABOUTME: Central entry point for all app settings, accessed via gear icon on profile

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/developer_mode_tap_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/apps/apps_permissions_screen.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:openvine/screens/settings/legal_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/utils/nostr_apps_platform_support.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  static const routeName = 'settings';
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
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
    });
  }

  Future<void> _handleSessionExpired() async {
    final authService = ref.read(authServiceProvider);
    final router = GoRouter.of(context);
    final refreshed = await authService.tryRefreshExpiredSession();
    if (!mounted) return;
    if (!refreshed) {
      router.go(WelcomeScreen.loginOptionsPath);
    }
  }

  Future<void> _handleSwitchAccount() async {
    final draftService = ref.read(draftStorageServiceProvider);
    final draftCount = await draftService.getDraftCount();

    if (!mounted) return;

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
            'Switching accounts will keep your $draftWord, but '
            'you may want to publish or review '
            '${draftCount == 1 ? 'it' : 'them'} first.\n\n'
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

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Switch Account?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: const Text(
          'You will be taken to the sign in screen where you '
          'can:\n\n'
          '\u2022 Continue with your saved keys\n'
          '\u2022 Import a different account\n'
          '\u2022 Create a new identity\n\n'
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

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final authState = ref.watch(currentAuthStateProvider);
    final isAuthenticated = authState == AuthState.authenticated;

    return Scaffold(
      appBar: DiVineAppBar(
        title: 'Settings',
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
              // Account header
              if (isAuthenticated) ...[
                _AccountHeader(onSwitchAccount: _handleSwitchAccount),
                if (authService.isAnonymous)
                  _SettingsTile(
                    icon: Icons.security,
                    title: 'Secure Your Account',
                    subtitle:
                        'Add email & password to recover your '
                        'account on any device',
                    onTap: () => context.push(SecureAccountScreen.path),
                  ),
                if (!authService.isAnonymous &&
                    authService.hasExpiredOAuthSession)
                  _SettingsTile(
                    icon: Icons.refresh,
                    title: 'Session Expired',
                    subtitle: 'Sign in again to restore full access',
                    onTap: _handleSessionExpired,
                    iconColor: VineTheme.accentOrange,
                  ),
              ],

              _SettingsTile(
                icon: Icons.analytics_outlined,
                title: 'Creator Analytics',
                subtitle: 'View your video performance',
                onTap: () => context.push(CreatorAnalyticsScreen.path),
              ),
              _SettingsTile(
                icon: Icons.support_agent,
                title: 'Support Center',
                subtitle: 'Report bugs, request features, view FAQ',
                onTap: () => context.push(SupportCenterScreen.path),
              ),

              _SettingsTile(
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Manage notification preferences',
                onTap: () => context.push(NotificationSettingsScreen.path),
              ),
              _SettingsTile(
                icon: Icons.tune,
                title: 'Content Preferences',
                subtitle: 'Language, audio, and content filters',
                onTap: () => context.push(ContentPreferencesScreen.path),
              ),
              _SettingsTile(
                icon: Icons.shield,
                title: 'Moderation Controls',
                subtitle: 'Blocked users, muted content, and reports',
                onTap: () => context.push(SafetySettingsScreen.path),
              ),
              _SettingsTile(
                icon: Icons.hub,
                title: 'Nostr Settings',
                subtitle: 'Relays, media servers, keys, and account',
                onTap: () => context.push(NostrSettingsScreen.path),
              ),
              if (nostrAppsSandboxSupported)
                _SettingsTile(
                  icon: Icons.apps,
                  title: 'Integrated Apps',
                  subtitle: 'Approved third-party apps that run inside Divine',
                  onTap: () {
                    ref.read(forceExploreTabNameProvider.notifier).state =
                        'apps';
                    context.go(ExploreScreen.path);
                  },
                ),
              _SettingsTile(
                icon: Icons.science,
                title: 'Experimental Features',
                subtitle: 'Tweaks that may hiccup—try them if you are curious.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FeatureFlagScreen(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.gavel,
                title: 'Legal',
                subtitle:
                    'Terms of Service, Privacy Policy, Safety Standards, '
                    'DMCA, Open Source Licenses',
                onTap: () => context.push(LegalScreen.path),
              ),
              _SettingsTile(
                icon: Icons.lock_open,
                title: 'Integration Permissions',
                subtitle: 'Review and revoke remembered integration approvals',
                onTap: () => context.push(AppsPermissionsScreen.path),
              ),

              const SizedBox(height: 24),
              _VersionTile(appVersion: _appVersion),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountHeader extends ConsumerWidget {
  const _AccountHeader({required this.onSwitchAccount});

  final VoidCallback onSwitchAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final pubkey = authService.currentPublicKeyHex;
    if (pubkey == null) return const SizedBox.shrink();

    final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
    final displayName =
        profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey);

    final truncatedNpub = NostrKeyUtils.truncateNpub(pubkey);
    final claimedNip05 = profile?.displayNip05;
    final verificationStatus = claimedNip05 != null && claimedNip05.isNotEmpty
        ? ref
              .watch(nip05VerificationProvider(pubkey))
              .whenOrNull(data: (status) => status)
        : null;
    final hasVerifiedNip05 =
        verificationStatus == Nip05VerificationStatus.verified;
    final uniqueIdentifier = hasVerifiedNip05 && claimedNip05 != null
        ? claimedNip05
        : truncatedNpub;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        spacing: 16,
        children: [
          UserAvatar(
            imageUrl: profile?.picture,
            name: displayName,
            size: 96,
          ),
          Column(
            children: [
              Text(
                displayName,
                style: VineTheme.headlineSmallFont(
                  color: VineTheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                uniqueIdentifier,
                style: VineTheme.bodyMediumFont(
                  color: VineTheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          GestureDetector(
            onTap: onSwitchAccount,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: VineTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: VineTheme.outlineMuted,
                  width: 2,
                ),
              ),
              child: Text(
                'Switch account',
                style: VineTheme.titleMediumFont(
                  color: VineTheme.vineGreen,
                ),
              ),
            ),
          ),
        ],
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
    final newCount = ref.watch(developerModeTapCounterProvider);

    return ListTile(
      leading: const Icon(Icons.info, color: VineTheme.vineGreen),
      title: const Text(
        'Version',
        style: TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _appVersion.isEmpty ? 'Loading...' : _appVersion,
        style: const TextStyle(color: VineTheme.lightText, fontSize: 14),
      ),
      onTap: () async {
        if (isDeveloperMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Developer mode is already enabled'),
              backgroundColor: VineTheme.vineGreen,
            ),
          );
          return;
        }

        ref.read(developerModeTapCounterProvider.notifier).tap();

        Log.debug(
          'Dev mode count: $newCount',
          name: 'SettingsScreen',
          category: LogCategory.ui,
        );

        if (newCount >= 7) {
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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? VineTheme.vineGreen),
      title: Text(
        title,
        style: const TextStyle(
          color: VineTheme.whiteText,
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
