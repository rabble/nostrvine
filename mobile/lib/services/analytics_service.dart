// ABOUTME: Analytics service for tracking video views with user opt-out support
// ABOUTME: Publishes Kind 22236 ephemeral Nostr view events for decentralized analytics

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for tracking video analytics with privacy controls.
///
/// Publishes Kind 22236 ephemeral Nostr view events via [ViewEventPublisher].
/// The relay processes these events in real-time for creator analytics,
/// recommendation systems, and aggregated view stats.
///
/// Stats are available via the relay REST API:
/// - GET /api/videos/{id}/views - Retrieve view stats
/// - GET /api/videos/{id}/stats - Retrieve engagement stats
class AnalyticsService implements BackgroundAwareService {
  AnalyticsService({
    ViewEventPublisher? viewEventPublisher,
    @visibleForTesting bool? disableNostrPublishing,
  }) : _viewEventPublisher = viewEventPublisher,
       _disableNostrPublishing = disableNostrPublishing ?? false;

  /// The view event publisher for Kind 22236 Nostr events.
  ViewEventPublisher? _viewEventPublisher;

  /// Testing flag to disable Nostr publishing in unit tests.
  final bool _disableNostrPublishing;

  static const String _analyticsEnabledKey = 'analytics_enabled';

  bool _analyticsEnabled = true; // Default to enabled
  bool _isInitialized = false;

  // Track recent views to prevent duplicate tracking
  final Set<String> _recentlyTrackedViews = {};
  Timer? _cleanupTimer;

  // Background activity management
  bool _isInBackground = false;

  // Track disposal state
  bool _isDisposed = false;

  /// Update the view event publisher (e.g. when Nostr client reconnects).
  void updateViewEventPublisher(ViewEventPublisher? publisher) {
    _viewEventPublisher = publisher;
  }

  /// Initialize the analytics service.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load analytics preference from storage
      final prefs = await SharedPreferences.getInstance();
      _analyticsEnabled = prefs.getBool(_analyticsEnabledKey) ?? true;
      _isInitialized = true;

      // Set up periodic cleanup of tracked views
      _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        _recentlyTrackedViews.clear();
      });

      // Register with background activity manager
      try {
        BackgroundActivityManager().registerService(this);
      } catch (e) {
        Log.warning(
          'Could not register with background activity manager: $e',
          name: 'AnalyticsService',
          category: LogCategory.system,
        );
      }

      Log.info(
        'Analytics service initialized (enabled: $_analyticsEnabled)',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize analytics service: $e',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );
      _isInitialized = true; // Mark as initialized even on error
    }
  }

  /// Get current analytics enabled state (user preference).
  bool get analyticsEnabled => _analyticsEnabled;

  /// Whether analytics tracking is currently operational.
  bool get isOperational => _analyticsEnabled;

  /// Set analytics enabled state.
  Future<void> setAnalyticsEnabled(bool enabled) async {
    if (_analyticsEnabled == enabled) return;

    _analyticsEnabled = enabled;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_analyticsEnabledKey, enabled);

      debugPrint('Analytics ${enabled ? 'enabled' : 'disabled'} by user');
    } catch (e) {
      Log.error(
        'Failed to save analytics preference: $e',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );
    }
  }

  /// Track a basic video view (when video starts playing).
  Future<void> trackVideoView(
    VideoEvent video, {
    String source = 'mobile',
  }) async {
    trackDetailedVideoView(video, source: source, eventType: 'view_start');
  }

  /// Track a video view with user identification for proper analytics.
  Future<void> trackVideoViewWithUser(
    VideoEvent video, {
    required String? userId,
    String source = 'mobile',
  }) async {
    trackDetailedVideoViewWithUser(
      video,
      userId: userId,
      source: source,
      eventType: 'view_start',
    );
  }

  /// Track detailed video interaction events.
  Future<void> trackDetailedVideoView(
    VideoEvent video, {
    required String source,
    required String eventType,
    Duration? watchDuration,
    Duration? totalDuration,
    int? loopCount,
    bool? completedVideo,
    ViewTrafficSource trafficSource = ViewTrafficSource.unknown,
    String? sourceDetail,
  }) async {
    trackDetailedVideoViewWithUser(
      video,
      userId: null,
      source: source,
      eventType: eventType,
      watchDuration: watchDuration,
      totalDuration: totalDuration,
      loopCount: loopCount,
      completedVideo: completedVideo,
      trafficSource: trafficSource,
      sourceDetail: sourceDetail,
    );
  }

  /// Track detailed video interaction events with user identification.
  ///
  /// For `view_end` events with meaningful watch duration, publishes a
  /// Kind 22236 ephemeral Nostr event via [ViewEventPublisher].
  Future<void> trackDetailedVideoViewWithUser(
    VideoEvent video, {
    required String? userId,
    required String source,
    required String eventType,
    Duration? watchDuration,
    Duration? totalDuration,
    int? loopCount,
    bool? completedVideo,
    ViewTrafficSource trafficSource = ViewTrafficSource.unknown,
    String? sourceDetail,
  }) async {
    if (_isDisposed) return;

    // Check if analytics is enabled by user preference
    if (!_analyticsEnabled) {
      return;
    }

    // Deduplicate rapid-fire tracking of the same video
    final dedupeKey = '${video.id}_$eventType';
    if (eventType == 'view_start' &&
        _recentlyTrackedViews.contains(dedupeKey)) {
      return;
    }
    if (eventType == 'view_start') {
      _recentlyTrackedViews.add(dedupeKey);
    }

    Log.debug(
      'Tracking $eventType for video ${video.id}',
      name: 'AnalyticsService',
      category: LogCategory.video,
    );

    // Publish Kind 22236 Nostr view event for view_end with meaningful data
    if (eventType == 'view_end' &&
        watchDuration != null &&
        watchDuration.inSeconds >= 1 &&
        !_disableNostrPublishing) {
      _publishNostrViewEvent(
        video: video,
        watchDuration: watchDuration,
        trafficSource: trafficSource,
        sourceDetail: sourceDetail,
        loopCount: loopCount,
      );
    }
  }

  /// Publish Kind 22236 ephemeral view event to Nostr relays.
  void _publishNostrViewEvent({
    required VideoEvent video,
    required Duration watchDuration,
    required ViewTrafficSource trafficSource,
    String? sourceDetail,
    int? loopCount,
  }) {
    final publisher = _viewEventPublisher;
    if (publisher == null) {
      Log.debug(
        'ViewEventPublisher not available, skipping Nostr view event',
        name: 'AnalyticsService',
        category: LogCategory.video,
      );
      return;
    }

    // Fire-and-forget: don't await, don't block
    publisher
        .publishViewEvent(
          video: video,
          startSeconds: 0,
          endSeconds: watchDuration.inSeconds,
          source: trafficSource,
          sourceDetail: sourceDetail,
          loopCount: loopCount,
        )
        .then((success) {
          if (success) {
            Log.debug(
              'Published Nostr view event for ${video.id}',
              name: 'AnalyticsService',
              category: LogCategory.video,
            );
          }
        })
        .catchError((Object error) {
          // Silently ignore errors - view events are best-effort
          Log.debug(
            'Failed to publish Nostr view event: $error',
            name: 'AnalyticsService',
            category: LogCategory.video,
          );
        });
  }

  /// Track multiple video views in batch (for feed loading).
  Future<void> trackVideoViews(
    List<VideoEvent> videos, {
    String source = 'mobile',
  }) async {
    if (!_analyticsEnabled || videos.isEmpty) return;

    for (final video in videos) {
      await trackVideoView(video, source: source);
    }
  }

  /// Clear tracked views cache.
  void clearTrackedViews() {
    _recentlyTrackedViews.clear();
  }

  // BackgroundAwareService implementation
  @override
  String get serviceName => 'AnalyticsService';

  @override
  void onAppBackgrounded() {
    _isInBackground = true;
  }

  @override
  void onExtendedBackground() {
    // No-op: Nostr events are fire-and-forget
  }

  @override
  void onAppResumed() {
    _isInBackground = false;
  }

  @override
  void onPeriodicCleanup() {
    if (!_isInBackground) {
      _recentlyTrackedViews.clear();
    }
  }

  void dispose() {
    _isDisposed = true;
    _cleanupTimer?.cancel();
  }
}
