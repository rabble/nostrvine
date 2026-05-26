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
  const NotificationSettingsView({required this.onMarkAllAsRead, super.key});

  final Future<bool> Function()? onMarkAllAsRead;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VineTheme.backgroundColor,
    appBar: DiVineAppBar(
      title: context.l10n.notificationSettingsTitle,
      showBackButton: true,
      onBackPressed: context.pop,
      actions: [
        DiVineAppBarAction(
          icon: const MaterialIconSource(Icons.refresh),
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
                    // Notification Types Section
                    _buildSectionHeader(context.l10n.notificationSettingsTypes),
                    const SizedBox(height: 8),
                    _buildNotificationCard(
                      icon: Icons.favorite,
                      iconColor: VineTheme.likeRed,
                      title: context.l10n.notificationSettingsLikes,
                      subtitle: context.l10n.notificationSettingsLikesSubtitle,
                      value: prefs.likesEnabled,
                      onChanged: (value) => cubit.setPreferences(
                        prefs.copyWith(likesEnabled: value),
                      ),
                    ),
                    _buildNotificationCard(
                      icon: Icons.chat_bubble,
                      iconColor: VineTheme.commentBlue,
                      title: context.l10n.notificationSettingsComments,
                      subtitle:
                          context.l10n.notificationSettingsCommentsSubtitle,
                      value: prefs.commentsEnabled,
                      onChanged: (value) => cubit.setPreferences(
                        prefs.copyWith(commentsEnabled: value),
                      ),
                    ),
                    _buildNotificationCard(
                      icon: Icons.person_add,
                      iconColor: VineTheme.vineGreen,
                      title: context.l10n.notificationSettingsFollows,
                      subtitle:
                          context.l10n.notificationSettingsFollowsSubtitle,
                      value: prefs.followsEnabled,
                      onChanged: (value) => cubit.setPreferences(
                        prefs.copyWith(followsEnabled: value),
                      ),
                    ),
                    _buildNotificationCard(
                      icon: Icons.alternate_email,
                      iconColor: VineTheme.warning,
                      title: context.l10n.notificationSettingsMentions,
                      subtitle:
                          context.l10n.notificationSettingsMentionsSubtitle,
                      value: prefs.mentionsEnabled,
                      onChanged: (value) => cubit.setPreferences(
                        prefs.copyWith(mentionsEnabled: value),
                      ),
                    ),
                    _buildNotificationCard(
                      icon: Icons.repeat,
                      iconColor: VineTheme.vineGreenLight,
                      title: context.l10n.notificationSettingsReposts,
                      subtitle:
                          context.l10n.notificationSettingsRepostsSubtitle,
                      value: prefs.repostsEnabled,
                      onChanged: (value) => cubit.setPreferences(
                        prefs.copyWith(repostsEnabled: value),
                      ),
                    ),
                    _buildNotificationCard(
                      icon: Icons.phone_android,
                      iconColor: VineTheme.lightText,
                      title: context.l10n.notificationSettingsSystem,
                      subtitle: context.l10n.notificationSettingsSystemSubtitle,
                      value: state.systemEnabled,
                      onChanged: cubit.setSystemEnabled,
                    ),

                    const SizedBox(height: 24),

                    // Push Notification Settings
                    _buildSectionHeader(
                      context.l10n.notificationSettingsPushNotificationsSection,
                    ),
                    const SizedBox(height: 8),
                    _buildNotificationCard(
                      icon: Icons.notifications,
                      iconColor: VineTheme.vineGreen,
                      title: context.l10n.notificationSettingsPushNotifications,
                      subtitle: context
                          .l10n
                          .notificationSettingsPushNotificationsSubtitle,
                      value: state.pushNotificationsEnabled,
                      onChanged: cubit.setPushNotificationsEnabled,
                    ),
                    _buildNotificationCard(
                      icon: Icons.volume_up,
                      iconColor: VineTheme.commentBlue,
                      title: context.l10n.notificationSettingsSound,
                      subtitle: context.l10n.notificationSettingsSoundSubtitle,
                      value: state.soundEnabled,
                      onChanged: cubit.setSoundEnabled,
                    ),
                    _buildNotificationCard(
                      icon: Icons.vibration,
                      iconColor: VineTheme.vineGreen,
                      title: context.l10n.notificationSettingsVibration,
                      subtitle:
                          context.l10n.notificationSettingsVibrationSubtitle,
                      value: state.vibrationEnabled,
                      onChanged: cubit.setVibrationEnabled,
                    ),

                    const SizedBox(height: 24),

                    // Actions
                    _buildSectionHeader(
                      context.l10n.notificationSettingsActions,
                    ),
                    const SizedBox(height: 8),

                    _buildActionCard(
                      icon: Icons.check_circle,
                      iconColor: VineTheme.vineGreenLight,
                      title: context.l10n.notificationSettingsMarkAllAsRead,
                      subtitle: context
                          .l10n
                          .notificationSettingsMarkAllAsReadSubtitle,
                      onTap: onMarkAllAsRead == null
                          ? null
                          : () => _onMarkAllAsReadPressed(context),
                    ),

                    const SizedBox(height: 24),

                    // Info Section
                    _buildInfoCard(context),
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
      SnackBar(
        content: Text(context.l10n.notificationSettingsResetToDefaults),
        duration: const Duration(seconds: 2),
        backgroundColor: VineTheme.vineGreen,
      ),
    );
  }

  Future<void> _onMarkAllAsReadPressed(BuildContext context) async {
    final success = await onMarkAllAsRead!();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.l10n.notificationSettingsAllMarkedAsRead
              : context.l10n.notificationSettingsMarkAllAsReadFailed,
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: success ? VineTheme.vineGreen : VineTheme.error,
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: VineTheme.primaryText,
    ),
  );

  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Card(
    color: VineTheme.cardBackground,
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: VineTheme.primaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: VineTheme.secondaryText, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: VineTheme.vineGreen,
      ),
    ),
  );

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) => Card(
    color: VineTheme.cardBackground,
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: VineTheme.primaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: VineTheme.secondaryText, fontSize: 12),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: VineTheme.lightText,
        size: 16,
      ),
      onTap: onTap,
    ),
  );

  Widget _buildInfoCard(BuildContext context) => Card(
    color: VineTheme.cardBackground,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: VineTheme.commentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.notificationSettingsAbout,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: VineTheme.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.notificationSettingsAboutDescription,
            style: const TextStyle(
              fontSize: 13,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );
}
