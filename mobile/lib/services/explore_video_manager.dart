// ABOUTME: Service to provide curated video feeds using the VideoManager pipeline
// ABOUTME: Bridges CurationService with VideoManager for consistent video playback

import 'package:flutter/foundation.dart';
import '../models/video_event.dart';
import '../models/curation_set.dart';
import 'curation_service.dart';
import 'video_manager_interface.dart';

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
    debugPrint('🎨 CurationService changed, syncing collections...');
    _syncAllCollections();
  }
  
  /// Sync all curation collections to VideoManager
  Future<void> _syncAllCollections() async {
    for (final type in CurationSetType.values) {
      await _syncCollection(type);
    }
    notifyListeners();
  }
  
  /// Sync a specific collection to VideoManager
  Future<void> _syncCollection(CurationSetType type) async {
    try {
      // Get videos from curation service
      final curatedVideos = _curationService.getVideosForSetType(type);
      
      if (curatedVideos.isEmpty) {
        _availableCollections[type] = [];
        return;
      }
      
      // Ensure all videos are registered with VideoManager
      final availableVideos = <VideoEvent>[];
      
      for (final video in curatedVideos) {
        try {
          // Check if video is already in VideoManager
          final videoState = _videoManager.getVideoState(video.id);
          
          if (videoState == null) {
            // Add video to VideoManager
            await _videoManager.addVideoEvent(video);
            debugPrint('📋 Added curated video ${video.id.substring(0, 8)}... to VideoManager');
          }
          
          // Video is now available
          availableVideos.add(video);
          
        } catch (e) {
          debugPrint('⚠️ Failed to register curated video ${video.id}: $e');
          // Continue with other videos
        }
      }
      
      _availableCollections[type] = availableVideos;
      debugPrint('✅ Synced ${availableVideos.length} videos for ${type.name}');
      
    } catch (e) {
      debugPrint('❌ Failed to sync collection ${type.name}: $e');
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
        videoManager.preloadVideo(videos[i].id);
      }
      
      debugPrint('⚡ Preloading ${type.name} collection around index $startIndex');
    }
  }
  
  /// Pause all videos in collections (called when leaving explore)
  void pauseAllVideos() {
    try {
      _videoManager.pauseAllVideos();
      debugPrint('⏸️ Paused all explore videos');
    } catch (e) {
      debugPrint('⚠️ Error pausing explore videos: $e');
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