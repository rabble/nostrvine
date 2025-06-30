// ABOUTME: Service to provide curated video feeds using the VideoManager pipeline
// ABOUTME: Bridges CurationService with VideoManager for consistent video playback

import 'package:flutter/foundation.dart';
import '../models/video_event.dart';
import '../models/curation_set.dart';
import 'curation_service.dart';
import 'video_manager_interface.dart';
import '../utils/unified_logger.dart';

/// Service that provides curated video collections through VideoManager
/// 
/// This bridges the CurationService (which provides curated content) with 
/// VideoManager (which handles video playback and lifecycle) to ensure
/// consistent video behavior across the app.
class ExploreVideoManager extends ChangeNotifier {
  final CurationService _curationService;
  final IVideoManager _videoManager;
  
  // Current collections available in VideoManager
  final Map<CurationSetType, List<VideoEvent>> _availableCollections = {};
  
  ExploreVideoManager({
    required CurationService curationService,
    required IVideoManager videoManager,
  }) : _curationService = curationService,
       _videoManager = videoManager {
    
    // Listen to curation service changes
    _curationService.addListener(_onCurationChanged);
    
    // Initialize with current content
    _initializeCollections();
  }
  
  /// Get videos for a specific curation type, ensuring they're in VideoManager
  List<VideoEvent> getVideosForType(CurationSetType type) {
    return _availableCollections[type] ?? [];
  }
  
  /// Check if videos are loading
  bool get isLoading => _curationService.isLoading;
  
  /// Get any error
  String? get error => _curationService.error;
  
  /// Initialize collections by ensuring curated videos are in VideoManager
  Future<void> _initializeCollections() async {
    await _syncAllCollections();
  }
  
  /// Handle changes from curation service
  void _onCurationChanged() {
    Log.verbose('CurationService changed, syncing collections...', name: 'ExploreVideoManager', category: LogCategory.system);
    _syncAllCollections();
  }
  
  /// Sync all curation collections to VideoManager
  Future<void> _syncAllCollections() async {
    // IMPORTANT: Do NOT add videos to VideoManager here!
    // VideoEventBridge already handles video additions from Nostr subscriptions.
    // ExploreVideoManager only needs to check which curated videos are available.
    
    
    // Sync each collection by checking what's available in VideoManager
    for (final type in CurationSetType.values) {
      await _syncCollectionInternal(type);
    }
    
    notifyListeners();
  }
  
  /// Internal sync method that doesn't notify listeners
  Future<void> _syncCollectionInternal(CurationSetType type) async {
    try {
      // Get videos from curation service
      final curatedVideos = _curationService.getVideosForSetType(type);
      
      // FIXED: Return curated videos directly instead of filtering through VideoManager
      // The CurationService already has access to all videos from VideoEventService
      _availableCollections[type] = curatedVideos;
      
      // Debug: Log what we're getting
      if (type == CurationSetType.editorsPicks) {
        Log.debug('ExploreVideoManager: Editor\'s Picks has ${curatedVideos.length} videos', name: 'ExploreVideoManager', category: LogCategory.system);
        if (curatedVideos.isNotEmpty) {
          final firstVideo = curatedVideos.first;
          Log.debug('  First video: ${firstVideo.title ?? firstVideo.id.substring(0, 8)} from pubkey ${firstVideo.pubkey.substring(0, 8)}', name: 'ExploreVideoManager', category: LogCategory.system);
        }
      }
      
      Log.verbose('Synced ${curatedVideos.length} videos for ${type.name}', name: 'ExploreVideoManager', category: LogCategory.system);
      
    } catch (e) {
      Log.error('Failed to sync collection ${type.name}: $e', name: 'ExploreVideoManager', category: LogCategory.system);
      _availableCollections[type] = [];
    }
  }
  
  /// Refresh collections from curation service
  Future<void> refreshCollections() async {
    await _curationService.refreshCurationSets();
    // _onCurationChanged will be called automatically
  }
  
  /// Start preloading videos for a specific collection
  void preloadCollection(CurationSetType type, {int startIndex = 0}) {
    final videos = _availableCollections[type];
    if (videos != null && videos.isNotEmpty && startIndex < videos.length) {
      // Use VideoManager's preloading for the collection
      final videoManager = _videoManager;
      
      // Preload around the starting position
      final preloadStart = (startIndex - 2).clamp(0, videos.length - 1);
      final preloadEnd = (startIndex + 3).clamp(0, videos.length);
      
      for (int i = preloadStart; i < preloadEnd; i++) {
        // Check if video exists in VideoManager before attempting to preload
        final videoState = videoManager.getVideoState(videos[i].id);
        if (videoState != null) {
          videoManager.preloadVideo(videos[i].id);
        } else {
          Log.warning('Skipping preload for video ${videos[i].id.substring(0, 8)}... - not in VideoManager', name: 'ExploreVideoManager', category: LogCategory.system);
        }
      }
      
      Log.debug('⚡ Preloading ${type.name} collection around index $startIndex', name: 'ExploreVideoManager', category: LogCategory.system);
    }
  }
  
  /// Pause all videos in collections (called when leaving explore)
  void pauseAllVideos() {
    try {
      _videoManager.pauseAllVideos();
      Log.debug('Paused all explore videos', name: 'ExploreVideoManager', category: LogCategory.system);
    } catch (e) {
      Log.error('Error pausing explore videos: $e', name: 'ExploreVideoManager', category: LogCategory.system);
    }
  }
  
  /// Get VideoManager for direct access
  IVideoManager get videoManager => _videoManager;
  
  @override
  void dispose() {
    _curationService.removeListener(_onCurationChanged);
    super.dispose();
  }
}