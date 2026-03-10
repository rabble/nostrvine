// ABOUTME: Handles deferred initialization of notification service
// ABOUTME: Replaces Future.delayed with proper async patterns

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/async_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:profile_repository/profile_repository.dart';

/// Handles deferred initialization of notification service
class DeferredNotificationInitializer {
  static const Duration _webDeferralTime = Duration(seconds: 3);

  /// Initialize notification service with appropriate deferral strategy
  static Future<void> initialize({
    required NotificationServiceEnhanced service,
    required NostrClient nostrService,
    required ProfileRepository profileRepository,
    required VideoEventService videoService,
    required bool isWeb,
  }) async {
    if (!isWeb) {
      // Mobile: Initialize immediately
      await _initializeService(
        service: service,
        nostrService: nostrService,
        profileRepository: profileRepository,
        videoService: videoService,
      );
    } else {
      // Web: Initialize after main UI loads
      _scheduleWebInitialization(
        service: service,
        nostrService: nostrService,
        profileRepository: profileRepository,
        videoService: videoService,
      );
    }
  }

  /// Initialize the notification service
  static Future<void> _initializeService({
    required NotificationServiceEnhanced service,
    required NostrClient nostrService,
    required ProfileRepository profileRepository,
    required VideoEventService videoService,
  }) async {
    try {
      await service.initialize(
        nostrService: nostrService,
        profileRepository: profileRepository,
        videoService: videoService,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize enhanced notification service: $e',
        name: 'NotificationInit',
        category: LogCategory.system,
      );
    }
  }

  /// Schedule web initialization using proper async patterns
  static void _scheduleWebInitialization({
    required NotificationServiceEnhanced service,
    required NostrClient nostrService,
    required ProfileRepository profileRepository,
    required VideoEventService videoService,
  }) {
    // Use a completer to track when main UI is ready
    final readyCompleter = Completer<void>();

    // Wait for next frame to ensure UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if critical services are ready
      AsyncUtils.waitForCondition(
            condition: () => _areServicesReady(nostrService),
            timeout: _webDeferralTime,
            debugName: 'notification-service-readiness',
          )
          .then((_) {
            readyCompleter.complete();
          })
          .catchError((e) {
            Log.warning(
              'Timeout waiting for services, initializing notification service anyway',
              name: 'NotificationInit',
            );
            readyCompleter.complete();
          });
    });

    // Initialize when ready
    readyCompleter.future.then((_) async {
      await _initializeService(
        service: service,
        nostrService: nostrService,
        profileRepository: profileRepository,
        videoService: videoService,
      );
    });
  }

  /// Check if required services are ready
  static bool _areServicesReady(NostrClient nostrService) =>
      // Check if services have completed basic initialization
      nostrService.connectedRelayCount > 0;
}
