// ABOUTME: Device-scoped provider for the app's CrashReportingService
// ABOUTME: Replaces the former lazy-static singleton (#4743)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/crash_reporting_service.dart';

/// The app's single [CrashReportingService].
///
/// Replaces the former `CrashReportingService.instance` singleton (#4743).
/// Device-scoped, not account-scoped: Crashlytics keeps one process-wide
/// handler chain (`FlutterError.onError`, `PlatformDispatcher.onError`), so a
/// per-container instance would re-install those on every account swap.
///
/// Created in `app_bootstrap` before any `ProviderContainer` exists — it is
/// initialized early so startup failures are reportable — and pinned by
/// `DeviceScope`, so this provider is override-only.
/// The fallback instance is deliberately a real but **uninitialized**
/// service: nothing calls `initialize()` on it, so it never reaches Firebase —
/// it writes non-fatal errors to the unified log and holds a bounded number of
/// calls that are never replayed (#8616). It exists so a test container need
/// not know about this provider; production always receives the initialized
/// instance through `DeviceScope`, which every container is built from
/// (`buildAccountContainer`).
final crashReportingServiceProvider = Provider<CrashReportingService>(
  (ref) => CrashReportingService(),
);
