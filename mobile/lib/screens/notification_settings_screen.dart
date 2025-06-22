// ABOUTME: Settings screen for notification preferences and controls
// ABOUTME: Allows users to customize notification types and behavior

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service_enhanced.dart';
import '../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _likesEnabled = true;
  bool _commentsEnabled = true;
  bool _followsEnabled = true;
  bool _mentionsEnabled = true;
  bool _repostsEnabled = true;
  bool _systemEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notification Settings',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: () {
              setState(() {
                _likesEnabled = true;
                _commentsEnabled = true;
                _followsEnabled = true;
                _mentionsEnabled = true;
                _repostsEnabled = true;
                _systemEnabled = true;
                _pushNotificationsEnabled = true;
                _soundEnabled = true;
                _vibrationEnabled = true;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings reset to defaults'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Notification Types Section
          _buildSectionHeader('Notification Types', isDarkMode),
          const SizedBox(height: 8),
          _buildNotificationCard(
            icon: Icons.favorite,
            iconColor: Colors.red,
            title: 'Likes',
            subtitle: 'When someone likes your videos',
            value: _likesEnabled,
            onChanged: (value) => setState(() => _likesEnabled = value),
            isDarkMode: isDarkMode,
          ),
          _buildNotificationCard(
            icon: Icons.chat_bubble,
            iconColor: Colors.blue,
            title: 'Comments',
            subtitle: 'When someone comments on your videos',
            value: _commentsEnabled,
            onChanged: (value) => setState(() => _commentsEnabled = value),
            isDarkMode: isDarkMode,
          ),
          _buildNotificationCard(
            icon: Icons.person_add,
            iconColor: NostrVineTheme.primaryPurple,
            title: 'Follows',
            subtitle: 'When someone follows you',
            value: _followsEnabled,
            onChanged: (value) => setState(() => _followsEnabled = value),
            isDarkMode: isDarkMode,
          ),
          _buildNotificationCard(
            icon: Icons.alternate_email,
            iconColor: Colors.orange,
            title: 'Mentions',
            subtitle: 'When you are mentioned',
            value: _mentionsEnabled,
            onChanged: (value) => setState(() => _mentionsEnabled = value),
            isDarkMode: isDarkMode,
          ),
          _buildNotificationCard(
            icon: Icons.repeat,
            iconColor: Colors.green,
            title: 'Reposts',
            subtitle: 'When someone reposts your videos',
            value: _repostsEnabled,
            onChanged: (value) => setState(() => _repostsEnabled = value),
            isDarkMode: isDarkMode,
          ),
          _buildNotificationCard(
            icon: Icons.phone_android,
            iconColor: Colors.grey,
            title: 'System',
            subtitle: 'App updates and system messages',
            value: _systemEnabled,
            onChanged: (value) => setState(() => _systemEnabled = value),
            isDarkMode: isDarkMode,
          ),
          
          const SizedBox(height: 24),
          
          // Push Notification Settings
          _buildSectionHeader('Push Notifications', isDarkMode),
          const SizedBox(height: 8),
          _buildNotificationCard(
            icon: Icons.notifications,
            iconColor: NostrVineTheme.primaryPurple,
            title: 'Push Notifications',
            subtitle: 'Receive notifications when app is closed',
            value: _pushNotificationsEnabled,
            onChanged: (value) => setState(() => _pushNotificationsEnabled = value),
            isDarkMode: isDarkMode,
          ),
          _buildNotificationCard(
            icon: Icons.volume_up,
            iconColor: Colors.blue,
            title: 'Sound',
            subtitle: 'Play sound for notifications',
            value: _soundEnabled,
            onChanged: (value) => setState(() => _soundEnabled = value),
            isDarkMode: isDarkMode,
          ),
          _buildNotificationCard(
            icon: Icons.vibration,
            iconColor: Colors.purple,
            title: 'Vibration',
            subtitle: 'Vibrate for notifications',
            value: _vibrationEnabled,
            onChanged: (value) => setState(() => _vibrationEnabled = value),
            isDarkMode: isDarkMode,
          ),
          
          const SizedBox(height: 24),
          
          // Actions
          _buildSectionHeader('Actions', isDarkMode),
          const SizedBox(height: 8),
          
          Consumer<NotificationServiceEnhanced>(
            builder: (context, service, _) {
              return Column(
                children: [
                  _buildActionCard(
                    icon: Icons.check_circle,
                    iconColor: Colors.green,
                    title: 'Mark All as Read',
                    subtitle: 'Mark all notifications as read',
                    onTap: () async {
                      await service.markAllAsRead();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All notifications marked as read'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    isDarkMode: isDarkMode,
                  ),
                  _buildActionCard(
                    icon: Icons.delete_sweep,
                    iconColor: Colors.red,
                    title: 'Clear Old Notifications',
                    subtitle: 'Remove notifications older than 30 days',
                    onTap: () async {
                      await service.clearOlderThan(const Duration(days: 30));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Old notifications cleared'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    isDarkMode: isDarkMode,
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Info Section
          _buildInfoCard(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDarkMode,
  }) {
    return Card(
      color: isDarkMode ? Colors.grey[900] : Colors.white,
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
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: NostrVineTheme.primaryPurple,
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Card(
      color: isDarkMode ? Colors.grey[900] : Colors.white,
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
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoCard(bool isDarkMode) {
    return Card(
      color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: isDarkMode ? Colors.blue[300] : Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'About Notifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Notifications are powered by the Nostr protocol. Real-time updates depend on your connection to Nostr relays. Some notifications may have delays.',
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}