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
import 'package:openvine/l10n/l10n.dart';
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
import 'package:openvine/screens/settings/general_settings_screen.dart';
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
    unawaited(context.read<InviteStatusCubit?>()?.load());
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
      final proceedWithWarning = await VineBottomSheet.show<bool>(
        context: context,
        scrollable: false,
        contentTitle: context.l10n.settingsUnsavedDraftsTitle,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              context.l10n.settingsUnsavedDraftsMessage(draftCount),
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
                    label: context.l10n.settingsCancel,
                    type: DivineButtonType.secondary,
                    expanded: true,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                Expanded(
                  child: DivineButton(
                    label: context.l10n.settingsSwitchAnyway,
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
    final accountSwitchingEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.accountSwitching),
    );
    return BlocProvider.value(
      value: _accountCubit,
      child: Scaffold(
        appBar: DiVineAppBar(
          title: context.l10n.settingsTitle,
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
                  _AccountHeader(
                    onSwitchAccount: _handleSwitchAccount,
                    accountSwitchingEnabled: accountSwitchingEnabled,
                  ),
                  if (authService.isAnonymous)
                    _SettingsTile(
                      icon: Icons.security,
                      title: context.l10n.settingsSecureAccount,
                      onTap: () => context.push(SecureAccountScreen.path),
                    ),
                  if (!authService.isAnonymous &&
                      authService.hasExpiredOAuthSession)
                    _SettingsTile(
                      icon: Icons.refresh,
                      title: context.l10n.settingsSessionExpired,
                      subtitle: context.l10n.settingsSessionExpiredSubtitle,
                      onTap: _handleSessionExpired,
                      iconColor: VineTheme.accentOrange,
                    ),
                ],

                _SettingsTile(
                  title: context.l10n.settingsCreatorAnalytics,
                  divineIcon: DivineIconName.trendUp,
                  onTap: () => context.push(CreatorAnalyticsScreen.path),
                ),
                _SettingsTile(
                  title: context.l10n.settingsSupportCenter,
                  icon: Icons.support_agent,
                  onTap: () => context.push(SupportCenterScreen.path),
                ),

                _SettingsTile(
                  title: context.l10n.settingsNotifications,
                  divineIcon: DivineIconName.bellSimple,
                  onTap: () => context.push(NotificationSettingsScreen.path),
                ),
                _SettingsTile(
                  title: 'General Settings',
                  divineIcon: DivineIconName.globe,
                  onTap: () => context.push(GeneralSettingsScreen.path),
                ),
                _SettingsTile(
                  title: 'Content & Safety',
                  divineIcon: DivineIconName.faders,
                  onTap: () => context.push(SafetySettingsScreen.path),
                ),
                _SettingsTile(
                  title: context.l10n.settingsNostrSettings,
                  divineIcon: DivineIconName.graph,
                  onTap: () => context.push(NostrSettingsScreen.path),
                ),
                if (nostrAppsSandboxSupported)
                  _SettingsTile(
                    icon: Icons.apps,
                    title: context.l10n.settingsIntegratedApps,
                    subtitle: context.l10n.settingsIntegratedAppsSubtitle,
                    onTap: () {
                      ref.read(forceExploreTabNameProvider.notifier).state =
                          'apps';
                      context.go(ExploreScreen.path);
                    },
                  ),
                _SettingsTile(
                  icon: Icons.science,
                  title: context.l10n.settingsExperimentalFeatures,
                  subtitle: context.l10n.settingsExperimentalFeaturesSubtitle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FeatureFlagScreen(),
                    ),
                  ),
                ),
                _SettingsTile(
                  title: context.l10n.settingsLegal,
                  icon: Icons.gavel,
                  onTap: () => context.push(LegalScreen.path),
                ),
                _SettingsTile(
                  icon: Icons.lock_open,
                  title: context.l10n.settingsIntegrationPermissions,
                  subtitle: context.l10n.settingsIntegrationPermissionsSubtitle,
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
  const _AccountHeader({
    required this.onSwitchAccount,
    required this.accountSwitchingEnabled,
  });

  final VoidCallback onSwitchAccount;
  final bool accountSwitchingEnabled;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsAccountCubit, SettingsAccountState>(
      builder: (context, accountState) {
        final pubkey = accountState.currentPubkey;
        if (pubkey == null) return const SizedBox.shrink();

        final hasMultipleAccounts = accountState.hasMultipleAccounts;
        final buttonLabel = hasMultipleAccounts
            ? context.l10n.settingsSwitchAccount
            : context.l10n.settingsAddAnotherAccount;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            spacing: 16,
            children: [
              _AccountHeaderProfile(pubkey: pubkey),
              BlocBuilder<InviteStatusCubit, InviteStatusState>(
                builder: (context, inviteState) {
                  if (!inviteState.hasAvailableInvites) {
                    return const SizedBox.shrink();
                  }
                  return Semantics(
                    button: true,
                    label: context.l10n.settingsInvites,
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
                              context.l10n.settingsInvites,
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
                                '${inviteState.availableInviteCount}',
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
              if (accountSwitchingEnabled)
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
          placeholderSeed: pubkey,
          size: 96,
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: VineTheme.headlineSmallFont(color: VineTheme.onSurface),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          uniqueIdentifier,
          style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceVariant),
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
      label: context.l10n.settingsAppVersionLabel,
      child: InkWell(
        onTap: () async {
          if (isDeveloperMode) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.settingsDeveloperModeAlreadyEnabled),
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
                SnackBar(
                  content: Text(context.l10n.settingsDeveloperModeEnabled),
                  backgroundColor: VineTheme.vineGreen,
                  duration: const Duration(seconds: 2),
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
                    context.l10n.settingsDeveloperModeTapsRemaining(remaining),
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
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                _appVersion.isEmpty
                    ? context.l10n.settingsVersionEmpty
                    : context.l10n.settingsVersion(_appVersion),
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
                  placeholderSeed: account.pubkeyHex,
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
      label: context.l10n.settingsAddAnotherAccount,
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
                    context.l10n.settingsAddAnotherAccount,
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
