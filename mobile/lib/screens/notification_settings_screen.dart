// ABOUTME: Settings screen for notification preferences and controls
// ABOUTME: Allows users to customize notification types and behavior

import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/models/notification_preferences.dart';
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
    final box = await Hive.openBox<dynamic>('notifications');
    final stored = box.get('push_preferences') as String?;
    if (stored != null) {
      try {
        final json = jsonDecode(stored) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _preferences = NotificationPreferences.fromJson(json);
          });
        }
      } on FormatException {
        // Corrupted cache, use defaults
      }
    }
  }

  Future<void> _updatePreference(NotificationPreferences newPrefs) async {
    setState(() {
      _preferences = newPrefs;
    });

    // Persist to Hive cache
    final box = await Hive.openBox<dynamic>('notifications');
    await box.put('push_preferences', jsonEncode(newPrefs.toJson()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: VineTheme.backgroundColor,
    appBar: DiVineAppBar(
      title: 'Notifications',
      showBackButton: true,
      onBackPressed: context.pop,
      actions: [
        DiVineAppBarAction(
          icon: const MaterialIconSource(Icons.refresh),
          tooltip: 'Reset to defaults',
          onPressed: () {
            _updatePreference(const NotificationPreferences());
            setState(() {
              _systemEnabled = true;
              _pushNotificationsEnabled = true;
              _soundEnabled = true;
              _vibrationEnabled = true;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Settings reset to defaults'),
                duration: Duration(seconds: 2),
                backgroundColor: VineTheme.vineGreen,
              ),
            );
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
            _buildSectionHeader('Notification Types'),
            const SizedBox(height: 8),
            _buildNotificationCard(
              icon: Icons.favorite,
              iconColor: VineTheme.likeRed,
              title: 'Likes',
              subtitle: 'When someone likes your videos',
              value: _preferences.likesEnabled,
              onChanged: (value) =>
                  _updatePreference(_preferences.copyWith(likesEnabled: value)),
            ),
            _buildNotificationCard(
              icon: Icons.chat_bubble,
              iconColor: VineTheme.commentBlue,
              title: 'Comments',
              subtitle: 'When someone comments on your videos',
              value: _preferences.commentsEnabled,
              onChanged: (value) => _updatePreference(
                _preferences.copyWith(commentsEnabled: value),
              ),
            ),
            _buildNotificationCard(
              icon: Icons.person_add,
              iconColor: VineTheme.vineGreen,
              title: 'Follows',
              subtitle: 'When someone follows you',
              value: _preferences.followsEnabled,
              onChanged: (value) => _updatePreference(
                _preferences.copyWith(followsEnabled: value),
              ),
            ),
            _buildNotificationCard(
              icon: Icons.alternate_email,
              iconColor: VineTheme.warning,
              title: 'Mentions',
              subtitle: 'When you are mentioned',
              value: _preferences.mentionsEnabled,
              onChanged: (value) => _updatePreference(
                _preferences.copyWith(mentionsEnabled: value),
              ),
            ),
            _buildNotificationCard(
              icon: Icons.repeat,
              iconColor: VineTheme.vineGreenLight,
              title: 'Reposts',
              subtitle: 'When someone reposts your videos',
              value: _preferences.repostsEnabled,
              onChanged: (value) => _updatePreference(
                _preferences.copyWith(repostsEnabled: value),
              ),
            ),
            _buildNotificationCard(
              icon: Icons.phone_android,
              iconColor: VineTheme.lightText,
              title: 'System',
              subtitle: 'App updates and system messages',
              value: _systemEnabled,
              onChanged: (value) => setState(() => _systemEnabled = value),
            ),

            const SizedBox(height: 24),

            // Push Notification Settings
            _buildSectionHeader('Push Notifications'),
            const SizedBox(height: 8),
            _buildNotificationCard(
              icon: Icons.notifications,
              iconColor: VineTheme.vineGreen,
              title: 'Push Notifications',
              subtitle: 'Receive notifications when app is closed',
              value: _pushNotificationsEnabled,
              onChanged: (value) =>
                  setState(() => _pushNotificationsEnabled = value),
            ),
            _buildNotificationCard(
              icon: Icons.volume_up,
              iconColor: VineTheme.commentBlue,
              title: 'Sound',
              subtitle: 'Play sound for notifications',
              value: _soundEnabled,
              onChanged: (value) => setState(() => _soundEnabled = value),
            ),
            _buildNotificationCard(
              icon: Icons.vibration,
              iconColor: VineTheme.vineGreen,
              title: 'Vibration',
              subtitle: 'Vibrate for notifications',
              value: _vibrationEnabled,
              onChanged: (value) => setState(() => _vibrationEnabled = value),
            ),

            const SizedBox(height: 24),

            // Actions
            _buildSectionHeader('Actions'),
            const SizedBox(height: 8),

            _buildActionCard(
              icon: Icons.check_circle,
              iconColor: VineTheme.vineGreenLight,
              title: 'Mark All as Read',
              subtitle: 'Mark all notifications as read',
              onTap: () async {
                await ref
                    .read(relayNotificationsProvider.notifier)
                    .markAllAsRead();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read'),
                      duration: Duration(seconds: 2),
                      backgroundColor: VineTheme.vineGreen,
                    ),
                  );
                }
              },
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

  Widget _buildInfoCard() => const Card(
    color: VineTheme.cardBackground,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: VineTheme.commentBlue, size: 20),
              SizedBox(width: 8),
              Text(
                'About Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: VineTheme.primaryText,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Notifications are powered by the Nostr protocol. Real-time updates depend on your connection to Nostr relays. Some notifications may have delays.',
            style: TextStyle(
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
