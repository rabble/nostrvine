// ABOUTME: Riverpod providers for the analytics package's tracker services,
// ABOUTME: migrated off the factory-singleton pattern to constructor injection (#4743).

import 'package:analytics/analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/creation_analytics/creation_analytics_tracker.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:unified_logger/unified_logger.dart';

typedef CrashUserIdSetter = Future<void> Function(String? userId);

/// Keeps Firebase Analytics and Crashlytics on the same authenticated identity.
class AnalyticsIdentityCoordinator {
  AnalyticsIdentityCoordinator({
    required AnalyticsEventSink analytics,
    required CrashUserIdSetter setCrashUserId,
  }) : _analytics = analytics,
       _setCrashUserId = setCrashUserId;

  final AnalyticsEventSink _analytics;
  final CrashUserIdSetter _setCrashUserId;

  Future<void> setUserId(String? pubkeyHex) async {
    if (pubkeyHex != null &&
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(pubkeyHex)) {
      Log.error(
        'Refusing to set a non-hex analytics user ID',
        name: 'AnalyticsIdentityCoordinator',
        category: LogCategory.auth,
      );
      return;
    }

    try {
      await _analytics.setUserId(pubkeyHex);
    } catch (error) {
      Log.warning(
        'Failed to update the Firebase Analytics identity: $error',
        name: 'AnalyticsIdentityCoordinator',
        category: LogCategory.auth,
      );
    }

    if (pubkeyHex == null) {
      try {
        await _analytics.setUserProperty(
          name: AnalyticsUserProperty.inviteCode,
          value: null,
        );
      } catch (error) {
        Log.warning(
          'Failed to clear Firebase Analytics invite attribution: $error',
          name: 'AnalyticsIdentityCoordinator',
          category: LogCategory.auth,
        );
      }
    }

    try {
      await _setCrashUserId(pubkeyHex);
    } catch (error) {
      Log.warning(
        'Failed to update the Crashlytics identity: $error',
        name: 'AnalyticsIdentityCoordinator',
        category: LogCategory.auth,
      );
    }
  }
}

/// Provides the low-level analytics event sink for feature-specific events.
final analyticsEventSinkProvider = Provider<AnalyticsEventSink>(
  (ref) => FirebaseAnalyticsEventSink(),
);

final creationAnalyticsTrackerProvider = Provider<CreationAnalyticsTracker>(
  (ref) => CreationAnalyticsTracker(
    analytics: ref.watch(analyticsEventSinkProvider),
  ),
);

final analyticsIdentityCoordinatorProvider =
    Provider<AnalyticsIdentityCoordinator>(
      (ref) => AnalyticsIdentityCoordinator(
        analytics: ref.watch(analyticsEventSinkProvider),
        setCrashUserId: CrashReportingService.instance.setUserId,
      ),
    );

/// Provides the app's shared [SurfacePerformanceTracker].
///
/// Replaces the former `SurfacePerformanceTracker()` factory singleton. A
/// single shared instance is kept alive so surface-load sessions started by
/// one consumer are visible to the resume-time reset in the app lifecycle
/// handler, and the tracker is mockable through a provider override in tests
/// instead of reaching into static state.
final surfacePerformanceTrackerProvider = Provider<SurfacePerformanceTracker>(
  (ref) => SurfacePerformanceTracker(),
);

/// Provides the app's shared [ErrorAnalyticsTracker].
///
/// Replaces the former `ErrorAnalyticsTracker()` factory singleton. A single
/// shared instance is kept alive so per-error counts accumulate in one place
/// (read back by the bug-report diagnostics), and the tracker is mockable
/// through a provider override in tests instead of reaching into static state.
final errorAnalyticsTrackerProvider = Provider<ErrorAnalyticsTracker>(
  (ref) => ErrorAnalyticsTracker(),
);
