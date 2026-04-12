// ABOUTME: New settings hub screen matching Figma design
// ABOUTME: Central entry point for all app settings, accessed via gear icon on profile

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/blocs/settings_account/settings_account_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/models/known_account.dart';
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
import 'package:openvine/screens/settings/bluesky_settings_screen.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:openvine/screens/settings/invites_screen.dart';
import 'package:openvine/screens/settings/legal_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/utils/nostr_apps_platform_support.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unified_logger/unified_logger.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  static const routeName = 'settings';
  static const path = '/settings';

  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';
  late final SettingsAccountCubit _accountCubit;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAppVersion());
    _accountCubit = SettingsAccountCubit(
      authService: ref.read(authServiceProvider),
      draftStorageService: ref.read(draftStorageServiceProvider),
    )..load();
  }

  @override
  void dispose() {
    _accountCubit.close();
    super.dispose();
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
    final accountState = _accountCubit.state;

    if (accountState.hasDrafts) {
      final draftCount = accountState.draftCount;
      final draftWord = draftCount == 1 ? 'draft' : 'drafts';
      final proceedWithWarning = await VineBottomSheet.show<bool>(
        context: context,
        scrollable: false,
        contentTitle: 'Unsaved Drafts',
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'You have $draftCount unsaved $draftWord. '
              'Switching accounts will keep your $draftWord, but '
              'you may want to publish or review '
              '${draftCount == 1 ? 'it' : 'them'} first.',
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              spacing: 16,
              children: [
                Expanded(
                  child: DivineButton(
                    label: 'Cancel',
                    type: DivineButtonType.secondary,
                    expanded: true,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                Expanded(
                  child: DivineButton(
                    label: 'Switch Anyway',
                    type: DivineButtonType.error,
                    expanded: true,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

      if (proceedWithWarning != true) return;
    }

    if (!mounted) return;

    await VineBottomSheet.show<void>(
      context: context,
      children: [
        ...accountState.accounts.map(
          (account) => _AccountSwitchTile(
            account: account,
            isCurrentAccount: account.pubkeyHex == accountState.currentPubkey,
            onTap: () {
              Navigator.of(context).pop();
              _accountCubit.switchToAccount(account.pubkeyHex);
            },
          ),
        ),
        _AddAccountTile(
          onTap: () {
            Navigator.of(context).pop();
            _accountCubit.addNewAccount();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final authState = ref.watch(currentAuthStateProvider);
    final isAuthenticated = authState == AuthState.authenticated;
    final showBluesky = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.blueskyPublishing),
    );
    return BlocProvider.value(
      value: _accountCubit,
      child: Scaffold(
        appBar: DiVineAppBar(
          title: 'Settings',
          showBackButton: true,
          onBackPressed: context.pop,
        ),
        backgroundColor: VineTheme.navGreen,
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
                  title: 'Creator Analytics',
                  divineIcon: DivineIconName.trendUp,
                  onTap: () => context.push(CreatorAnalyticsScreen.path),
                ),
                _SettingsTile(
                  title: 'Support Center',
                  icon: Icons.support_agent,
                  onTap: () => context.push(SupportCenterScreen.path),
                ),

                _SettingsTile(
                  title: 'Notifications',
                  divineIcon: DivineIconName.bellSimple,
                  onTap: () => context.push(NotificationSettingsScreen.path),
                ),
                _SettingsTile(
                  title: 'Content Preferences',
                  divineIcon: DivineIconName.globe,
                  onTap: () => context.push(ContentPreferencesScreen.path),
                ),
                _SettingsTile(
                  title: 'Moderation Controls',
                  divineIcon: DivineIconName.faders,
                  onTap: () => context.push(SafetySettingsScreen.path),
                ),
                if (showBluesky)
                  _SettingsTile(
                    icon: Icons.cloud_upload,
                    title: 'Bluesky Publishing',
                    subtitle: 'Manage crossposting to Bluesky',
                    onTap: () => context.push(BlueskySettingsScreen.path),
                  ),
                _SettingsTile(
                  title: 'Nostr Settings',
                  divineIcon: DivineIconName.graph,
                  onTap: () => context.push(NostrSettingsScreen.path),
                ),
                if (nostrAppsSandboxSupported)
                  _SettingsTile(
                    icon: Icons.apps,
                    title: 'Integrated Apps',
                    subtitle:
                        'Approved third-party apps that run inside Divine',
                    onTap: () {
                      ref.read(forceExploreTabNameProvider.notifier).state =
                          'apps';
                      context.go(ExploreScreen.path);
                    },
                  ),
                _SettingsTile(
                  icon: Icons.science,
                  title: 'Experimental Features',
                  subtitle:
                      'Tweaks that may hiccup—try them if you are curious.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FeatureFlagScreen(),
                    ),
                  ),
                ),
                _SettingsTile(
                  title: 'Legal',
                  icon: Icons.gavel,
                  onTap: () => context.push(LegalScreen.path),
                ),
                _SettingsTile(
                  icon: Icons.lock_open,
                  title: 'Integration Permissions',
                  subtitle:
                      'Review and revoke remembered integration approvals',
                  onTap: () => context.push(AppsPermissionsScreen.path),
                ),

                const SizedBox(height: 24),
                _VersionTile(appVersion: _appVersion),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.onSwitchAccount});

  final VoidCallback onSwitchAccount;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsAccountCubit, SettingsAccountState>(
      builder: (context, accountState) {
        final pubkey = accountState.currentPubkey;
        if (pubkey == null) return const SizedBox.shrink();

        final hasMultipleAccounts = accountState.hasMultipleAccounts;
        final buttonLabel = hasMultipleAccounts
            ? 'Switch account'
            : 'Add another account';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            spacing: 16,
            children: [
              _AccountHeaderProfile(pubkey: pubkey),
              BlocBuilder<InviteStatusCubit, InviteStatusState>(
                builder: (context, inviteState) {
                  if (!inviteState.hasUnclaimedCodes) {
                    return const SizedBox.shrink();
                  }
                  return Semantics(
                    button: true,
                    label: 'Invites',
                    child: InkWell(
                      onTap: () => context.push(InvitesScreen.path),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: VineTheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: VineTheme.outlineMuted,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 8,
                          children: [
                            const DivineIcon(
                              icon: DivineIconName.shareNetwork,
                              color: VineTheme.vineGreen,
                            ),
                            Text(
                              'Invites',
                              style: VineTheme.titleMediumFont(
                                color: VineTheme.vineGreen,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: VineTheme.vineGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${inviteState.unclaimedCount}',
                                style: VineTheme.labelSmallFont(
                                  color: VineTheme.backgroundColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Semantics(
                button: true,
                label: buttonLabel,
                child: InkWell(
                  onTap: onSwitchAccount,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: VineTheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: VineTheme.outlineMuted,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        if (!hasMultipleAccounts)
                          const DivineIcon(
                            icon: DivineIconName.userPlus,
                            color: VineTheme.vineGreen,
                          ),
                        Text(
                          buttonLabel,
                          style: VineTheme.titleMediumFont(
                            color: VineTheme.vineGreen,
                          ),
                        ),
                        if (hasMultipleAccounts)
                          const DivineIcon(
                            icon: DivineIconName.caretDown,
                            color: VineTheme.vineGreen,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Profile avatar, name, and identifier for the account header.
///
/// Uses Riverpod providers for reactive profile data while the parent
/// [_AccountHeader] reads account state from the Cubit.
class _AccountHeaderProfile extends ConsumerWidget {
  const _AccountHeaderProfile({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Column(
      children: [
        UserAvatar(
          imageUrl: profile?.picture,
          name: displayName,
          size: 96,
        ),
        const SizedBox(height: 16),
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

    return Semantics(
      button: true,
      label: 'App version',
      child: InkWell(
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
                  content: Text(
                    '$remaining more taps to enable developer mode',
                  ),
                  duration: const Duration(milliseconds: 500),
                ),
              );
            }
            return;
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _appVersion.isEmpty ? 'Version' : 'Version $_appVersion',
                style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.onTap,
    this.divineIcon,
    this.icon,
    this.iconColor,
    this.subtitle,
  }) : assert(
         divineIcon != null || icon != null,
         '_SettingsTile requires either divineIcon or icon',
       );

  final DivineIconName? divineIcon;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final Widget leadingWidget = divineIcon != null
        ? DivineIcon(
            icon: divineIcon!,
            color: iconColor ?? VineTheme.onSurfaceVariant,
          )
        : Icon(icon, color: iconColor ?? VineTheme.onSurfaceVariant);

    return ListTile(
      minTileHeight: 64,
      leading: leadingWidget,
      title: Text(title, style: VineTheme.titleMediumFont()),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
            )
          : null,
      trailing: const DivineIcon(
        icon: DivineIconName.caretRight,
        color: VineTheme.primary,
      ),
      onTap: onTap,
    );
  }
}

/// A single account row in the account-switcher bottom sheet.
class _AccountSwitchTile extends ConsumerWidget {
  const _AccountSwitchTile({
    required this.account,
    required this.isCurrentAccount,
    required this.onTap,
  });

  final KnownAccount account;
  final bool isCurrentAccount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref
        .watch(userProfileReactiveProvider(account.pubkeyHex))
        .value;
    final displayName =
        profile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(account.pubkeyHex);
    final identifier =
        profile?.displayNip05 ?? NostrKeyUtils.truncateNpub(account.pubkeyHex);

    return Semantics(
      button: true,
      label: displayName,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCurrentAccount
                  ? VineTheme.vineGreen.withValues(alpha: 0.1)
                  : VineTheme.transparent,
            ),
            child: Row(
              spacing: 12,
              children: [
                UserAvatar(
                  imageUrl: profile?.picture,
                  name: displayName,
                  size: 40,
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: VineTheme.titleMediumFont(
                          color: VineTheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        identifier,
                        style: VineTheme.bodyMediumFont(
                          color: VineTheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isCurrentAccount)
                  const DivineIcon(
                    icon: DivineIconName.check,
                    color: VineTheme.vineGreen,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Add account" row at the bottom of the account-switcher sheet.
class _AddAccountTile extends StatelessWidget {
  const _AddAccountTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add another account',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              spacing: 12,
              children: [
                const DivineIcon(
                  icon: DivineIconName.userPlus,
                  color: VineTheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Text(
                    'Add another account',
                    style: VineTheme.titleMediumFont(
                      color: VineTheme.onSurface,
                    ),
                  ),
                ),
                const DivineIcon(
                  icon: DivineIconName.caretRight,
                  color: VineTheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
