// ABOUTME: Handles deferred initialization of notification service
// ABOUTME: Replaces Future.delayed with proper async patterns

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Handles deferred initialization of notification service
class DeferredNotificationInitializer {
  /// Initialize notification service with appropriate deferral strategy
  static Future<void> initialize({
    required NotificationServiceEnhanced service,
    required NostrClient nostrService,
    required ProfileRepository profileRepository,
    required VideoEventService videoService,
    required bool isWeb,
  }) async {
    if (!isWeb) {
      await _initializeService(
        service: service,
        nostrService: nostrService,
        profileRepository: profileRepository,
        videoService: videoService,
      );
      return;
    }

    _scheduleWebInitialization(
      service: service,
      nostrService: nostrService,
      profileRepository: profileRepository,
      videoService: videoService,
    );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_areServicesReady(nostrService)) {
        unawaited(
          _initializeService(
            service: service,
            nostrService: nostrService,
            profileRepository: profileRepository,
            videoService: videoService,
          ),
        );
        return;
      }

      Log.info(
        'Notification service init scheduled before relay readiness; continuing without fixed delay',
        name: 'NotificationInit',
      );
      unawaited(
        _initializeService(
          service: service,
          nostrService: nostrService,
          profileRepository: profileRepository,
          videoService: videoService,
        ),
      );
    });
  }

  /// Check if required services are ready
  static bool _areServicesReady(NostrClient nostrService) =>
      // Check if services have completed basic initialization
      nostrService.connectedRelayCount > 0;
}
