// ABOUTME: Device-scoped provider for the app's StartupPerformanceService
// ABOUTME: Replaces the former lazy-static singleton (#4743)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/startup_performance_service.dart';

/// The app's single [StartupPerformanceService].
///
/// Replaces the former `StartupPerformanceService.instance` singleton (#4743).
/// It is **device-scoped**, not account-scoped: startup phase timings describe
/// the process, so an account swap must not reset them the way a per-container
/// provider would. `DeviceScope` pins it with `overrideWithValue`, exactly as
/// it does for `appVersion` and `installSource`.
///
/// The service is created in `app_bootstrap` before any `ProviderContainer`
/// exists — it times the bootstrap itself, starting ~420 lines before the
/// container is built — so this provider is override-only and throws if read
/// from a container that was not built through `DeviceScope`.
final startupPerformanceServiceProvider = Provider<StartupPerformanceService>(
  (ref) => throw StateError(
    'startupPerformanceServiceProvider must be overridden at container '
    'creation (see DeviceScope.overrides)',
  ),
);
