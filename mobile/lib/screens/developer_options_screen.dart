// ABOUTME: Developer options screen for switching between environments
// ABOUTME: Allows switching relay URLs (POC, Staging, Test, Production)
// ABOUTME: Shows page load performance timing data for debugging

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/services/page_load_history.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Returns a color indicating speed: green (<1s), orange (1-3s), red (>3s).
Color _getSpeedColor(PageLoadRecord record) {
  final ms = record.dataLoadedMs ?? record.contentVisibleMs ?? 0;
  if (ms > 3000) return VineTheme.likeRed;
  if (ms > 1000) return VineTheme.accentOrange;
  return VineTheme.vineGreen;
}

class DeveloperOptionsScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'developer-options';

  /// Path for this route.
  static const path = '/developer-options';

  const DeveloperOptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentConfig = ref.watch(currentEnvironmentProvider);

    // All available environment configurations
    final environments = [
      const EnvironmentConfig(environment: AppEnvironment.production),
      const EnvironmentConfig(environment: AppEnvironment.staging),
      const EnvironmentConfig(environment: AppEnvironment.test),
      const EnvironmentConfig(environment: AppEnvironment.poc),
    ];

    final recentRecords = PageLoadHistory().getRecent(10);
    final slowestRecords = PageLoadHistory().getSlowest(5);

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leadingWidth: 80,
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: VineTheme.navGreen,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VineTheme.iconButtonBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SvgPicture.asset(
              'assets/icon/CaretLeft.svg',
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(
                VineTheme.whiteText,
                BlendMode.srcIn,
              ),
            ),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Developer Options',
          style: VineTheme.titleFont(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        children: [
          // Environment configs
          ...environments.map((env) {
            final isSelected = env == currentConfig;
            return ListTile(
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(env.indicatorColorValue),
                ),
              ),
              title: Text(
                env.displayName,
                style: const TextStyle(
                  color: VineTheme.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                env.relayUrl,
                style: const TextStyle(
                  color: VineTheme.secondaryText,
                  fontSize: 14,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check, color: VineTheme.vineGreen)
                  : null,
              onTap: () => _switchEnvironment(context, ref, env, isSelected),
            );
          }),

          // Divider between environments and page load times
          const Divider(color: VineTheme.outlineVariant, height: 32),

          // Page Load Times section header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Page Load Times',
              style: TextStyle(
                color: VineTheme.vineGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Recent page load records
          if (recentRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No page loads recorded yet.\n'
                'Navigate around the app to see timing data.',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
              ),
            )
          else
            ...recentRecords.map((record) {
              return ListTile(
                title: Text(
                  record.screenName,
                  style: const TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Visible: ${record.contentVisibleMs ?? "\u2014"}ms'
                  '  |  '
                  'Data: ${record.dataLoadedMs ?? "\u2014"}ms',
                  style: const TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
                trailing: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getSpeedColor(record),
                  ),
                ),
              );
            }),

          // Slowest Screens subsection
          if (slowestRecords.isNotEmpty) ...[
            const Divider(color: VineTheme.outlineVariant, height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Slowest Screens',
                style: TextStyle(
                  color: VineTheme.vineGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...slowestRecords.map((record) {
              final dataMs = record.dataLoadedMs ?? 0;
              return ListTile(
                title: Text(
                  record.screenName,
                  style: const TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  '${dataMs}ms',
                  style: TextStyle(color: _getSpeedColor(record), fontSize: 12),
                ),
                trailing: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getSpeedColor(record),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _switchEnvironment(
    BuildContext context,
    WidgetRef ref,
    EnvironmentConfig newConfig,
    bool isSelected,
  ) async {
    // Don't switch if already selected
    if (isSelected) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Switch Environment?',
          style: TextStyle(color: VineTheme.primaryText),
        ),
        content: Text(
          'Switch to ${newConfig.displayName}?\n\n'
          'This will clear cached video data and reconnect to the new relay.',
          style: const TextStyle(color: VineTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: VineTheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => context.pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
            ),
            child: const Text(
              'Switch',
              style: TextStyle(color: VineTheme.primaryText),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    Log.info(
      'Switching environment to ${newConfig.displayName}',
      name: 'DeveloperOptions',
      category: LogCategory.system,
    );

    // Clear in-memory video events
    final videoEventService = ref.read(videoEventServiceProvider);
    videoEventService.clearVideoEvents();

    // Switch environment (clears video cache from DB and updates config)
    await switchEnvironment(ref, newConfig);

    Log.info(
      'Environment switched to ${newConfig.displayName}',
      name: 'DeveloperOptions',
      category: LogCategory.system,
    );

    // Show confirmation and go back
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${newConfig.displayName}'),
          backgroundColor: Color(newConfig.indicatorColorValue),
        ),
      );
      context.pop();
    }
  }
}
