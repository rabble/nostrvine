// ABOUTME: Service for managing NIP-51 video curation sets and content discovery
// ABOUTME: Handles fetching, caching, and filtering videos based on curation sets

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/filter.dart';
import '../models/curation_set.dart';
import '../models/video_event.dart';
import '../services/nostr_service_interface.dart';
import '../services/video_event_service.dart';
import '../services/social_service.dart';
import '../services/default_content_service.dart';

class CurationService extends ChangeNotifier {
  final INostrService _nostrService;
  final VideoEventService _videoEventService;
  final SocialService _socialService;
  
  final Map<String, CurationSet> _curationSets = {};
  final Map<String, List<VideoEvent>> _setVideoCache = {};
  bool _isLoading = false;
  String? _error;

  CurationService({
    required INostrService nostrService,
    required VideoEventService videoEventService,
    required SocialService socialService,
  }) : _nostrService = nostrService,
       _videoEventService = videoEventService,
       _socialService = socialService {
    _initializeWithSampleData();
    
    // Listen for video updates and refresh curation data
    _videoEventService.addListener(_onVideoDataChanged);
  }

  /// Current curation sets
  List<CurationSet> get curationSets => _curationSets.values.toList();
  
  /// Loading state
  bool get isLoading => _isLoading;
  
  /// Error state
  String? get error => _error;

  /// Initialize with sample data while we're developing
  void _initializeWithSampleData() {
    _isLoading = true;
    
    // Load sample curation sets
    for (final sampleSet in SampleCurationSets.all) {
      _curationSets[sampleSet.id] = sampleSet;
    }
    
    // Populate with actual video data
    _populateSampleSets();
    
    _isLoading = false;
    notifyListeners();
  }

  /// Populate sample sets with real video data
  void _populateSampleSets() {
    final allVideos = _videoEventService.videoEvents;
    debugPrint('🎨 Populating curation sets with ${allVideos.length} available videos');
    
    // Always create Editor's Picks with default video, even if no other videos
    final editorsPicks = _selectEditorsPicksVideos(allVideos, allVideos);
    _setVideoCache[CurationSetType.editorsPicks.id] = editorsPicks;
    
    if (allVideos.isEmpty) {
      debugPrint('⚠️ No videos available, but added default video to Editor\'s Picks');
      // Set empty for other categories since we don't have data
      _setVideoCache[CurationSetType.trending.id] = [];
      _setVideoCache[CurationSetType.featured.id] = [];
      return;
    }

    // Sort videos by different criteria for different sets
    final sortedByTime = List<VideoEvent>.from(allVideos)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Sort by reaction count (using cached counts from social service)
    final sortedByReactions = List<VideoEvent>.from(allVideos)
      ..sort((a, b) {
        final aReactions = _socialService.getCachedLikeCount(a.id) ?? 0;
        final bReactions = _socialService.getCachedLikeCount(b.id) ?? 0;
        return bReactions.compareTo(aReactions);
      });

    // Update Editor's Picks with actual data (already created above with default video)
    final updatedEditorsPicks = _selectEditorsPicksVideos(sortedByTime, sortedByReactions);
    _setVideoCache[CurationSetType.editorsPicks.id] = updatedEditorsPicks;

    // Trending: Recent videos with engagement
    final trending = _selectTrendingVideos(sortedByTime, sortedByReactions);
    _setVideoCache[CurationSetType.trending.id] = trending;

    // Featured: Top quality videos
    final featured = _selectFeaturedVideos(sortedByReactions);
    _setVideoCache[CurationSetType.featured.id] = featured;

    debugPrint('🎨 Populated curation sets:');
    debugPrint('   Editor\'s Picks: ${updatedEditorsPicks.length} videos');
    debugPrint('   Trending: ${trending.length} videos');
    debugPrint('   Featured: ${featured.length} videos');
    debugPrint('   Total available videos: ${allVideos.length}');
  }

  /// Algorithm for selecting editor's picks
  List<VideoEvent> _selectEditorsPicksVideos(
    List<VideoEvent> byTime, 
    List<VideoEvent> byReactions,
  ) {
    final picks = <VideoEvent>[];
    final seenIds = <String>{};

    // Editor's Pick: Only show videos from the specified curator pubkey
    const editorPubkey = '70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082';
    
    debugPrint('🎯 Filtering Editor\'s Picks to only show videos from pubkey: $editorPubkey');
    
    // Get all videos from the editor's pubkey
    final editorVideos = _videoEventService.videoEvents
        .where((video) => video.pubkey == editorPubkey)
        .toList();
    
    debugPrint('📹 Found ${editorVideos.length} videos from editor\'s account');
    
    // Sort editor's videos by creation time (newest first)
    editorVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Add all editor's videos to picks
    for (final video in editorVideos) {
      debugPrint('📹 Editor\'s video ${video.id.substring(0, 8)}:');
      debugPrint('   - Title: ${video.title}');
      debugPrint('   - hasVideo: ${video.hasVideo}');
      debugPrint('   - videoUrl: ${video.videoUrl}');
      debugPrint('   - thumbnailUrl: ${video.effectiveThumbnailUrl}');
      picks.add(video);
      seenIds.add(video.id);
    }
    
    // If no videos from editor, show a message or default content
    if (picks.isEmpty) {
      debugPrint('⚠️ No videos found from editor\'s pubkey, checking for default video');
      // ALWAYS include the default video if no editor videos found
      final defaultVideo = DefaultContentService.createDefaultVideo();
      final hasDefaultVideo = _videoEventService.videoEvents.any((v) => v.id == defaultVideo.id);
      
      if (!hasDefaultVideo) {
        debugPrint('🎯 Adding default video "I\'m the bad guys" as fallback');
        picks.add(defaultVideo);
        seenIds.add(defaultVideo.id);
      } else {
        debugPrint('✅ Default video already exists in video events, using it as fallback');
        // Find and use the existing default video
        final existingDefault = _videoEventService.videoEvents.firstWhere((v) => v.id == defaultVideo.id);
        picks.add(existingDefault);
        seenIds.add(existingDefault.id);
      }
    }

    return picks;
  }

  /// Algorithm for selecting trending videos
  List<VideoEvent> _selectTrendingVideos(
    List<VideoEvent> byTime,
    List<VideoEvent> byReactions,
  ) {
    final trending = <VideoEvent>[];
    final seenIds = <String>{};

    // Recent videos from last 24 hours with engagement
    final cutoffTime = DateTime.now().millisecondsSinceEpoch - (24 * 60 * 60 * 1000);
    
    for (final video in byTime) {
      if (video.createdAt > cutoffTime && !seenIds.contains(video.id)) {
        trending.add(video);
        seenIds.add(video.id);
        if (trending.length >= 20) break;
      }
    }

    // If not enough recent videos, pad with popular ones
    if (trending.length < 10) {
      for (final video in byReactions) {
        if (!seenIds.contains(video.id)) {
          trending.add(video);
          seenIds.add(video.id);
          if (trending.length >= 15) break;
        }
      }
    }

    return trending;
  }

  /// Algorithm for selecting featured videos
  List<VideoEvent> _selectFeaturedVideos(List<VideoEvent> byReactions) {
    // Simply take top reacted videos
    return byReactions.take(12).toList();
  }

  /// Get videos for a specific curation set
  List<VideoEvent> getVideosForSet(String setId) {
    return _setVideoCache[setId] ?? [];
  }

  /// Get videos for a curation set type
  List<VideoEvent> getVideosForSetType(CurationSetType setType) {
    return getVideosForSet(setType.id);
  }

  /// Get a specific curation set
  CurationSet? getCurationSet(String setId) {
    return _curationSets[setId];
  }

  /// Get curation set by type
  CurationSet? getCurationSetByType(CurationSetType setType) {
    return getCurationSet(setType.id);
  }

  /// Refresh curation sets from Nostr
  Future<void> refreshCurationSets({List<String>? curatorPubkeys}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Implement actual Nostr queries for kind 30005 events
      // For now, just refresh sample data
      _populateSampleSets();
      
      _isLoading = false;
      notifyListeners();
      
    } catch (e) {
      _error = 'Failed to refresh curation sets: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error refreshing curation sets: $e');
    }
  }

  /// Subscribe to curation set updates
  Future<void> subscribeToCurationSets({List<String>? curatorPubkeys}) async {
    try {
      debugPrint('📡 Subscribing to kind 30005 curation sets...');
      
      // Query for video curation sets (kind 30005)
      final filter = {
        'kinds': [30005],
        'limit': 100,
      };
      
      // If specific curators provided, filter by them
      if (curatorPubkeys != null && curatorPubkeys.isNotEmpty) {
        filter['authors'] = curatorPubkeys;
      }
      
      // Subscribe to receive curation set events
      final eventStream = _nostrService.subscribeToEvents(
        filters: [Filter(
          kinds: [30005],
          authors: curatorPubkeys,
          limit: 100,
        )],
      );
      
      eventStream.listen(
        (event) {
          try {
            // Debug: Check what kind of event we're receiving
            if (event.kind != 30005) {
              debugPrint('⚠️ Received unexpected event kind ${event.kind} in curation subscription (expected 30005)');
              return;
            }
            
            final curationSet = CurationSet.fromNostrEvent(event);
            _curationSets[curationSet.id] = curationSet;
            debugPrint('📝 Received curation set: ${curationSet.title} (${curationSet.videoIds.length} videos)');
            
            // Update the video cache for this set
            _updateVideoCache(curationSet);
            notifyListeners();
            
          } catch (e) {
            debugPrint('⚠️ Failed to parse curation set from event: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ Error in curation set subscription: $error');
        },
      );
      
      // Also set up periodic refresh for sample data fallback
      Timer.periodic(const Duration(minutes: 5), (_) {
        if (!_isLoading) {
          _populateSampleSets();
          notifyListeners();
        }
      });
      
    } catch (e) {
      debugPrint('❌ Error subscribing to curation sets: $e');
    }
  }
  
  /// Update video cache for a specific curation set
  void _updateVideoCache(CurationSet curationSet) {
    final allVideos = _videoEventService.videoEvents;
    final setVideos = <VideoEvent>[];
    
    // Find videos matching the curation set's video IDs
    for (final videoId in curationSet.videoIds) {
      try {
        final video = allVideos.firstWhere(
          (v) => v.id == videoId,
        );
        setVideos.add(video);
      } catch (e) {
        // Video not found, skip it
      }
    }
    
    _setVideoCache[curationSet.id] = setVideos;
    debugPrint('🎬 Updated cache for ${curationSet.id}: ${setVideos.length} videos found');
  }

  /// Create a new curation set (for future implementation)
  Future<bool> createCurationSet({
    required String id,
    required String title,
    String? description,
    String? imageUrl,
    required List<String> videoIds,
  }) async {
    try {
      // TODO: Implement actual creation and publishing to Nostr
      debugPrint('🎨 Creating curation set: $title');
      return true;
    } catch (e) {
      debugPrint('❌ Error creating curation set: $e');
      return false;
    }
  }

  /// Check if videos need updating and refresh cache
  void refreshIfNeeded() {
    final currentVideoCount = _videoEventService.videoEvents.length;
    final cachedCount = _setVideoCache.values.fold<int>(
      0, (sum, videos) => sum + videos.length,
    );

    // Refresh if we have new videos
    if (currentVideoCount > cachedCount) {
      _populateSampleSets();
      notifyListeners();
    }
  }

  /// Handle video data changes
  void _onVideoDataChanged() {
    debugPrint('🔄 Video data changed, refreshing curation sets');
    _populateSampleSets();
    notifyListeners();
  }

  @override
  void dispose() {
    // Clean up any subscriptions
    _videoEventService.removeListener(_onVideoDataChanged);
    super.dispose();
  }
}