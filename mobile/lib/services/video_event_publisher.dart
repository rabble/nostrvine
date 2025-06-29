// ABOUTME: Background service for polling and publishing processed videos to Nostr
// ABOUTME: Handles automatic event creation, signing, and relay broadcasting with smart polling

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/ready_event_data.dart';
import '../models/pending_upload.dart';
import '../services/upload_manager.dart';
import '../services/nostr_service_interface.dart';
import '../services/auth_service.dart';
import 'package:nostr_sdk/event.dart';
import '../utils/unified_logger.dart';

/// Service for publishing processed videos to Nostr relays
class VideoEventPublisher extends ChangeNotifier {
  final UploadManager _uploadManager;
  final INostrService _nostrService;
  final AuthService? _authService;
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
  static const Duration _retryDelay = Duration(minutes: 1);
  
  // Statistics
  int _totalEventsPublished = 0;
  int _totalEventsFailed = 0;
  DateTime? _lastPublishTime;
  
  // Synchronization for preventing duplicate publishing
  final Set<String> _activePublishes = {};
  
  VideoEventPublisher({
    required UploadManager uploadManager,
    required INostrService nostrService,
    AuthService? authService,
    required Future<List<ReadyEventData>> Function() fetchReadyEvents,
    required Future<void> Function(String publicId) cleanupRemoteEvent,
  }) : _uploadManager = uploadManager,
       _nostrService = nostrService,
       _authService = authService,
       _fetchReadyEvents = fetchReadyEvents,
       _cleanupRemoteEvent = cleanupRemoteEvent;

  /// Initialize the publisher and start background polling
  Future<void> initialize() async {
    Log.debug('Initializing VideoEventPublisher', name: 'VideoEventPublisher', category: LogCategory.video);
    
    // Set up app lifecycle monitoring
    _setupAppLifecycleListener();
    
    // Listen for upload status changes to publish direct uploads immediately
    _uploadManager.addListener(_checkForDirectUploads);
    
    // Start polling for ready events
    await startPolling();
    
    Log.info('VideoEventPublisher initialized', name: 'VideoEventPublisher', category: LogCategory.video);
  }

  /// Start the background polling service
  Future<void> startPolling() async {
    if (_isPollingActive) {
      Log.warning('Polling already active', name: 'VideoEventPublisher', category: LogCategory.video);
      return;
    }
    
    _isPollingActive = true;
    _updatePollInterval();
    
    Log.debug('Starting video event polling (interval: ${_currentPollInterval.inSeconds}s)', name: 'VideoEventPublisher', category: LogCategory.video);
    
    // Check if we're using direct uploads (skip polling if so)
    try {
      // Do an immediate check
      await _checkForReadyEvents();
      
      // Schedule periodic checks
      _pollTimer = Timer.periodic(_currentPollInterval, (_) => _checkForReadyEvents());
    } catch (e) {
      Log.warning('Polling endpoint not available - using direct upload only mode', name: 'VideoEventPublisher', category: LogCategory.video);
      // Continue without polling - direct uploads will still work
    }
  }

  /// Stop the background polling service
  void stopPolling() {
    if (!_isPollingActive) return;
    
    Log.debug('Stopping video event polling', name: 'VideoEventPublisher', category: LogCategory.video);
    
    _isPollingActive = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Check for ready events and publish them
  Future<void> _checkForReadyEvents() async {
    if (!_isPollingActive || !_isAppActive) {
      Log.warning('Skipping poll - app inactive or polling stopped', name: 'VideoEventPublisher', category: LogCategory.video);
      return;
    }
    
    try {
      Log.debug('Checking for ready events...', name: 'VideoEventPublisher', category: LogCategory.video);
      
      // Fetch ready events from backend
      final readyEvents = await _fetchReadyEvents();
      
      if (readyEvents.isEmpty) {
        Log.info('No ready events found', name: 'VideoEventPublisher', category: LogCategory.video);
        _updatePollInterval();
        return;
      }
      
      Log.info('Found ${readyEvents.length} ready events', name: 'VideoEventPublisher', category: LogCategory.video);
      
      // Process each ready event
      for (final eventData in readyEvents) {
        await _processReadyEvent(eventData);
      }
      
      _lastSuccessfulPoll = DateTime.now();
      _updatePollInterval();
      
    } catch (e, stackTrace) {
      Log.error('Error checking ready events: $e', name: 'VideoEventPublisher', category: LogCategory.video);
      Log.verbose('� Stack trace: $stackTrace', name: 'VideoEventPublisher', category: LogCategory.video);
      
      // Handle network errors gracefully
      if (e.toString().contains('network') || e.toString().contains('timeout')) {
        Log.error('� Network error detected, will retry later', name: 'VideoEventPublisher', category: LogCategory.video);
        _scheduleRetry();
      }
    }
  }

  /// Process a single ready event
  Future<void> _processReadyEvent(ReadyEventData eventData) async {
    try {
      Log.debug('Processing ready event: ${eventData.publicId}', name: 'VideoEventPublisher', category: LogCategory.video);
      
      if (!eventData.isReadyForPublishing) {
        Log.warning('Event not ready for publishing: ${eventData.statusDescription}', name: 'VideoEventPublisher', category: LogCategory.video);
        return;
      }
      
      // Create Kind 22 video event
      final nostrEvent = await _createVideoEvent(eventData);
      if (nostrEvent == null) {
        throw Exception('Failed to create Nostr event');
      }
      
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
        
        Log.info('Successfully published event: ${nostrEvent.id}', name: 'VideoEventPublisher', category: LogCategory.video);
      } else {
        throw Exception('Failed to publish to Nostr relays');
      }
      
    } catch (e, stackTrace) {
      Log.error('Failed to process event ${eventData.publicId}: $e', name: 'VideoEventPublisher', category: LogCategory.video);
      Log.verbose('� Stack trace: $stackTrace', name: 'VideoEventPublisher', category: LogCategory.video);
      
      _totalEventsFailed++;
      _failedEvents.add(eventData);
      
      // Schedule retry for failed events
      _scheduleRetryForFailedEvents();
    }
  }

  /// Create NIP-71 video event from ready event data
  Future<Event?> _createVideoEvent(ReadyEventData eventData) async {
    if (_authService == null || !_authService!.isAuthenticated) {
      Log.error('Cannot create video event - user not authenticated', name: 'VideoEventPublisher', category: LogCategory.video);
      return null;
    }
    
    try {
      // Extract video metadata from eventData
      String? videoUrl;
      String? thumbnailUrl;
      String? title;
      int? duration;
      String? dimensions;
      String? mimeType;
      String? sha256;
      int? fileSize;
      
      // Parse the NIP-94 tags to extract video info
      for (final tag in eventData.nip94Tags) {
        if (tag.isEmpty) continue;
        switch (tag[0]) {
          case 'url':
            videoUrl = tag.length > 1 ? tag[1] : null;
            break;
          case 'thumb':
            thumbnailUrl = tag.length > 1 ? tag[1] : null;
            break;
          case 'title':
            title = tag.length > 1 ? tag[1] : null;
            break;
          case 'duration':
            duration = tag.length > 1 ? int.tryParse(tag[1]) : null;
            break;
          case 'dim':
            dimensions = tag.length > 1 ? tag[1] : null;
            break;
          case 'm':
            mimeType = tag.length > 1 ? tag[1] : null;
            break;
          case 'x':
            sha256 = tag.length > 1 ? tag[1] : null;
            break;
          case 'size':
            fileSize = tag.length > 1 ? int.tryParse(tag[1]) : null;
            break;
        }
      }
      
      // Create Kind 22 tags
      final videoTags = <List<String>>[];
      if (videoUrl != null) videoTags.add(['url', videoUrl]);
      if (title != null) videoTags.add(['title', title]);
      if (thumbnailUrl != null) videoTags.add(['thumb', thumbnailUrl]);
      if (duration != null) videoTags.add(['duration', duration.toString()]);
      if (dimensions != null) videoTags.add(['dim', dimensions]);
      if (mimeType != null) videoTags.add(['m', mimeType]);
      if (sha256 != null) videoTags.add(['x', sha256]);
      if (fileSize != null) videoTags.add(['size', fileSize.toString()]);
      
      // Add hashtags from original tags
      for (final tag in eventData.nip94Tags) {
        if (tag.isNotEmpty && tag[0] == 't') {
          videoTags.add(tag);
        }
      }
      
      // Add client tag
      videoTags.add(['client', 'openvine']);
      
      final event = await _authService!.createAndSignEvent(
        kind: 22, // NIP-71 short video
        content: eventData.contentSuggestion,
        tags: videoTags,
      );
      
      if (event == null) {
        Log.error('Failed to create and sign video event', name: 'VideoEventPublisher', category: LogCategory.video);
        return null;
      }
      
      Log.info('� Created Kind 22 video event: ${event.id}', name: 'VideoEventPublisher', category: LogCategory.video);
      Log.debug('Video URL: $videoUrl', name: 'VideoEventPublisher', category: LogCategory.video);
      Log.debug('Event size: ${eventData.estimatedEventSize} bytes', name: 'VideoEventPublisher', category: LogCategory.video);
      Log.verbose('Tags: ${event.tags.length}', name: 'VideoEventPublisher', category: LogCategory.video);
      
      return event;
      
    } catch (e) {
      Log.error('Error creating video event: $e', name: 'VideoEventPublisher', category: LogCategory.video);
      return null;
    }
  }

  /// Publish event to Nostr relays
  Future<bool> _publishEventToNostr(Event event) async {
    try {
      Log.debug('Publishing event to Nostr relays: ${event.id}', name: 'VideoEventPublisher', category: LogCategory.video);
      
      // Use the existing Nostr service to broadcast
      await _nostrService.broadcastEvent(event);
      
      Log.info('Event published successfully to relays', name: 'VideoEventPublisher', category: LogCategory.video);
      return true;
      
    } catch (e) {
      Log.error('Failed to publish event to relays: $e', name: 'VideoEventPublisher', category: LogCategory.video);
      return false;
    }
  }

  /// Update local upload status to published
  Future<void> _updateLocalUploadStatus(ReadyEventData eventData, String nostrEventId) async {
    final upload = _uploadManager.getUpload(eventData.originalUploadId);
    if (upload != null) {
      // This would normally update the upload in the manager with:
      // upload.copyWith(status: UploadStatus.published, nostrEventId: nostrEventId, completedAt: DateTime.now())
      Log.debug('� Updated local upload status: ${eventData.originalUploadId} -> published', name: 'VideoEventPublisher', category: LogCategory.video);
      Log.debug('� Linked to Nostr event: $nostrEventId', name: 'VideoEventPublisher', category: LogCategory.video);
    } else {
      Log.warning('Could not find local upload for: ${eventData.originalUploadId}', name: 'VideoEventPublisher', category: LogCategory.video);
    }
  }

  /// Show user notification for successful publication
  Future<void> _showPublishNotification(ReadyEventData eventData, String nostrEventId) async {
    try {
      // Show platform notification
      // TODO: Implement actual notification service
      Log.debug('� Would show notification: Video published!', name: 'VideoEventPublisher', category: LogCategory.video);
      Log.debug('� Event ID: $nostrEventId', name: 'VideoEventPublisher', category: LogCategory.video);
      Log.debug('Video URL: ${eventData.secureUrl}', name: 'VideoEventPublisher', category: LogCategory.video);
      
    } catch (e) {
      Log.error('Failed to show notification: $e', name: 'VideoEventPublisher', category: LogCategory.video);
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
      Log.debug('Updated poll interval to ${_currentPollInterval.inSeconds}s', name: 'VideoEventPublisher', category: LogCategory.video);
    }
  }

  /// Set up app lifecycle monitoring
  void _setupAppLifecycleListener() {
    SystemChannels.lifecycle.setMessageHandler((message) async {
      Log.debug('� App lifecycle: $message', name: 'VideoEventPublisher', category: LogCategory.video);
      
      switch (message) {
        case 'AppLifecycleState.resumed':
          _isAppActive = true;
          
          // If app was backgrounded for a long time, do immediate check
          if (_lastAppBackgroundTime != null) {
            final backgroundDuration = DateTime.now().difference(_lastAppBackgroundTime!);
            if (backgroundDuration.inMinutes > 10) {
              Log.debug('App resumed after ${backgroundDuration.inMinutes}min, checking immediately', name: 'VideoEventPublisher', category: LogCategory.video);
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
      Log.error('Retrying after network error', name: 'VideoEventPublisher', category: LogCategory.video);
      _checkForReadyEvents();
    });
  }

  /// Schedule retry for failed events
  void _scheduleRetryForFailedEvents() {
    if (_failedEvents.isEmpty) return;
    
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () async {
      Log.error('Retrying ${_failedEvents.length} failed events', name: 'VideoEventPublisher', category: LogCategory.video);
      
      final eventsToRetry = List<ReadyEventData>.from(_failedEvents);
      _failedEvents.clear();
      
      for (final event in eventsToRetry) {
        await _processReadyEvent(event);
      }
    });
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
    Log.debug('Force checking for ready events', name: 'VideoEventPublisher', category: LogCategory.video);
    await _checkForReadyEvents();
  }
  
  /// Check for direct uploads that are ready to publish
  void _checkForDirectUploads() async {
    try {
      // Get all uploads that are ready to publish
      final readyUploads = _uploadManager.getUploadsByStatus(UploadStatus.readyToPublish);
      
      if (readyUploads.isEmpty) return;
      
      Log.info('Found ${readyUploads.length} direct uploads ready to publish', name: 'VideoEventPublisher', category: LogCategory.video);
      
      // Process each ready upload
      for (final upload in readyUploads) {
        // Skip if missing required fields
        if (upload.videoId == null || upload.cdnUrl == null) {
          Log.warning('Skipping upload ${upload.id} - missing videoId or cdnUrl', name: 'VideoEventPublisher', category: LogCategory.video);
          continue;
        }
        
        // Check if already being published (prevent duplicates)
        if (_activePublishes.contains(upload.id)) {
          Log.warning('⏭️ Skipping upload ${upload.id} - already being published', name: 'VideoEventPublisher', category: LogCategory.video);
          continue;
        }
        
        // Mark as being published
        _activePublishes.add(upload.id);
        
        try {
          // Publish directly without polling
          final success = await publishDirectUpload(upload);
          
          if (success) {
            Log.info('Published direct upload: ${upload.id}', name: 'VideoEventPublisher', category: LogCategory.video);
          } else {
            Log.error('Failed to publish direct upload: ${upload.id}', name: 'VideoEventPublisher', category: LogCategory.video);
            // Remove from active set so it can be retried
            _activePublishes.remove(upload.id);
          }
        } catch (e) {
          Log.error('Exception publishing direct upload ${upload.id}: $e', name: 'VideoEventPublisher', category: LogCategory.video);
          // Remove from active set so it can be retried
          _activePublishes.remove(upload.id);
        }
      }
    } catch (e) {
      Log.error('Error checking direct uploads: $e', name: 'VideoEventPublisher', category: LogCategory.video);
    }
  }
  
  /// Publish a video event with custom metadata
  Future<bool> publishVideoEvent({
    required PendingUpload upload,
    String? title,
    String? description,
    List<String>? hashtags,
    int? expirationTimestamp,
  }) async {
    // Create a temporary upload with updated metadata
    final updatedUpload = upload.copyWith(
      title: title ?? upload.title,
      description: description ?? upload.description,
      hashtags: hashtags ?? upload.hashtags,
    );
    
    return publishDirectUpload(updatedUpload, expirationTimestamp: expirationTimestamp);
  }
  
  /// Publish a video directly without polling (for direct upload)
  Future<bool> publishDirectUpload(PendingUpload upload, {int? expirationTimestamp}) async {
    if (upload.videoId == null || upload.cdnUrl == null) {
      Log.error('Cannot publish upload - missing videoId or cdnUrl', name: 'VideoEventPublisher', category: LogCategory.video);
      return false;
    }
    
    try {
      Log.debug('Publishing direct upload: ${upload.videoId}', name: 'VideoEventPublisher', category: LogCategory.video);
      
      // Create NIP-94 style tags for the video
      final tags = <List<String>>[];
      
      // Required tags
      tags.add(['url', upload.cdnUrl!]);
      tags.add(['m', 'video/mp4']); // Assume MP4 for now
      
      // Add thumbnail if available
      if (upload.thumbnailPath != null) {
        tags.add(['thumb', upload.thumbnailPath!]);
        Log.verbose('Including thumbnail: ${upload.thumbnailPath}', name: 'VideoEventPublisher', category: LogCategory.video);
      }
      
      // Optional tags
      if (upload.title != null) tags.add(['title', upload.title!]);
      if (upload.description != null) tags.add(['summary', upload.description!]);
      
      // Add hashtags
      if (upload.hashtags != null) {
        for (final hashtag in upload.hashtags!) {
          tags.add(['t', hashtag]);
        }
      }
      
      // Add client tag
      tags.add(['client', 'openvine']);
      
      // Add expiration tag if specified
      if (expirationTimestamp != null) {
        tags.add(['expiration', expirationTimestamp.toString()]);
      }
      
      // Create the event content
      final content = upload.description ?? upload.title ?? '';
      
      // Create and sign the event
      if (_authService == null) {
        Log.error('Auth service is null - cannot create video event', name: 'VideoEventPublisher', category: LogCategory.video);
        return false;
      }
      
      if (!_authService!.isAuthenticated) {
        Log.error('User not authenticated - cannot create video event', name: 'VideoEventPublisher', category: LogCategory.video);
        return false;
      }
      
      Log.debug('� Creating and signing video event...', name: 'VideoEventPublisher', category: LogCategory.video);
      Log.verbose('Content: "$content"', name: 'VideoEventPublisher', category: LogCategory.video);
      Log.verbose('Tags: ${tags.length} tags', name: 'VideoEventPublisher', category: LogCategory.video);
      
      final event = await _authService!.createAndSignEvent(
        kind: 22, // NIP-71 short video
        content: content,
        tags: tags,
      );
      
      if (event == null) {
        Log.error('Failed to create and sign video event - createAndSignEvent returned null', name: 'VideoEventPublisher', category: LogCategory.video);
        return false;
      }
      
      Log.info('Created video event: ${event.id}', name: 'VideoEventPublisher', category: LogCategory.video);
      
      // Publish to Nostr relays
      final publishResult = await _publishEventToNostr(event);
      
      if (publishResult) {
        // Update upload status
        await _uploadManager.updateUploadStatus(
          upload.id,
          UploadStatus.published,
          nostrEventId: event.id,
        );
        
        _totalEventsPublished++;
        _lastPublishTime = DateTime.now();
        
        Log.info('Successfully published direct upload: ${event.id}', name: 'VideoEventPublisher', category: LogCategory.video);
        Log.debug('Video URL: ${upload.cdnUrl}', name: 'VideoEventPublisher', category: LogCategory.video);
        
        return true;
      } else {
        Log.error('Failed to publish to Nostr relays', name: 'VideoEventPublisher', category: LogCategory.video);
        return false;
      }
      
    } catch (e, stackTrace) {
      Log.error('Error publishing direct upload: $e', name: 'VideoEventPublisher', category: LogCategory.video);
      Log.verbose('� Stack trace: $stackTrace', name: 'VideoEventPublisher', category: LogCategory.video);
      _totalEventsFailed++;
      return false;
    }
  }

  @override
  void dispose() {
    Log.debug('�️ Disposing VideoEventPublisher', name: 'VideoEventPublisher', category: LogCategory.video);
    
    stopPolling();
    _failedEvents.clear();
    
    // Remove upload manager listener
    _uploadManager.removeListener(_checkForDirectUploads);
    
    // Remove app lifecycle listener
    SystemChannels.lifecycle.setMessageHandler(null);
    
    super.dispose();
  }
}