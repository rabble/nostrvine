// ABOUTME: Developer options screen for switching between environments
// ABOUTME: Allows switching relay URLs (Production, Staging, Dev relays, Funnelcake Prod)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

class DeveloperOptionsScreen extends ConsumerWidget {
  const DeveloperOptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentConfig = ref.watch(currentEnvironmentProvider);

    // All available environment configurations
    final environments = [
      const EnvironmentConfig(environment: AppEnvironment.production),
      const EnvironmentConfig(environment: AppEnvironment.staging),
      const EnvironmentConfig(
        environment: AppEnvironment.dev,
        devRelay: DevRelay.umbra,
      ),
      const EnvironmentConfig(
        environment: AppEnvironment.dev,
        devRelay: DevRelay.shugur,
      ),
      const EnvironmentConfig(
        environment: AppEnvironment.dev,
        devRelay: DevRelay.funnelcakeProd,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Developer Options'),
        backgroundColor: VineTheme.vineGreen,
      ),
      body: ListView.builder(
        itemCount: environments.length,
        itemBuilder: (context, index) {
          final env = environments[index];
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
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              env.relayUrl,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            trailing: isSelected
                ? const Icon(Icons.check, color: VineTheme.vineGreen)
                : null,
            onTap: () => _switchEnvironment(context, ref, env, isSelected),
          );
        },
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
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Switch to ${newConfig.displayName}?\n\n'
          'This will clear cached video data and reconnect to the new relay.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => context.pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
            ),
            child: const Text('Switch', style: TextStyle(color: Colors.white)),
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
