// ABOUTME: Settings screen for notification preferences and controls
// ABOUTME: Allows users to customize notification types and behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_cubit.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_state.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/app_providers.dart';

/// Page: bridges Riverpod-provided dependencies into [NotificationSettingsCubit].
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'notification-settings';

  /// Path for this route.
  static const path = '/notification-settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesService = ref.watch(
      notificationPreferencesServiceProvider,
    );
    final repository = ref.watch(notificationRepositoryProvider);

    return BlocProvider(
      // notificationPreferencesServiceProvider watches authServiceProvider, so
      // its identity can change on auth flip; re-key so the Cubit reloads with
      // the fresh service instead of operating on a stale one.
      key: ValueKey(preferencesService),
      create: (_) =>
          NotificationSettingsCubit(preferencesService: preferencesService)
            ..load(),
      child: NotificationSettingsView(
        onMarkAllAsRead: repository == null
            ? null
            : () => _markAllAsRead(repository),
        showNewPosts: ref.watch(
          isFeatureEnabledProvider(FeatureFlag.newPostNotifications),
        ),
      ),
    );
  }

  Future<bool> _markAllAsRead(NotificationRepository repository) async {
    try {
      await repository.markAllAsRead();
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// View: renders the notification settings UI from the Cubit state.
///
/// [onMarkAllAsRead] performs the bridge-level repository call and resolves to
/// whether it succeeded; `null` disables the mark-all-as-read action. That
/// action stays out of the Cubit because it uses a separate, auth-nullable
/// notification repository (see #4744 scope decision).
class NotificationSettingsView extends StatelessWidget {
  @visibleForTesting
  const NotificationSettingsView({
    required this.onMarkAllAsRead,
    required this.showNewPosts,
    super.key,
  });

  final Future<bool> Function()? onMarkAllAsRead;

  /// Whether to offer the new-post ("bell") toggle. Hidden until the push
  /// service delivers kind 34236, since there is no bell to switch off and
  /// the toggle would change nothing a user could observe.
  final bool showNewPosts;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.vineColors.background,
    appBar: DiVineAppBar(
      title: context.l10n.notificationSettingsTitle,
      showBackButton: true,
      onBackPressed: context.pop,
      actions: [
        DiVineAppBarAction(
          icon: SvgIconSource(DivineIconName.arrowClockwise.assetPath),
          tooltip: context.l10n.notificationSettingsResetTooltip,
          onPressed: () => _onResetPressed(context),
        ),
      ],
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child:
            BlocBuilder<NotificationSettingsCubit, NotificationSettingsState>(
              builder: (context, state) {
                final cubit = context.read<NotificationSettingsCubit>();
                final prefs = state.preferences;
                return ListView(
                  padding: .fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  children: [
                    DivineSectionHeader(
                      context.l10n.notificationSettingsTypes,
                      padding: const EdgeInsets.only(bottom: 8),
                    ),
                    _NotificationCard(
                      icon: DivineIconName.heart,
                      iconColor: VineTheme.likeRed,
                      title: context.l10n.notificationSettingsLikes,
                      subtitle: context.l10n.notificationSettingsLikesSubtitle,
                      value: prefs.likesEnabled,
                      onChanged: (value) => cubit.setPreferences(
                        prefs.copyWith(likesEnabled: value),
                      ),
                    ),
                    _NotificationCard(
                      icon: DivineIconName.chat,
                      iconColor: VineTheme.commentBlue,
                      title: context.l10n.notificationSettingsComments,
                      subtitle:
                          context.l10n.notificationSettingsCommentsSubtitle,
                      value: prefs.commentsEnabled,
                      onChanged: (value) => cubit.setPreferences(
                        prefs.copyWith(commentsEnabled: value),
                      ),
                    ),
                    _NotificationCard(
                      icon: DivineIconName.user,
                      iconColor: VineTheme.vineGreen,
                      title: context.l10n.notificationSettingsFollows,
                      subtitle:
                          context.l10n.notificationSettingsFollowsSubtitle,
                      value: prefs.followsEnabled,
                      onChanged: (value) => cubit.setPreferences(
                        prefs.copyWith(followsEnabled: value),
                      ),
                    ),
                    _NotificationCard(
                      icon: DivineIconName.chat,
                      iconColor: VineTheme.warning,
                      title: context.l10n.notificationSettingsMentions,
                      subtitle:
                          context.l10n.notificationSettingsMentionsSubtitle,
                      value: prefs.mentionsEnabled,
                      onChanged: (value) => cubit.setPreferences(
                        prefs.copyWith(mentionsEnabled: value),
                      ),
                    ),
                    _NotificationCard(
                      icon: DivineIconName.repeat,
                      iconColor: VineTheme.vineGreenDark,
                      title: context.l10n.notificationSettingsReposts,
                      subtitle:
                          context.l10n.notificationSettingsRepostsSubtitle,
                      value: prefs.repostsEnabled,
                      onChanged: (value) => cubit.setPreferences(
                        prefs.copyWith(repostsEnabled: value),
                      ),
                    ),
                    if (showNewPosts)
                      _NotificationCard(
                        icon: DivineIconName.bellSimple,
                        iconColor: VineTheme.vineGreen,
                        title: context.l10n.notificationSettingsNewPosts,
                        subtitle:
                            context.l10n.notificationSettingsNewPostsSubtitle,
                        value: prefs.newPostsEnabled,
                        onChanged: (value) => cubit.setPreferences(
                          prefs.copyWith(newPostsEnabled: value),
                        ),
                      ),
                    DivineSectionHeader(
                      context.l10n.notificationSettingsActions,
                      padding: const EdgeInsets.only(top: 24, bottom: 8),
                    ),
                    _ActionCard(
                      icon: DivineIconName.checkCircle,
                      iconColor: VineTheme.vineGreenDark,
                      title: context.l10n.notificationSettingsMarkAllAsRead,
                      subtitle: context
                          .l10n
                          .notificationSettingsMarkAllAsReadSubtitle,
                      onTap: onMarkAllAsRead == null
                          ? null
                          : () => _onMarkAllAsReadPressed(context),
                    ),
                    const SizedBox(height: 24),
                    const _InfoCard(),
                  ],
                );
              },
            ),
      ),
    ),
  );

  Future<void> _onResetPressed(BuildContext context) async {
    await context.read<NotificationSettingsCubit>().resetToDefaults();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.notificationSettingsResetToDefaults,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onMarkAllAsReadPressed(BuildContext context) async {
    final success = await onMarkAllAsRead!();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        success
            ? context.l10n.notificationSettingsAllMarkedAsRead
            : context.l10n.notificationSettingsMarkAllAsReadFailed,
        error: !success,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final DivineIconName icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    color: context.vineColors.card,
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: .hardEdge,
    child: DivineSwitchTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DivineIcon(icon: icon, color: iconColor),
      ),
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final DivineIconName icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: context.vineColors.card,
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: .hardEdge,
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DivineIcon(icon: icon, color: iconColor),
      ),
      title: Text(
        title,
        style: VineTheme.labelLargeFont(color: context.vineColors.primaryText),
      ),
      subtitle: Text(
        subtitle,
        style: VineTheme.bodySmallFont(color: context.vineColors.secondaryText),
      ),
      trailing: const DivineIcon(
        icon: DivineIconName.caretRight,
        color: VineTheme.primary,
      ),
      onTap: onTap,
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) => DivineInfoCard(
    tone: DivineInfoCardTone.neutral,
    title: context.l10n.notificationSettingsAbout,
    message: context.l10n.notificationSettingsAboutDescription,
  );
}
