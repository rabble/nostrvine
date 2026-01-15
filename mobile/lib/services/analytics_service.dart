// ABOUTME: Analytics service for tracking video views with user opt-out support
import 'package:flutter/foundation.dart'; // ABOUTME: Sends anonymous view data to divine analytics backend when enabled

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/utils/async_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for tracking video analytics with privacy controls
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
///
/// ## Analytics Backend Integration (TODO)
///
/// This service is designed to integrate with the DiVine FunnelCake relay's
/// analytics API at https://relay.staging.dvines.org/
///
/// **Current Status**: STUBBED - Analytics sending is disabled until the
/// backend POST endpoint is implemented.
///
/// **Planned Endpoints**:
/// - POST /api/analytics/view - Record video view events
/// - GET /api/videos/{id}/views - Retrieve view stats (already available)
/// - GET /api/videos/{id}/stats - Retrieve engagement stats (already available)
///
/// **Swagger Documentation**: https://relay.staging.dvines.org/swagger-ui/
///
/// When the backend is ready:
/// 1. Set [_analyticsBackendReady] to true
/// 2. Update [_analyticsEndpoint] if the path differs
/// 3. Verify request/response format matches backend expectations
class AnalyticsService implements BackgroundAwareService {
  AnalyticsService({
    http.Client? client,
    @visibleForTesting bool? backendReadyOverride,
  }) : _client = client ?? http.Client(),
       _backendReadyOverride = backendReadyOverride;

  /// Base URL for the DiVine FunnelCake relay analytics API
  static const String _analyticsBaseUrl = 'https://relay.staging.dvines.org';

  /// Full endpoint for posting view analytics
  /// TODO: Confirm exact path when backend implements POST endpoint
  static const String _analyticsEndpoint =
      '$_analyticsBaseUrl/api/analytics/view';

  /// Feature flag: Set to true when backend POST endpoint is implemented
  /// Currently stubbed out - no requests are sent
  static const bool _analyticsBackendReady = false;

  static const String _analyticsEnabledKey = 'analytics_enabled';
  static const Duration _requestTimeout = Duration(seconds: 10);

  final http.Client _client;

  /// Testing override for backend readiness - allows tests to simulate
  /// a ready backend without changing the static const flag
  final bool? _backendReadyOverride;
  bool _analyticsEnabled = true; // Default to enabled
  bool _isInitialized = false;

  // Track recent views to prevent duplicate tracking
  final Set<String> _recentlyTrackedViews = {};
  Timer? _cleanupTimer;

  // Background activity management
  bool _isInBackground = false;
  final List<Map<String, dynamic>> _pendingAnalytics = [];

  // Track active retry operations to cancel on dispose
  bool _isDisposed = false;

  /// Initialize the analytics service
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
        Log.debug(
          '📱 Registered AnalyticsService with background activity manager',
          name: 'AnalyticsService',
          category: LogCategory.system,
        );
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

  /// Whether the analytics backend is ready to receive requests
  /// Returns false while the funnelcake POST endpoint is not yet implemented
  static bool get isBackendReady => _analyticsBackendReady;

  /// Instance-level check for backend readiness
  /// Uses testing override if provided, otherwise falls back to static const
  bool get _isBackendReady => _backendReadyOverride ?? _analyticsBackendReady;

  /// Get current analytics enabled state (user preference)
  bool get analyticsEnabled => _analyticsEnabled;

  /// Whether analytics tracking is currently operational
  /// Requires both backend to be ready AND user to have analytics enabled
  bool get isOperational => _isBackendReady && _analyticsEnabled;

  /// Set analytics enabled state
  Future<void> setAnalyticsEnabled(bool enabled) async {
    if (_analyticsEnabled == enabled) return;

    _analyticsEnabled = enabled;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_analyticsEnabledKey, enabled);

      debugPrint('📊 Analytics ${enabled ? 'enabled' : 'disabled'} by user');
    } catch (e) {
      Log.error(
        'Failed to save analytics preference: $e',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );
    }
  }

  /// Track a basic video view (when video starts playing)
  Future<void> trackVideoView(
    VideoEvent video, {
    String source = 'mobile',
  }) async {
    trackDetailedVideoView(video, source: source, eventType: 'view_start');
  }

  /// Track a video view with user identification for proper analytics
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

  /// Track detailed video interaction events
  Future<void> trackDetailedVideoView(
    VideoEvent video, {
    required String source,
    required String
    eventType, // 'view_start', 'view_end', 'loop', 'pause', 'resume', 'skip'
    Duration? watchDuration,
    Duration? totalDuration,
    int? loopCount,
    bool? completedVideo,
  }) async {
    trackDetailedVideoViewWithUser(
      video,
      userId: null, // Legacy method - no user ID
      source: source,
      eventType: eventType,
      watchDuration: watchDuration,
      totalDuration: totalDuration,
      loopCount: loopCount,
      completedVideo: completedVideo,
    );
  }

  /// Track detailed video interaction events with user identification
  Future<void> trackDetailedVideoViewWithUser(
    VideoEvent video, {
    required String? userId,
    required String source,
    required String
    eventType, // 'view_start', 'view_end', 'loop', 'pause', 'resume', 'skip'
    Duration? watchDuration,
    Duration? totalDuration,
    int? loopCount,
    bool? completedVideo,
  }) async {
    // Check if backend is ready (feature flag)
    if (!_isBackendReady) {
      // TODO: Remove this check when funnelcake backend POST endpoint is ready
      // See: https://relay.staging.dvines.org/swagger-ui/
      Log.debug(
        'Analytics backend not ready - skipping $eventType tracking',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );
      return;
    }

    // Check if analytics is enabled by user preference
    if (!_analyticsEnabled) {
      Log.debug(
        'Analytics disabled by user - not tracking view',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );
      return;
    }

    // Fire-and-forget analytics to avoid blocking the UI
    _trackDetailedVideoViewWithRetry(
      video,
      userId,
      source,
      eventType,
      watchDuration: watchDuration,
      totalDuration: totalDuration,
      loopCount: loopCount,
      completedVideo: completedVideo,
    ).catchError((error) {
      Log.error(
        'Analytics tracking failed after retries: $error',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );
    });
  }

  /// Internal method to track detailed video view with retry logic
  Future<void> _trackDetailedVideoViewWithRetry(
    VideoEvent video,
    String? userId,
    String source,
    String eventType, {
    Duration? watchDuration,
    Duration? totalDuration,
    int? loopCount,
    bool? completedVideo,
    int attempt = 1,
    int maxAttempts = 3,
  }) async {
    try {
      // Prepare detailed view data
      final viewData = {
        'eventId': video.id,
        'userId': userId, // Include user ID for proper unique viewer counting
        'source': source,
        'eventType': eventType,
        'creatorPubkey': video.pubkey,
        'hashtags': video.hashtags.isNotEmpty ? video.hashtags : null,
        'title': video.title,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Add optional engagement metrics (backend expects these field names)
      if (watchDuration != null) {
        viewData['watchDuration'] = watchDuration.inMilliseconds;
      }
      if (totalDuration != null) {
        viewData['totalDuration'] = totalDuration.inMilliseconds;
        if (watchDuration != null) {
          viewData['completionRate'] =
              (watchDuration.inMilliseconds / totalDuration.inMilliseconds)
                  .clamp(0.0, 1.0);
        }
      }
      if (loopCount != null) {
        viewData['loopCount'] = loopCount;
      }
      if (completedVideo != null) {
        viewData['completedVideo'] = completedVideo;
      }

      // Log only on first attempt to reduce noise
      if (attempt == 1) {
        Log.info(
          '📊 Tracking $eventType for video ${video.id}',
          name: 'AnalyticsService',
          category: LogCategory.system,
        );
      }

      // Send view tracking request
      final response = await _client
          .post(
            Uri.parse(_analyticsEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'divine-Mobile/1.0',
            },
            body: jsonEncode(viewData),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        Log.debug(
          '✅ Successfully tracked $eventType for video ${video.id} (attempt $attempt)',
          name: 'AnalyticsService',
          category: LogCategory.system,
        );
      } else if (response.statusCode == 429) {
        Log.warning(
          '⚠️ Rate limited by analytics service (attempt $attempt)',
          name: 'AnalyticsService',
          category: LogCategory.system,
        );
        // Don't retry on rate limits
        return;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      Log.warning(
        'Analytics attempt $attempt failed: $e',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );

      // Retry with exponential backoff if we haven't reached max attempts
      if (attempt < maxAttempts) {
        // Check if disposed before scheduling retry
        if (_isDisposed) {
          Log.debug(
            'Analytics service disposed, skipping retry',
            name: 'AnalyticsService',
            category: LogCategory.system,
          );
          return;
        }

        final delay = Duration(milliseconds: 1000 * attempt); // 1s, 2s, 3s...
        await Future.delayed(delay);

        // Check if disposed after delay
        if (_isDisposed) {
          Log.debug(
            'Analytics service disposed during retry delay',
            name: 'AnalyticsService',
            category: LogCategory.system,
          );
          return;
        }

        await _trackDetailedVideoViewWithRetry(
          video,
          userId,
          source,
          eventType,
          watchDuration: watchDuration,
          totalDuration: totalDuration,
          loopCount: loopCount,
          completedVideo: completedVideo,
          attempt: attempt + 1,
          maxAttempts: maxAttempts,
        );
      } else {
        // Log final failure but don't crash the app
        Log.error(
          'Analytics tracking failed after $maxAttempts attempts: $e',
          name: 'AnalyticsService',
          category: LogCategory.system,
        );
        rethrow;
      }
    }
  }

  /// Track multiple video views in batch (for feed loading)
  Future<void> trackVideoViews(
    List<VideoEvent> videos, {
    String source = 'mobile',
  }) async {
    // Skip if backend not ready or analytics disabled
    if (!_isBackendReady || !_analyticsEnabled || videos.isEmpty) return;

    // Create operations for rate-limited execution
    final operations = videos
        .map(
          (video) => () async {
            await trackVideoView(video, source: source);
            return null; // Return void as Future<void?>
          },
        )
        .toList();

    // Execute with proper rate limiting instead of Future.delayed
    await AsyncUtils.executeWithRateLimit(
      operations: operations,
      minInterval: const Duration(milliseconds: 100),
      debugName: 'Analytics batch tracking',
    );
  }

  /// Clear tracked views cache
  void clearTrackedViews() {
    _recentlyTrackedViews.clear();
  }

  // BackgroundAwareService implementation
  @override
  String get serviceName => 'AnalyticsService';

  @override
  void onAppBackgrounded() {
    _isInBackground = true;
    Log.info(
      '📱 AnalyticsService: App backgrounded - queuing analytics',
      name: 'AnalyticsService',
      category: LogCategory.system,
    );
  }

  @override
  void onExtendedBackground() {
    if (_isInBackground) {
      Log.info(
        '📱 AnalyticsService: Extended background - suspending network requests',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );
      // Analytics will be queued and sent when app resumes
    }
  }

  @override
  void onAppResumed() {
    _isInBackground = false;
    Log.info(
      '📱 AnalyticsService: App resumed - processing pending analytics',
      name: 'AnalyticsService',
      category: LogCategory.system,
    );

    // Process any pending analytics
    if (_pendingAnalytics.isNotEmpty) {
      Log.info(
        '📊 Processing ${_pendingAnalytics.length} pending analytics',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );

      // Process pending analytics asynchronously
      _processPendingAnalytics();
    }
  }

  @override
  void onPeriodicCleanup() {
    if (!_isInBackground) {
      Log.debug(
        '🧹 AnalyticsService: Performing periodic cleanup',
        name: 'AnalyticsService',
        category: LogCategory.system,
      );

      // Clear old tracked views to prevent memory growth
      _recentlyTrackedViews.clear();
    }
  }

  /// Process any analytics that were queued while in background
  Future<void> _processPendingAnalytics() async {
    if (_pendingAnalytics.isEmpty || _isInBackground) return;

    final analytics = List<Map<String, dynamic>>.from(_pendingAnalytics);
    _pendingAnalytics.clear();

    for (final analytic in analytics) {
      try {
        if (!_isInBackground && _analyticsEnabled) {
          // Send the queued analytics
          // This would require refactoring the tracking methods to accept raw data
          Log.debug(
            '📊 Sending queued analytic: ${analytic['event_type']}',
            name: 'AnalyticsService',
            category: LogCategory.system,
          );
        }
      } catch (e) {
        Log.error(
          'Failed to send queued analytics: $e',
          name: 'AnalyticsService',
          category: LogCategory.system,
        );
      }
    }
  }

  void dispose() {
    _isDisposed = true;
    _cleanupTimer?.cancel();
    _client.close();
  }
}
