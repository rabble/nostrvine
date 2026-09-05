// ABOUTME: Account-scoped provider for BackgroundActivityManager
// ABOUTME: Replaces the factory singleton so tests get their own registry (#4743)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/background_activity_manager.dart';

/// The app's single [BackgroundActivityManager].
///
/// Replaces `factory BackgroundActivityManager() => _instance` (#4743).
///
/// Account-scoped, deliberately — unlike `crashReportingServiceProvider` and
/// `startupPerformanceServiceProvider`, which `DeviceScope` pins. All three
/// registrants (`AuthService`, `UploadManager`, `AnalyticsService`) are
/// account-scoped, and `ContainerSwapHost` remounts the subtree under a
/// `KeyedSubtree` on a swap, so `AppLifecycleHandler` re-reads this provider
/// and driver and registrants stay on one instance.
///
/// Pinning it device-wide would be worse: a registrant whose `dispose()` skips
/// the unregister (#8413 does exactly that when `initialize()` was still in
/// flight) would follow the user into the next account forever. Discarding the
/// whole manager on a swap bounds that leak to one session.
///
/// `background_activity_provider_test.dart` pins both halves: one instance per
/// container, and separate registries across containers.
///
/// Giving each test its own instance is the point. As a process global, its
/// registry only ever grew — a service registered by one test kept receiving
/// lifecycle callbacks for the rest of the merged isolate, and a later suite
/// driving `resumed` was blamed for what those strangers did (#6880).
final backgroundActivityManagerProvider = Provider<BackgroundActivityManager>(
  (ref) => BackgroundActivityManager(),
);
