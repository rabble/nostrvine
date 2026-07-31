// ABOUTME: New settings hub screen matching Figma design
// ABOUTME: Central entry point for all app settings, accessed via gear icon on profile

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/blocs/settings_account/settings_account_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/features/monetization/monetization_storefront_policy.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/developer_mode_tap_provider.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/swap_account.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/apps/apps_permissions_screen.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/screens/settings/invites_screen.dart';
import 'package:openvine/screens/settings/legal_screen.dart';
import 'package:openvine/screens/settings/monetization_links_settings_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/screens/settings/supporter_screen.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/utils/deferred_login_options_navigator.dart';
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
  final _deferredLoginOptionsNavigator = DeferredLoginOptionsNavigator();

  @override
  void initState() {
    super.initState();
    unawaited(_loadAppVersion());
    unawaited(context.read<InviteStatusCubit?>()?.load());
    _accountCubit = SettingsAccountCubit(
      authService: ref.read(authServiceProvider),
      draftStorageService: ref.read(draftStorageServiceProvider),
      featureFlagService: ref.read(featureFlagServiceProvider),
    )..load();
  }

  @override
  void dispose() {
    _deferredLoginOptionsNavigator.dispose();
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
    final refreshed = await authService.tryRefreshExpiredSession();
    if (!mounted) return;
    if (refreshed) return;

    _deferredLoginOptionsNavigator.goAfterUploadsComplete(
      context: context,
      publishBloc: context.read(),
    );
  }

  /// Confirmation sheet shown before an account switch that would disturb
  /// unfinished work. Returns true when the user chose to switch anyway.
  Future<bool> _confirmSwitchAnyway({
    required String title,
    required String message,
  }) async {
    final proceed = await VineBottomSheet.show<bool>(
      context: context,
      scrollable: false,
      contentTitle: title,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            message,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
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
    return proceed ?? false;
  }

  Future<bool> _parkUploadsBeforeAccountChange(
    BackgroundPublishBloc publishBloc,
  ) async {
    try {
      await publishBloc.parkInFlight();
      return true;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to park uploads before account change',
        name: 'SettingsScreen',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsAccountSwitchFailed)),
      );
      return false;
    }
  }

  Future<void> _handleSwitchAccount() async {
    final accountState = _accountCubit.state;
    final publishBloc = context.read<BackgroundPublishBloc>();

    // An in-flight upload cannot survive the switch — the leaving account's
    // container owns the UploadManager and is torn down. Say so here; the
    // videos are parked back as drafts of the account they were recorded on
    // only once a target account is actually picked, since confirming this
    // sheet still leaves the user free to back out of the picker below.
    final inFlightCount = publishBloc.state.uploads
        .where((upload) => upload.result == null)
        .length;
    if (inFlightCount > 0) {
      final proceed = await _confirmSwitchAnyway(
        title: context.l10n.settingsUploadInProgressTitle,
        message: context.l10n.settingsUploadInProgressMessage(inFlightCount),
      );
      if (!proceed) return;
    } else if (accountState.hasDrafts) {
      final proceed = await _confirmSwitchAnyway(
        title: context.l10n.settingsUnsavedDraftsTitle,
        message: context.l10n.settingsUnsavedDraftsMessage(
          accountState.draftCount,
        ),
      );
      if (!proceed) return;
    }

    if (!mounted) return;

    await VineBottomSheet.show<void>(
      context: context,
      children: [
        ...accountState.accounts.map(
          (account) => _AccountSwitchTile(
            account: account,
            isCurrentAccount: account.pubkeyHex == accountState.currentPubkey,
            onTap: () async {
              Navigator.of(context).pop();
              if (account.pubkeyHex == accountState.currentPubkey) return;

              // Park now that a switch is actually committed, and await it:
              // `swapAccount` disposes the container this bloc lives in, so a
              // fire-and-forget event would race the teardown and lose the
              // video. Parking reads the queue now rather than reusing the ids
              // the warning was built from, so an upload that finished while
              // the picker was open is left alone.
              if (!await _parkUploadsBeforeAccountChange(publishBloc)) return;
              if (!mounted) return;

              final deviceScope = ref.read(deviceScopeProvider);
              try {
                // In-place swap: no sign-out, no welcome-screen bounce. On
                // failure the current account is left untouched.
                await swapAccount(
                  deviceScope: deviceScope,
                  controller: deviceScope.switchController,
                  account: account,
                );
              } catch (e, stackTrace) {
                Log.error(
                  'Account switch failed',
                  name: 'SettingsScreen',
                  error: e,
                  stackTrace: stackTrace,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.settingsAccountSwitchFailed),
                  ),
                );
              }
            },
          ),
        ),
        _AddAccountTile(
          onTap: () async {
            Navigator.of(context).pop();

            // Adding an account ends this session too — `addNewAccount` signs
            // out to reach the sign-in flow. It keeps the local rows, but an
            // in-flight upload's copy would be stranded at
            // `PublishStatus.publishing`, which the drafts library filters out,
            // so the video would be missing from both the queue and the library
            // until a later launch swept it up. Park it for the same reason the
            // switch above does, under the same warning this sheet opened with.
            if (!await _parkUploadsBeforeAccountChange(publishBloc)) return;
            if (!mounted) return;
            await _accountCubit.addNewAccount();
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
    final monetizationLinksEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.profileMonetizationLinks),
    );
    final divineSupportersEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.divineSupporters),
    );
    // Watched here (not just in _VersionTile) so the Developer Options tile
    // appears immediately when dev mode is unlocked via the version tap.
    final isDeveloperMode = ref.watch(isDeveloperModeEnabledProvider);
    final appStoreTipPolicy = usesAppleAppStoreTipPolicy;
    return BlocProvider.value(
      value: _accountCubit,
      child: Scaffold(
        appBar: DiVineAppBar(
          title: context.l10n.settingsTitle,
          showBackButton: true,
          onBackPressed: context.pop,
        ),
        backgroundColor: context.vineColors.surface,
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
                      divineIcon: DivineIconName.arrowClockwise,
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
                if (isAuthenticated && monetizationLinksEnabled)
                  _SettingsTile(
                    title: appStoreTipPolicy
                        ? context.l10n.monetizationTipsSettingsTitle
                        : context.l10n.monetizationSettingsTitle,
                    divineIcon: DivineIconName.heart,
                    subtitle: appStoreTipPolicy
                        ? context.l10n.monetizationTipsSettingsSubtitle
                        : context.l10n.monetizationSettingsSubtitle,
                    onTap: () =>
                        context.push(MonetizationLinksSettingsScreen.path),
                  ),
                if (divineSupportersEnabled)
                  _SettingsTile(
                    title: context.l10n.supporterTitle,
                    divineIcon: DivineIconName.heart,
                    subtitle: context.l10n.supporterTileSubtitle,
                    onTap: () => context.push(SupporterScreen.path),
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
                  title: context.l10n.settingsGeneralTitle,
                  divineIcon: DivineIconName.globe,
                  onTap: () => context.push(GeneralSettingsScreen.path),
                ),
                _SettingsTile(
                  title: context.l10n.settingsContentSafetyTitle,
                  divineIcon: DivineIconName.faders,
                  onTap: () => context.push(SafetySettingsScreen.path),
                ),
                _SettingsTile(
                  title: context.l10n.settingsNostrSettings,
                  divineIcon: DivineIconName.graph,
                  onTap: () => context.push(NostrSettingsScreen.path),
                ),
                _SettingsTile(
                  title: context.l10n.settingsBadgesTitle,
                  divineIcon: DivineIconName.sealCheck,
                  subtitle: context.l10n.settingsBadgesSubtitle,
                  onTap: () => context.push(BadgesScreen.path),
                ),
                if (nostrAppsSandboxSupported)
                  _SettingsTile(
                    icon: Icons.apps,
                    title: context.l10n.settingsIntegratedApps,
                    subtitle: context.l10n.settingsIntegratedAppsSubtitle,
                    onTap: () => context.push(AppsDirectoryScreen.path),
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
                if (isDeveloperMode) ...[
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
                    divineIcon: DivineIconName.bracketsAngle,
                    title: context.l10n.settingsDeveloperOptions,
                    subtitle: context.l10n.settingsDeveloperOptionsSubtitle,
                    iconColor: VineTheme.warning,
                    onTap: () => context.push(DeveloperOptionsScreen.path),
                  ),
                ],

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
                  if (!inviteState.hasInviteActivity) {
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
                          color: context.vineColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.vineColors.outlineMuted,
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
                            if (inviteState.hasAvailableInvites)
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
                                    color: VineTheme.onPrimary,
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
                        color: context.vineColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.vineColors.outlineMuted,
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
          style: VineTheme.headlineSmallFont(
            color: context.vineColors.onSurface,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          uniqueIdentifier,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceVariant,
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
    // Watch the tap counter to keep the auto-dispose provider alive
    // between taps while this widget is mounted.
    ref.watch(developerModeTapCounterProvider);

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

          final tapCount = ref
              .read(developerModeTapCounterProvider.notifier)
              .tap();

          Log.debug(
            'Dev mode count: $tapCount',
            name: 'SettingsScreen',
            category: LogCategory.ui,
          );

          if (tapCount >= 7) {
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
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.mutedText,
                ),
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
            color: iconColor ?? context.vineColors.onSurfaceVariant,
          )
        : Icon(icon, color: iconColor ?? context.vineColors.onSurfaceVariant);

    return ListTile(
      minTileHeight: 64,
      leading: leadingWidget,
      title: Text(
        title,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
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
                          color: context.vineColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        identifier,
                        style: VineTheme.bodyMediumFont(
                          color: context.vineColors.onSurfaceVariant,
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
                DivineIcon(
                  icon: DivineIconName.userPlus,
                  color: context.vineColors.onSurfaceVariant,
                ),
                Expanded(
                  child: Text(
                    context.l10n.settingsAddAnotherAccount,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.onSurface,
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
