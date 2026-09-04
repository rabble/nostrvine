// ABOUTME: Device-scoped provider for BackgroundActivityManager
// ABOUTME: Replaces the factory singleton so tests get their own registry (#4743)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/background_activity_manager.dart';

/// The app's single [BackgroundActivityManager].
///
/// Replaces `factory BackgroundActivityManager() => _instance` (#4743).
/// Device-scoped: it observes the process lifecycle and its registry must
/// outlive an account swap, so `DeviceScope` pins one instance across every
/// container.
///
/// Giving each test its own instance is the point. As a process global, its
/// registry only ever grew — a service registered by one test kept receiving
/// lifecycle callbacks for the rest of the merged isolate, and a later suite
/// driving `resumed` was blamed for what those strangers did (#6880).
final backgroundActivityManagerProvider = Provider<BackgroundActivityManager>(
  (ref) => BackgroundActivityManager(),
);
