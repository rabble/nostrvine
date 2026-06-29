// ABOUTME: Riverpod providers for the analytics package's tracker services,
// ABOUTME: migrated off the factory-singleton pattern to constructor injection (#4743).

import 'package:analytics/analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
