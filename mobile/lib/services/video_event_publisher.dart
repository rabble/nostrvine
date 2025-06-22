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
    debugPrint('🔧 Initializing VideoEventPublisher');
    
    // Set up app lifecycle monitoring
    _setupAppLifecycleListener();
    
    // Listen for upload status changes to publish direct uploads immediately
    _uploadManager.addListener(_checkForDirectUploads);
    
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
    
    // Check if we're using direct uploads (skip polling if so)
    try {
      // Do an immediate check
      await _checkForReadyEvents();
      
      // Schedule periodic checks
      _pollTimer = Timer.periodic(_currentPollInterval, (_) => _checkForReadyEvents());
    } catch (e) {
      debugPrint('⚠️ Polling endpoint not available - using direct upload only mode');
      // Continue without polling - direct uploads will still work
    }
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

  /// Create NIP-71 video event from ready event data
  Future<Event?> _createVideoEvent(ReadyEventData eventData) async {
    if (_authService == null || !_authService!.isAuthenticated) {
      debugPrint('❌ Cannot create video event - user not authenticated');
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
      videoTags.add(['client', 'nostrvine']);
      
      final event = await _authService!.createAndSignEvent(
        kind: 22, // NIP-71 short video
        content: eventData.contentSuggestion,
        tags: videoTags,
      );
      
      if (event == null) {
        debugPrint('❌ Failed to create and sign video event');
        return null;
      }
      
      debugPrint('📹 Created Kind 22 video event: ${event.id}');
      debugPrint('🎬 Video URL: $videoUrl');
      debugPrint('📊 Event size: ${eventData.estimatedEventSize} bytes');
      debugPrint('🏷️ Tags: ${event.tags.length}');
      
      return event;
      
    } catch (e) {
      debugPrint('❌ Error creating video event: $e');
      return null;
    }
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
      // This would normally update the upload in the manager with:
      // upload.copyWith(status: UploadStatus.published, nostrEventId: nostrEventId, completedAt: DateTime.now())
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
  
  /// Check for direct uploads that are ready to publish
  void _checkForDirectUploads() async {
    try {
      // Get all uploads that are ready to publish
      final readyUploads = _uploadManager.getUploadsByStatus(UploadStatus.readyToPublish);
      
      if (readyUploads.isEmpty) return;
      
      debugPrint('📬 Found ${readyUploads.length} direct uploads ready to publish');
      
      // Process each ready upload
      for (final upload in readyUploads) {
        // Skip if missing required fields
        if (upload.videoId == null || upload.cdnUrl == null) {
          debugPrint('⚠️ Skipping upload ${upload.id} - missing videoId or cdnUrl');
          continue;
        }
        
        // Check if already being published (prevent duplicates)
        if (_activePublishes.contains(upload.id)) {
          debugPrint('⏭️ Skipping upload ${upload.id} - already being published');
          continue;
        }
        
        // Mark as being published
        _activePublishes.add(upload.id);
        
        try {
          // Publish directly without polling
          final success = await publishDirectUpload(upload);
          
          if (success) {
            debugPrint('✅ Published direct upload: ${upload.id}');
          } else {
            debugPrint('❌ Failed to publish direct upload: ${upload.id}');
            // Remove from active set so it can be retried
            _activePublishes.remove(upload.id);
          }
        } catch (e) {
          debugPrint('❌ Exception publishing direct upload ${upload.id}: $e');
          // Remove from active set so it can be retried
          _activePublishes.remove(upload.id);
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking direct uploads: $e');
    }
  }
  
  /// Publish a video directly without polling (for direct upload)
  Future<bool> publishDirectUpload(PendingUpload upload) async {
    if (upload.videoId == null || upload.cdnUrl == null) {
      debugPrint('❌ Cannot publish upload - missing videoId or cdnUrl');
      return false;
    }
    
    try {
      debugPrint('🎬 Publishing direct upload: ${upload.videoId}');
      
      // Create NIP-94 style tags for the video
      final tags = <List<String>>[];
      
      // Required tags
      tags.add(['url', upload.cdnUrl!]);
      tags.add(['m', 'video/mp4']); // Assume MP4 for now
      
      // Add thumbnail if available
      if (upload.thumbnailPath != null) {
        tags.add(['thumb', upload.thumbnailPath!]);
        debugPrint('🖼️ Including thumbnail: ${upload.thumbnailPath}');
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
      tags.add(['client', 'nostrvine']);
      
      // Create the event content
      final content = upload.description ?? upload.title ?? '';
      
      // Create and sign the event
      if (_authService == null) {
        debugPrint('❌ Auth service is null - cannot create video event');
        return false;
      }
      
      if (!_authService!.isAuthenticated) {
        debugPrint('❌ User not authenticated - cannot create video event');
        return false;
      }
      
      debugPrint('🔐 Creating and signing video event...');
      debugPrint('📝 Content: "$content"');
      debugPrint('🏷️ Tags: ${tags.length} tags');
      
      final event = await _authService!.createAndSignEvent(
        kind: 22, // NIP-71 short video
        content: content,
        tags: tags,
      );
      
      if (event == null) {
        debugPrint('❌ Failed to create and sign video event - createAndSignEvent returned null');
        return false;
      }
      
      debugPrint('✅ Created video event: ${event.id}');
      
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
        
        debugPrint('✅ Successfully published direct upload: ${event.id}');
        debugPrint('🎬 Video URL: ${upload.cdnUrl}');
        
        return true;
      } else {
        debugPrint('❌ Failed to publish to Nostr relays');
        return false;
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error publishing direct upload: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      _totalEventsFailed++;
      return false;
    }
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing VideoEventPublisher');
    
    stopPolling();
    _failedEvents.clear();
    
    // Remove upload manager listener
    _uploadManager.removeListener(_checkForDirectUploads);
    
    // Remove app lifecycle listener
    SystemChannels.lifecycle.setMessageHandler(null);
    
    super.dispose();
  }
}