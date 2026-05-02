// ABOUTME: Settings screen for managing feature flag states and overrides
// ABOUTME: Provides UI for toggling flags, viewing descriptions, and resetting to defaults

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/cache_recovery_service.dart';

class FeatureFlagScreen extends ConsumerWidget {
  const FeatureFlagScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(featureFlagServiceProvider);
    final state = ref.watch(featureFlagStateProvider);

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.featureFlagTitle,
        showBackButton: true,
        onBackPressed: context.pop,
        actions: [
          DiVineAppBarAction(
            icon: const MaterialIconSource(Icons.restore),
            onPressed: () async {
              await service.resetAllFlags();
            },
            tooltip: context.l10n.featureFlagResetAllTooltip,
            semanticLabel: context.l10n.featureFlagResetAllTooltip,
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                // Cache Recovery Section
                _buildCacheRecoverySection(context),
                const Divider(),
                // Feature Flags List
                Expanded(
                  child: ListView.builder(
                    itemCount: FeatureFlag.values.length,
                    itemBuilder: (context, index) {
                      final flag = FeatureFlag.values[index];
                      final isEnabled = state[flag] ?? false;
                      final hasUserOverride = service.hasUserOverride(flag);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: ListTile(
                          title: Text(
                            flag.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: hasUserOverride
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            flag.description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasUserOverride)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 8,
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              Switch(
                                value: isEnabled,
                                onChanged: (value) async {
                                  await service.setFlag(flag, value);
                                },
                                activeThumbColor: hasUserOverride
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              if (hasUserOverride)
                                IconButton(
                                  icon: const Icon(Icons.undo, size: 20),
                                  tooltip:
                                      context.l10n.featureFlagResetToDefault,
                                  onPressed: () async {
                                    await service.resetFlag(flag);
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCacheRecoverySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.featureFlagAppRecovery,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.featureFlagAppRecoveryDescription,
            style: const TextStyle(color: VineTheme.lightText),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _clearCache(context),
                icon: const Icon(Icons.cleaning_services),
                label: Text(context.l10n.featureFlagClearAllCache),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.accentOrange,
                  foregroundColor: VineTheme.whiteText,
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => _showCacheInfo(context),
                icon: const Icon(Icons.info_outline),
                label: Text(context.l10n.featureFlagCacheInfo),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    // Show confirmation dialog
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.featureFlagClearCacheTitle),
            content: Text(context.l10n.featureFlagClearCacheMessage),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: Text(context.l10n.devOptionsCancel),
              ),
              ElevatedButton(
                onPressed: () => context.pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.accentOrange,
                ),
                child: Text(context.l10n.featureFlagClearCache),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    // Show loading dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(context.l10n.featureFlagClearingCache),
          ],
        ),
      ),
    );

    // Perform cache clearing
    final success = await CacheRecoveryService.clearAllCaches();

    // Close loading dialog
    if (!context.mounted) return;
    context.pop();

    // Show result
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          success
              ? context.l10n.featureFlagSuccess
              : context.l10n.featureFlagError,
        ),
        content: Text(
          success
              ? context.l10n.featureFlagClearCacheSuccess
              : context.l10n.featureFlagClearCacheFailure,
        ),
        actions: [
          TextButton(
            onPressed: context.pop,
            child: Text(context.l10n.featureFlagOk),
          ),
        ],
      ),
    );
  }

  Future<void> _showCacheInfo(BuildContext context) async {
    final cacheSize = await CacheRecoveryService.getCacheSizeInfo();

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.featureFlagCacheInformation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.featureFlagTotalCacheSize(cacheSize)),
            const SizedBox(height: 12),
            Text(
              context.l10n.featureFlagCacheIncludes,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: context.pop,
            child: Text(context.l10n.featureFlagOk),
          ),
        ],
      ),
    );
  }
}
