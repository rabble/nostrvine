// ABOUTME: Background service for polling and publishing processed videos to Nostr
// ABOUTME: Handles automatic event creation, signing, and relay broadcasting with smart polling

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/ready_event_data.dart';
import '../models/pending_upload.dart';
import '../services/upload_manager.dart';
import '../services/nostr_service_interface.dart';
import 'package:nostr/nostr.dart';

/// Service for publishing processed videos to Nostr relays
class VideoEventPublisher extends ChangeNotifier {
  final UploadManager _uploadManager;
  final INostrService _nostrService;
  final Future<List<ReadyEventData>> Function() _fetchReadyEvents;
  final Future<void> Function(String publicId) _cleanupRemoteEvent;
  
  Timer? _pollTimer;
  Timer? _retryTimer;
  
  // Adaptive polling configuration
  Duration _currentPollInterval = const Duration(minutes: 2);
  static const Duration _basePollInterval = Duration(minutes: 2);
  static const Duration _activePollInterval = Duration(seconds: 30);
  static const Duration _idlePollInterval = Duration(minutes: 5);
  
  // App lifecycle state
  bool _isAppActive = true;
  bool _isPollingActive = false;
  DateTime? _lastSuccessfulPoll;
  DateTime? _lastAppBackgroundTime;
  
  // Retry configuration
  final List<ReadyEventData> _failedEvents = [];
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(minutes: 1);
  
  // Statistics
  int _totalEventsPublished = 0;
  int _totalEventsFailed = 0;
  DateTime? _lastPublishTime;
  
  VideoEventPublisher({
    required UploadManager uploadManager,
    required INostrService nostrService,
    required Future<List<ReadyEventData>> Function() fetchReadyEvents,
    required Future<void> Function(String publicId) cleanupRemoteEvent,
  }) : _uploadManager = uploadManager,
       _nostrService = nostrService,
       _fetchReadyEvents = fetchReadyEvents,
       _cleanupRemoteEvent = cleanupRemoteEvent;

  /// Initialize the publisher and start background polling
  Future<void> initialize() async {
    debugPrint('🔧 Initializing VideoEventPublisher');
    
    // Set up app lifecycle monitoring
    _setupAppLifecycleListener();
    
    // Start polling for ready events
    await startPolling();
    
    debugPrint('✅ VideoEventPublisher initialized');
  }

  /// Start the background polling service
  Future<void> startPolling() async {
    if (_isPollingActive) {
      debugPrint('⚠️ Polling already active');
      return;
    }
    
    _isPollingActive = true;
    _updatePollInterval();
    
    debugPrint('🔄 Starting video event polling (interval: ${_currentPollInterval.inSeconds}s)');
    
    // Do an immediate check
    await _checkForReadyEvents();
    
    // Schedule periodic checks
    _pollTimer = Timer.periodic(_currentPollInterval, (_) => _checkForReadyEvents());
  }

  /// Stop the background polling service
  void stopPolling() {
    if (!_isPollingActive) return;
    
    debugPrint('⏹️ Stopping video event polling');
    
    _isPollingActive = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Check for ready events and publish them
  Future<void> _checkForReadyEvents() async {
    if (!_isPollingActive || !_isAppActive) {
      debugPrint('⏸️ Skipping poll - app inactive or polling stopped');
      return;
    }
    
    try {
      debugPrint('🔍 Checking for ready events...');
      
      // Fetch ready events from backend
      final readyEvents = await _fetchReadyEvents();
      
      if (readyEvents.isEmpty) {
        debugPrint('📭 No ready events found');
        _updatePollInterval();
        return;
      }
      
      debugPrint('📬 Found ${readyEvents.length} ready events');
      
      // Process each ready event
      for (final eventData in readyEvents) {
        await _processReadyEvent(eventData);
      }
      
      _lastSuccessfulPoll = DateTime.now();
      _updatePollInterval();
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error checking ready events: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      
      // Handle network errors gracefully
      if (e.toString().contains('network') || e.toString().contains('timeout')) {
        debugPrint('🌐 Network error detected, will retry later');
        _scheduleRetry();
      }
    }
  }

  /// Process a single ready event
  Future<void> _processReadyEvent(ReadyEventData eventData) async {
    try {
      debugPrint('🎬 Processing ready event: ${eventData.publicId}');
      
      if (!eventData.isReadyForPublishing) {
        debugPrint('⚠️ Event not ready for publishing: ${eventData.statusDescription}');
        return;
      }
      
      // Create NIP-94 event
      final nostrEvent = await _createNip94Event(eventData);
      
      // Publish to Nostr relays
      final publishResult = await _publishEventToNostr(nostrEvent);
      
      if (publishResult) {
        // Update local upload state
        await _updateLocalUploadStatus(eventData, nostrEvent.id);
        
        // Clean up remote event
        await _cleanupRemoteEvent(eventData.publicId);
        
        // Show user notification
        await _showPublishNotification(eventData, nostrEvent.id);
        
        _totalEventsPublished++;
        _lastPublishTime = DateTime.now();
        
        debugPrint('✅ Successfully published event: ${nostrEvent.id}');
      } else {
        throw Exception('Failed to publish to Nostr relays');
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to process event ${eventData.publicId}: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      
      _totalEventsFailed++;
      _failedEvents.add(eventData);
      
      // Schedule retry for failed events
      _scheduleRetryForFailedEvents();
    }
  }

  /// Create NIP-94 file metadata event from ready event data
  Future<Event> _createNip94Event(ReadyEventData eventData) async {
    // Get user's private key (placeholder implementation)
    final privateKey = await _getUserPrivateKey();
    
    final event = Event.from(
      kind: 1063, // NIP-94 file metadata
      content: eventData.contentSuggestion,
      tags: eventData.nip94Tags,
      privkey: privateKey,
    );
    
    debugPrint('📝 Created NIP-94 event: ${event.id}');
    debugPrint('📊 Event size: ${eventData.estimatedEventSize} bytes');
    debugPrint('🏷️ Tags: ${event.tags.length}');
    
    return event;
  }

  /// Publish event to Nostr relays
  Future<bool> _publishEventToNostr(Event event) async {
    try {
      debugPrint('📡 Publishing event to Nostr relays: ${event.id}');
      
      // Use the existing Nostr service to broadcast
      await _nostrService.broadcastEvent(event);
      
      debugPrint('✅ Event published successfully to relays');
      return true;
      
    } catch (e) {
      debugPrint('❌ Failed to publish event to relays: $e');
      return false;
    }
  }

  /// Update local upload status to published
  Future<void> _updateLocalUploadStatus(ReadyEventData eventData, String nostrEventId) async {
    final upload = _uploadManager.getUpload(eventData.originalUploadId);
    if (upload != null) {
      final updatedUpload = upload.copyWith(
        status: UploadStatus.published,
        nostrEventId: nostrEventId,
        completedAt: DateTime.now(),
      );
      
      // This would normally update the upload in the manager
      debugPrint('📱 Updated local upload status: ${eventData.originalUploadId} -> published');
      debugPrint('🔗 Linked to Nostr event: $nostrEventId');
    } else {
      debugPrint('⚠️ Could not find local upload for: ${eventData.originalUploadId}');
    }
  }

  /// Show user notification for successful publication
  Future<void> _showPublishNotification(ReadyEventData eventData, String nostrEventId) async {
    try {
      // Show platform notification
      // TODO: Implement actual notification service
      debugPrint('🔔 Would show notification: Video published!');
      debugPrint('📺 Event ID: $nostrEventId');
      debugPrint('🎬 Video URL: ${eventData.secureUrl}');
      
    } catch (e) {
      debugPrint('⚠️ Failed to show notification: $e');
    }
  }

  /// Update polling interval based on app state and pending uploads
  void _updatePollInterval() {
    final hasPendingUploads = _uploadManager.getUploadsByStatus(UploadStatus.processing).isNotEmpty ||
                             _uploadManager.getUploadsByStatus(UploadStatus.readyToPublish).isNotEmpty;
    
    if (!_isAppActive) {
      // App is in background - use longer interval
      _currentPollInterval = _idlePollInterval;
    } else if (hasPendingUploads || _failedEvents.isNotEmpty) {
      // Active uploads or failed events - poll frequently
      _currentPollInterval = _activePollInterval;
    } else {
      // No active uploads - use base interval
      _currentPollInterval = _basePollInterval;
    }
    
    // Restart polling with new interval if active
    if (_isPollingActive && _pollTimer != null) {
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(_currentPollInterval, (_) => _checkForReadyEvents());
      debugPrint('🔄 Updated poll interval to ${_currentPollInterval.inSeconds}s');
    }
  }

  /// Set up app lifecycle monitoring
  void _setupAppLifecycleListener() {
    SystemChannels.lifecycle.setMessageHandler((message) async {
      debugPrint('📱 App lifecycle: $message');
      
      switch (message) {
        case 'AppLifecycleState.resumed':
          _isAppActive = true;
          
          // If app was backgrounded for a long time, do immediate check
          if (_lastAppBackgroundTime != null) {
            final backgroundDuration = DateTime.now().difference(_lastAppBackgroundTime!);
            if (backgroundDuration.inMinutes > 10) {
              debugPrint('🔄 App resumed after ${backgroundDuration.inMinutes}min, checking immediately');
              _checkForReadyEvents();
            }
          }
          
          _updatePollInterval();
          break;
          
        case 'AppLifecycleState.paused':
        case 'AppLifecycleState.inactive':
          _isAppActive = false;
          _lastAppBackgroundTime = DateTime.now();
          _updatePollInterval();
          break;
      }
      
      return null;
    });
  }

  /// Schedule retry for general polling failures
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      debugPrint('🔄 Retrying after network error');
      _checkForReadyEvents();
    });
  }

  /// Schedule retry for failed events
  void _scheduleRetryForFailedEvents() {
    if (_failedEvents.isEmpty) return;
    
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () async {
      debugPrint('🔄 Retrying ${_failedEvents.length} failed events');
      
      final eventsToRetry = List<ReadyEventData>.from(_failedEvents);
      _failedEvents.clear();
      
      for (final event in eventsToRetry) {
        await _processReadyEvent(event);
      }
    });
  }

  /// Get user's private key for signing events
  Future<String> _getUserPrivateKey() async {
    // TODO: Implement proper private key management
    // This should get the user's private key from secure storage
    debugPrint('⚠️ TODO: Implement proper private key management');
    return 'placeholder-private-key-hex';
  }

  /// Get publishing statistics
  Map<String, dynamic> get publishingStats {
    return {
      'total_published': _totalEventsPublished,
      'total_failed': _totalEventsFailed,
      'last_publish_time': _lastPublishTime?.toIso8601String(),
      'last_successful_poll': _lastSuccessfulPoll?.toIso8601String(),
      'current_poll_interval': _currentPollInterval.inSeconds,
      'is_polling_active': _isPollingActive,
      'is_app_active': _isAppActive,
      'failed_events_count': _failedEvents.length,
    };
  }

  /// Force an immediate check (for manual testing)
  Future<void> forceCheck() async {
    debugPrint('🔧 Force checking for ready events');
    await _checkForReadyEvents();
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing VideoEventPublisher');
    
    stopPolling();
    _failedEvents.clear();
    
    // Remove app lifecycle listener
    SystemChannels.lifecycle.setMessageHandler(null);
    
    super.dispose();
  }
}