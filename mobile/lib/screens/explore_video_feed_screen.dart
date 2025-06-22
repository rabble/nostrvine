// ABOUTME: Explore video feed using VideoManager pipeline for consistent playback
// ABOUTME: Shows curated videos with same performance as main feed

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/explore_video_manager.dart';
import '../services/video_manager_interface.dart';
import '../widgets/video_feed_item.dart';
import '../models/video_event.dart';
import '../models/curation_set.dart';

/// Video feed screen for explore content using VideoManager pipeline
/// 
/// This provides the same performance and video management as the main feed
/// but displays curated content from the explore service.
class ExploreVideoFeedScreen extends StatefulWidget {
  final CurationSetType curationSetType;
  final String title;
  final VideoEvent? startingVideo;
  final int startingIndex;
  
  const ExploreVideoFeedScreen({
    super.key,
    required this.curationSetType,
    required this.title,
    this.startingVideo,
    this.startingIndex = 0,
  });

  @override
  State<ExploreVideoFeedScreen> createState() => _ExploreVideoFeedScreenState();
}

class _ExploreVideoFeedScreenState extends State<ExploreVideoFeedScreen> 
    with WidgetsBindingObserver {
  late PageController _pageController;
  ExploreVideoManager? _exploreVideoManager;
  IVideoManager? _videoManager;
  List<VideoEvent> _videos = [];
  int _currentIndex = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.startingIndex);
    _currentIndex = widget.startingIndex;
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    
    // Pause all videos when leaving
    if (_isInitialized && _exploreVideoManager != null) {
      _exploreVideoManager!.pauseAllVideos();
    }
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (!_isInitialized) return;
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _pauseAllVideos();
        break;
      case AppLifecycleState.resumed:
        _resumeCurrentVideo();
        break;
      case AppLifecycleState.detached:
        _pauseAllVideos();
        break;
    }
  }

  void _initializeServices() {
    try {
      _exploreVideoManager = Provider.of<ExploreVideoManager>(context, listen: false);
      _videoManager = _exploreVideoManager!.videoManager;
      
      // Get videos for this curation type
      _videos = _exploreVideoManager!.getVideosForType(widget.curationSetType);
      
      // Start preloading around initial position
      if (_videos.isNotEmpty) {
        _exploreVideoManager!.preloadCollection(widget.curationSetType, startIndex: _currentIndex);
      }
      
      // Listen for changes
      _exploreVideoManager!.addListener(_onExploreVideosChanged);
      
      _isInitialized = true;
      setState(() {});
      
      debugPrint('✅ ExploreVideoFeedScreen initialized with ${_videos.length} videos');
      
    } catch (e) {
      debugPrint('❌ Failed to initialize ExploreVideoFeedScreen: $e');
      _isInitialized = true; // Mark as initialized to show error state
      setState(() {});
    }
  }

  void _onExploreVideosChanged() {
    if (!mounted) return;
    
    final newVideos = _exploreVideoManager!.getVideosForType(widget.curationSetType);
    
    if (newVideos.length != _videos.length) {
      setState(() {
        _videos = newVideos;
      });
      
      debugPrint('📺 Explore videos updated: ${_videos.length} videos available');
    }
  }

  void _onPageChanged(int index) {
    if (!_isInitialized || _videoManager == null) return;
    
    setState(() {
      _currentIndex = index;
    });
    
    // Use VideoManager's preloading around new position
    _exploreVideoManager!.preloadCollection(widget.curationSetType, startIndex: index);
    
    // Update video playback states
    _updateVideoPlayback(index);
  }

  void _updateVideoPlayback(int newIndex) {
    if (_videoManager == null || _videos.isEmpty) return;
    
    if (newIndex < 0 || newIndex >= _videos.length) return;
    
    // Pause previous video
    if (_currentIndex != newIndex && _currentIndex < _videos.length) {
      final previousVideo = _videos[_currentIndex];
      _pauseVideo(previousVideo.id);
    }
    
    // Current video will auto-play via VideoFeedItem
  }

  void _pauseVideo(String videoId) {
    if (!_isInitialized || _videoManager == null) return;
    
    try {
      _videoManager!.pauseVideo(videoId);
      debugPrint('⏸️ Paused explore video: ${videoId.substring(0, 8)}...');
    } catch (e) {
      debugPrint('⚠️ Error pausing explore video $videoId: $e');
    }
  }

  void _pauseAllVideos() {
    if (_exploreVideoManager != null) {
      _exploreVideoManager!.pauseAllVideos();
    }
  }

  void _resumeCurrentVideo() {
    // VideoFeedItem will handle resuming when it becomes active
    if (mounted) {
      setState(() {}); // Trigger rebuild to resume current video
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_exploreVideoManager?.isLoading == true && _videos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading curated videos...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${widget.title.toLowerCase()} available',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check back later for new content',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Use same PageView structure as main feed
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: _onPageChanged,
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        final isActive = index == _currentIndex;
        
        return VideoFeedItem(
          video: video,
          isActive: isActive,
          onVideoError: (videoId) {
            debugPrint('⚠️ Error in explore video $videoId');
          },
        );
      },
    );
  }
}