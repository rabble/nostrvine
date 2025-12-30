// ABOUTME: Riverpod provider for environment service
// ABOUTME: Exposes environment config and developer mode state to widgets

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/services/environment_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'environment_provider.g.dart';

/// Provider for the environment service singleton
@Riverpod(keepAlive: true)
EnvironmentService environmentService(Ref ref) {
  final service = EnvironmentService();
  // Note: initialize() must be called during app startup
  return service;
}

/// Provider for current environment config (reactive)
@riverpod
EnvironmentConfig currentEnvironment(Ref ref) {
  final service = ref.watch(environmentServiceProvider);

  // Proper listener management with cleanup
  void listener() => ref.invalidateSelf();
  service.addListener(listener);
  ref.onDispose(() => service.removeListener(listener));

  return service.currentConfig;
}

/// Provider for developer mode enabled state
@riverpod
bool isDeveloperModeEnabled(Ref ref) {
  final service = ref.watch(environmentServiceProvider);

  // Proper listener management with cleanup
  void listener() => ref.invalidateSelf();
  service.addListener(listener);
  ref.onDispose(() => service.removeListener(listener));

  return service.isDeveloperModeEnabled;
}

/// Provider to check if showing environment indicator
@riverpod
bool showEnvironmentIndicator(Ref ref) {
  final config = ref.watch(currentEnvironmentProvider);
  return !config.isProduction;
}

/// Switch environment and clear cached video data
///
/// Cancels all active subscriptions, clears kind 34236 video events and their
/// metrics from the local database to ensure a fresh start when switching
/// between prod/staging/dev. Also handles setting the dev relay.
Future<void> switchEnvironment(
  WidgetRef ref,
  EnvironmentConfig newConfig,
) async {
  final service = ref.read(environmentServiceProvider);
  final db = ref.read(databaseProvider);
  final subscriptionManager = ref.read(subscriptionManagerProvider);

  // Cancel all active relay subscriptions before switching
  await subscriptionManager.cancelAllSubscriptions();

  // Clear cached video events (kind 34236) and metrics from database
  await db.nostrEventsDao.deleteEventsByKind(34236);
  await db.videoMetricsDao.deleteAllVideoMetrics();

  // Switch the environment (this also clears persisted relay list)
  await service.setEnvironment(newConfig.environment);
  if (newConfig.devRelay != null) {
    await service.setDevRelay(newConfig.devRelay!);
  }
}
