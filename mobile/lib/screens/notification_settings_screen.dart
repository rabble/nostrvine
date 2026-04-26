// ABOUTME: Settings screen for notification preferences and controls
// ABOUTME: Allows users to customize notification types and behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'notification-settings';

  /// Path for this route.
  static const path = '/notification-settings';

  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotificationPreferences _preferences = const NotificationPreferences();
  bool _systemEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await ref
        .read(notificationPreferencesServiceProvider)
        .loadPreferences();
    if (!mounted) return;

    setState(() {
      _preferences = prefs;
    });
  }

  Future<void> _applyPreferences(NotificationPreferences newPrefs) async {
    setState(() {
      _preferences = newPrefs;
    });

    await ref
        .read(notificationPreferencesServiceProvider)
        .updatePreferences(newPrefs);
  }

  Future<void> _resetToDefaults() async {
    await _applyPreferences(const NotificationPreferences());
    if (!mounted) return;

    setState(() {
      _systemEnabled = true;
      _pushNotificationsEnabled = true;
      _soundEnabled = true;
      _vibrationEnabled = true;
    });
  }

  Future<void> _markAllAsRead() async {
    await ref.read(relayNotificationsProvider.notifier).markAllAsRead();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.notificationSettingsAllMarkedAsRead),
        duration: const Duration(seconds: 2),
        backgroundColor: VineTheme.vineGreen,
      ),
    );
  }

  void _showResetSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.notificationSettingsResetToDefaults),
        duration: const Duration(seconds: 2),
        backgroundColor: VineTheme.vineGreen,
      ),
    );
  }

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
          onPressed: () async {
            await _resetToDefaults();
            if (!mounted) return;
            _showResetSnackBar();
          },
        ),
      ],
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
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
              value: _preferences.likesEnabled,
              onChanged: (value) =>
                  _applyPreferences(_preferences.copyWith(likesEnabled: value)),
            ),
            _buildNotificationCard(
              icon: Icons.chat_bubble,
              iconColor: VineTheme.commentBlue,
              title: context.l10n.notificationSettingsComments,
              subtitle: context.l10n.notificationSettingsCommentsSubtitle,
              value: _preferences.commentsEnabled,
              onChanged: (value) => _applyPreferences(
                _preferences.copyWith(commentsEnabled: value),
              ),
            ),
            _buildNotificationCard(
              icon: Icons.person_add,
              iconColor: VineTheme.vineGreen,
              title: context.l10n.notificationSettingsFollows,
              subtitle: context.l10n.notificationSettingsFollowsSubtitle,
              value: _preferences.followsEnabled,
              onChanged: (value) => _applyPreferences(
                _preferences.copyWith(followsEnabled: value),
              ),
            ),
            _buildNotificationCard(
              icon: Icons.alternate_email,
              iconColor: VineTheme.warning,
              title: context.l10n.notificationSettingsMentions,
              subtitle: context.l10n.notificationSettingsMentionsSubtitle,
              value: _preferences.mentionsEnabled,
              onChanged: (value) => _applyPreferences(
                _preferences.copyWith(mentionsEnabled: value),
              ),
            ),
            _buildNotificationCard(
              icon: Icons.repeat,
              iconColor: VineTheme.vineGreenLight,
              title: context.l10n.notificationSettingsReposts,
              subtitle: context.l10n.notificationSettingsRepostsSubtitle,
              value: _preferences.repostsEnabled,
              onChanged: (value) => _applyPreferences(
                _preferences.copyWith(repostsEnabled: value),
              ),
            ),
            _buildNotificationCard(
              icon: Icons.phone_android,
              iconColor: VineTheme.lightText,
              title: context.l10n.notificationSettingsSystem,
              subtitle: context.l10n.notificationSettingsSystemSubtitle,
              value: _systemEnabled,
              onChanged: (value) => setState(() => _systemEnabled = value),
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
              subtitle:
                  context.l10n.notificationSettingsPushNotificationsSubtitle,
              value: _pushNotificationsEnabled,
              onChanged: (value) =>
                  setState(() => _pushNotificationsEnabled = value),
            ),
            _buildNotificationCard(
              icon: Icons.volume_up,
              iconColor: VineTheme.commentBlue,
              title: context.l10n.notificationSettingsSound,
              subtitle: context.l10n.notificationSettingsSoundSubtitle,
              value: _soundEnabled,
              onChanged: (value) => setState(() => _soundEnabled = value),
            ),
            _buildNotificationCard(
              icon: Icons.vibration,
              iconColor: VineTheme.vineGreen,
              title: context.l10n.notificationSettingsVibration,
              subtitle: context.l10n.notificationSettingsVibrationSubtitle,
              value: _vibrationEnabled,
              onChanged: (value) => setState(() => _vibrationEnabled = value),
            ),

            const SizedBox(height: 24),

            // Actions
            _buildSectionHeader(context.l10n.notificationSettingsActions),
            const SizedBox(height: 8),

            _buildActionCard(
              icon: Icons.check_circle,
              iconColor: VineTheme.vineGreenLight,
              title: context.l10n.notificationSettingsMarkAllAsRead,
              subtitle: context.l10n.notificationSettingsMarkAllAsReadSubtitle,
              onTap: _markAllAsRead,
            ),

            const SizedBox(height: 24),

            // Info Section
            _buildInfoCard(),
          ],
        ),
      ),
    ),
  );

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
    required VoidCallback onTap,
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

  Widget _buildInfoCard() => Card(
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
