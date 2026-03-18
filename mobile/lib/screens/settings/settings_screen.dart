// ABOUTME: New settings hub screen matching Figma design
// ABOUTME: Central entry point for all app settings, accessed via gear icon on profile

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/developer_mode_tap_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/notification_settings_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/utils/unified_logger.dart';
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

  @override
  Widget build(BuildContext context) {
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

              // Preferences
              const _SectionHeader(title: 'Preferences'),
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

              const SizedBox(height: 24),
              _VersionTile(appVersion: _appVersion),
            ],
          ),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: VineTheme.vineGreen),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: VineTheme.vineGreen,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
