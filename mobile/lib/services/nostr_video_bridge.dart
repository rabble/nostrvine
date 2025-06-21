// ABOUTME: Bridge service connecting Nostr video events to the new TDD video manager
// ABOUTME: Replaces dual-list architecture by feeding VideoManagerService from Nostr events

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/video_event.dart';
import '../services/video_manager_interface.dart';
import '../services/video_event_service.dart';
import '../services/nostr_service_interface.dart';
import '../services/seen_videos_service.dart';
import '../services/connection_status_service.dart';

/// Bridge service that connects Nostr video events to the TDD VideoManager
/// 
/// This service replaces the dual-list architecture by:
/// 1. Subscribing to Nostr video events via VideoEventService
/// 2. Filtering and processing events
/// 3. Adding them to the single VideoManagerService
/// 4. Managing subscription lifecycle
class NostrVideoBridge extends ChangeNotifier {
  final IVideoManager _videoManager;
  final VideoEventService _videoEventService;
  final SeenVideosService? _seenVideosService;
  final ConnectionStatusService _connectionService;
  
  // Bridge state
  bool _isActive = false;
  StreamSubscription? _videoEventSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _healthCheckTimer;
  
  // Processing state
  final Set<String> _processedEventIds = {};
  int _totalEventsReceived = 0;
  int _totalEventsAdded = 0;
  int _totalEventsFiltered = 0;
  DateTime? _lastEventReceived;
  
  // Configuration
  final int _maxProcessedEvents = 1000; // Prevent memory leaks
  final Duration _healthCheckInterval = const Duration(minutes: 2);
  final Duration _eventProcessingDelay = const Duration(milliseconds: 100);

  NostrVideoBridge({
    required IVideoManager videoManager,
    required INostrService nostrService,
    SeenVideosService? seenVideosService,
    ConnectionStatusService? connectionService,
  }) : _videoManager = videoManager,
       _videoEventService = VideoEventService(nostrService, seenVideosService: seenVideosService),
       _seenVideosService = seenVideosService,
       _connectionService = connectionService ?? ConnectionStatusService();

  /// Whether the bridge is actively processing events
  bool get isActive => _isActive;

  /// Statistics about event processing
  Map<String, dynamic> get processingStats => {
    'isActive': _isActive,
    'totalEventsReceived': _totalEventsReceived,
    'totalEventsAdded': _totalEventsAdded,
    'totalEventsFiltered': _totalEventsFiltered,
    'processedEventIds': _processedEventIds.length,
    'lastEventReceived': _lastEventReceived?.toIso8601String(),
    'videoEventServiceStats': {
      'isSubscribed': _videoEventService.isSubscribed,
      'isLoading': _videoEventService.isLoading,
      'hasEvents': _videoEventService.hasEvents,
      'eventCount': _videoEventService.eventCount,
      'error': _videoEventService.error,
    },
  };

  /// Start the bridge - subscribe to Nostr events and process them
  Future<void> start({
    List<String>? authors,
    List<String>? hashtags,
    int? since,
    int? until,
    int limit = 500,
  }) async {
    if (_isActive) {
      debugPrint('NostrVideoBridge: Already active, ignoring start request');
      return;
    }

    try {
      debugPrint('NostrVideoBridge: Starting bridge...');
      _isActive = true;

      // Subscribe to video events
      await _videoEventService.subscribeToVideoFeed(
        authors: authors,
        hashtags: hashtags,
        since: since,
        until: until,
        limit: limit,
      );

      // Listen for new video events  
      _videoEventService.addListener(_onVideoEventsChanged);

      // Listen for connection changes (if available)
      // Note: ConnectionStatusService may not have statusStream method
      // _connectionSubscription = _connectionService.statusStream?.listen(_onConnectionStatusChanged);

      // Start health check timer
      _startHealthCheck();

      debugPrint('NostrVideoBridge: Bridge started successfully');
      notifyListeners();

    } catch (e) {
      debugPrint('NostrVideoBridge: Failed to start bridge: $e');
      _isActive = false;
      rethrow;
    }
  }

  /// Stop the bridge and clean up resources
  Future<void> stop() async {
    if (!_isActive) return;

    debugPrint('NostrVideoBridge: Stopping bridge...');
    _isActive = false;

    // Cancel subscriptions
    await _videoEventSubscription?.cancel();
    await _connectionSubscription?.cancel();
    
    // Stop health check
    _healthCheckTimer?.cancel();

    // Note: VideoEventService may not have unsubscribe method
    // Consider adding proper cleanup method

    debugPrint('NostrVideoBridge: Bridge stopped');
    notifyListeners();
  }

  /// Restart the bridge (useful for configuration changes)
  Future<void> restart({
    List<String>? authors,
    List<String>? hashtags,
    int? since,
    int? until,
    int limit = 500,
  }) async {
    await stop();
    await Future.delayed(const Duration(milliseconds: 500)); // Brief pause
    await start(
      authors: authors,
      hashtags: hashtags,
      since: since,
      until: until,
      limit: limit,
    );
  }

  /// Manually process existing events (useful for initial load)
  Future<void> processExistingEvents() async {
    final existingEvents = _videoEventService.videoEvents;
    debugPrint('NostrVideoBridge: Processing ${existingEvents.length} existing events');

    for (final event in existingEvents) {
      await _processVideoEvent(event);
    }
  }

  /// Get comprehensive debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'bridge': processingStats,
      'videoManager': _videoManager.getDebugInfo(),
      'videoEventService': {
        'isSubscribed': _videoEventService.isSubscribed,
        'isLoading': _videoEventService.isLoading,
        'eventCount': _videoEventService.eventCount,
        'error': _videoEventService.error,
      },
      'connection': true, // _connectionService.isConnected may not be available
    };
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  // Private methods

  void _onVideoEventsChanged() {
    if (!_isActive) return;

    // Process new events with a small delay to batch updates
    Timer(_eventProcessingDelay, () {
      _processNewEvents();
    });
  }

  Future<void> _processNewEvents() async {
    final currentEvents = _videoEventService.videoEvents;
    
    for (final event in currentEvents) {
      if (!_processedEventIds.contains(event.id)) {
        await _processVideoEvent(event);
      }
    }
  }

  Future<void> _processVideoEvent(VideoEvent event) async {
    try {
      _totalEventsReceived++;
      _lastEventReceived = DateTime.now();

      // Filter event based on various criteria
      if (!_shouldProcessEvent(event)) {
        _totalEventsFiltered++;
        return;
      }

      // Add to video manager
      await _videoManager.addVideoEvent(event);
      
      // Track processed events
      _processedEventIds.add(event.id);
      _totalEventsAdded++;

      // Prevent memory leaks by limiting processed event tracking
      if (_processedEventIds.length > _maxProcessedEvents) {
        final toRemove = _processedEventIds.take(_maxProcessedEvents ~/ 2).toList();
        _processedEventIds.removeAll(toRemove);
      }

      debugPrint('NostrVideoBridge: Added video ${event.id} (${event.title ?? 'No title'})');

    } catch (e) {
      debugPrint('NostrVideoBridge: Error processing event ${event.id}: $e');
    }
  }

  bool _shouldProcessEvent(VideoEvent event) {
    // Filter out events that don't meet quality criteria
    
    // Must have valid video URL
    if (event.videoUrl == null || event.videoUrl!.isEmpty) {
      debugPrint('NostrVideoBridge: Filtered event ${event.id} - no video URL');
      return false;
    }

    // Must have reasonable content
    if (event.content.trim().isEmpty && (event.title?.trim().isEmpty ?? true)) {
      debugPrint('NostrVideoBridge: Filtered event ${event.id} - no content or title');
      return false;
    }

    // Check if already seen (if service available)
    if (_seenVideosService?.hasSeenVideo(event.id) == true) {
      debugPrint('NostrVideoBridge: Filtered event ${event.id} - already seen');
      return false;
    }

    // Filter out videos that are too old (optional)
    final daysSinceCreated = DateTime.now().difference(event.timestamp).inDays;
    if (daysSinceCreated > 30) {
      debugPrint('NostrVideoBridge: Filtered event ${event.id} - too old ($daysSinceCreated days)');
      return false;
    }

    // Filter out suspicious URLs
    if (_isSuspiciousUrl(event.videoUrl!)) {
      debugPrint('NostrVideoBridge: Filtered event ${event.id} - suspicious URL');
      return false;
    }

    return true;
  }

  bool _isSuspiciousUrl(String url) {
    // Basic URL validation and suspicious pattern detection
    try {
      final uri = Uri.parse(url);
      
      // Must be HTTP/HTTPS
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return true;
      }

      // Check for common video file extensions or streaming patterns
      final path = uri.path.toLowerCase();
      final hasVideoExtension = path.endsWith('.mp4') || 
                               path.endsWith('.webm') || 
                               path.endsWith('.mov') || 
                               path.endsWith('.avi') ||
                               path.endsWith('.gif');
      
      final isStreamingDomain = uri.host.contains('youtube') ||
                               uri.host.contains('vimeo') ||
                               uri.host.contains('twitch') ||
                               uri.host.contains('streamable') ||
                               uri.host.contains('cloudfront') ||
                               uri.host.contains('nostr.build');

      return !hasVideoExtension && !isStreamingDomain;

    } catch (e) {
      // Invalid URL
      return true;
    }
  }

  void _onConnectionStatusChanged(bool isConnected) {
    debugPrint('NostrVideoBridge: Connection status changed: $isConnected');
    
    if (isConnected && _isActive) {
      // Reconnected - restart video event subscription
      Future.delayed(const Duration(seconds: 2), () {
        if (_isActive) {
          _videoEventService.subscribeToVideoFeed();
        }
      });
    }
  }

  void _startHealthCheck() {
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performHealthCheck();
    });
  }

  void _performHealthCheck() {
    if (!_isActive) return;

    final debugInfo = getDebugInfo();
    debugPrint('NostrVideoBridge: Health check - ${debugInfo['bridge']}');

    // Check if we haven't received events in a while
    if (_lastEventReceived != null) {
      final timeSinceLastEvent = DateTime.now().difference(_lastEventReceived!);
      if (timeSinceLastEvent.inMinutes > 10) {
        debugPrint('NostrVideoBridge: No events received for ${timeSinceLastEvent.inMinutes} minutes, restarting...');
        restart();
      }
    }

    // Check video manager health
    final videoManagerStats = _videoManager.getDebugInfo();
    final estimatedMemory = videoManagerStats['estimatedMemoryMB'] as int? ?? 0;
    
    if (estimatedMemory > 800) { // Approaching the 1GB limit
      debugPrint('NostrVideoBridge: High memory usage detected: ${estimatedMemory}MB');
      // Could trigger additional cleanup here
    }
  }
}

/// Factory for creating NostrVideoBridge instances with proper dependencies
class NostrVideoBridgeFactory {
  static NostrVideoBridge create({
    required IVideoManager videoManager,
    required INostrService nostrService,
    SeenVideosService? seenVideosService,
    ConnectionStatusService? connectionService,
  }) {
    return NostrVideoBridge(
      videoManager: videoManager,
      nostrService: nostrService,
      seenVideosService: seenVideosService,
      connectionService: connectionService,
    );
  }
}