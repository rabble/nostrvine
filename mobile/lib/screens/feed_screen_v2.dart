// ABOUTME: TDD-driven video feed screen implementation with single source of truth
// ABOUTME: Memory-efficient PageView with intelligent preloading and error boundaries

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/video_manager_interface.dart';
import '../services/video_event_bridge.dart';
import '../services/user_profile_service.dart';
import '../widgets/video_feed_item.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';
import '../theme/vine_theme.dart';
import '../widgets/feed_transition_indicator.dart';
import 'search_screen.dart';
import '../utils/unified_logger.dart';

/// Feed context for filtering videos
enum FeedContext {
  general,        // All videos (default feed)
  hashtag,        // Videos from specific hashtag
  editorsPicks,   // Curated videos
  trending,       // Trending content
  userProfile,    // User's videos
}

/// Main video feed screen implementing TDD specifications
/// 
/// Key features:
/// - Single source of truth video management
/// - Memory-bounded operation (<500MB)
/// - Intelligent preloading around current position
/// - Error boundaries for individual videos
/// - Accessibility support
/// - Lifecycle management (pause on background, resume on foreground)
/// - Context-aware content filtering
class FeedScreenV2 extends StatefulWidget {
  final VideoEvent? startingVideo;
  final FeedContext context;
  final String? contextValue; // hashtag name, user pubkey, etc.
  
  const FeedScreenV2({
    super.key,
    this.startingVideo,
    this.context = FeedContext.general,
    this.contextValue,
  });

  @override
  State<FeedScreenV2> createState() => _FeedScreenV2State();
  
  /// Static method to pause videos - called from external components
  static void pauseVideos(GlobalKey<State<FeedScreenV2>> key) {
    final state = key.currentState;
    if (state is _FeedScreenV2State) {
      state.pauseVideos();
    }
  }
  
  /// Static method to resume videos - called from external components
  static void resumeVideos(GlobalKey<State<FeedScreenV2>> key) {
    final state = key.currentState;
    if (state is _FeedScreenV2State) {
      state.resumeVideos();
    }
  }
  
  /// Static method to get current video - called from external components
  static VideoEvent? getCurrentVideo(GlobalKey<State<FeedScreenV2>> key) {
    final state = key.currentState;
    if (state is _FeedScreenV2State) {
      return state.getCurrentVideo();
    }
    return null;
  }
  
  /// Static method to scroll to top and refresh - called from external components
  static void scrollToTopAndRefresh(GlobalKey<State<FeedScreenV2>> key) {
    final state = key.currentState;
    if (state is _FeedScreenV2State) {
      state.scrollToTopAndRefresh();
    }
  }
}

class _FeedScreenV2State extends State<FeedScreenV2> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  IVideoManager? _videoManager;
  VideoEventBridge? _videoEventBridge;
  UserProfileService? _userProfileService;
  int _currentIndex = 0;
  bool _isInitialized = false;
  StreamSubscription? _stateChangeSubscription;
  bool _isUserScrolling = false; // Track if user is actively scrolling
  // Removed _isLoadingMore as we no longer show loading indicator
  DateTime? _lastPaginationRequest; // Prevent too frequent pagination requests
  final Set<String> _profilesBeingFetched = {}; // Track profiles currently being fetched
  bool _isRefreshing = false; // Track if feed is currently refreshing

  @override
  bool get wantKeepAlive => true; // Keep state alive when using IndexedStack

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideoManager();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _stateChangeSubscription?.cancel();
    
    // Pause all videos when screen is disposed
    if (_isInitialized) {
      _pauseAllVideos();
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
        _pauseAllVideos();
        break;
      case AppLifecycleState.resumed:
        _resumeCurrentVideo();
        break;
      case AppLifecycleState.detached:
        _pauseAllVideos();
        break;
      case AppLifecycleState.hidden:
        _pauseAllVideos();
        break;
    }
  }

  void _initializeVideoManager() {
    try {
      _videoManager = Provider.of<IVideoManager>(context, listen: false);
      
      // Try to get the video event bridge for pagination
      try {
        _videoEventBridge = Provider.of<VideoEventBridge>(context, listen: false);
        Log.info('VideoEventBridge found for pagination support', name: 'FeedScreenV2', category: LogCategory.ui);
      } catch (e) {
        Log.warning('VideoEventBridge not found - pagination will be limited: $e', name: 'FeedScreenV2', category: LogCategory.ui);
      }
      
      // Try to get the user profile service for batch profile loading
      try {
        _userProfileService = Provider.of<UserProfileService>(context, listen: false);
        Log.info('UserProfileService found for profile batching', name: 'FeedScreenV2', category: LogCategory.ui);
      } catch (e) {
        Log.warning('UserProfileService not found - profile loading will be individual: $e', name: 'FeedScreenV2', category: LogCategory.ui);
      }
      
      _isInitialized = true;
      
      // Apply context filtering if needed
      _applyContextFiltering();
      
      // Set starting video position if provided
      _setInitialPosition();
      
      // Listen to state changes - no debouncing for video control operations
      _stateChangeSubscription = _videoManager!.stateChanges.listen((_) {
        // Don't rebuild during user scrolling to prevent index misalignment
        if (_isUserScrolling) {
          Log.warning('Skipping state update during user scrolling', name: 'FeedScreenV2', category: LogCategory.ui);
          return;
        }
        
        if (mounted) {
          setState(() {});
          
          // Aggressive preloading for first videos
          if (_videoManager!.videos.isNotEmpty && _currentIndex == 0) {
            Log.debug('Videos available - preloading around current index', name: 'FeedScreenV2', category: LogCategory.ui);
            // Start preloading immediately
            _videoManager!.preloadAroundIndex(_currentIndex);
            
            // Also preload the next video immediately for faster scrolling
            if (_videoManager!.videos.length > 1) {
              _videoManager!.preloadVideo(_videoManager!.videos[1].id);
            }
          }
        }
      });
      
      // Trigger initial preloading and profile batching
      if (_videoManager!.videos.isNotEmpty) {
        _videoManager!.preloadAroundIndex(0);
        _batchFetchProfilesAroundIndex(0);
      }
      
      setState(() {});
    } catch (e) {
      // Handle case where video manager is not provided
      Log.info('FeedScreenV2: VideoManager not found in context: $e', name: 'FeedScreenV2', category: LogCategory.ui);
      _videoManager = null;
      _isInitialized = true; // Mark as initialized even without manager
      setState(() {});
    }
  }

  void _onPageChanged(int index) {
    if (!_isInitialized || _videoManager == null) return;
    
    // Store the previous index before updating
    final previousIndex = _currentIndex;
    
    setState(() {
      _currentIndex = index;
    });
    
    // Don't try to preload or play the transition indicator
    if (_shouldShowTransitionAtIndex(index)) {
      // Pause any playing videos when showing transition
      _pauseAllVideos();
      return;
    }
    
    // Adjust index for video operations
    final videoIndex = _adjustVideoIndex(index);
    if (videoIndex < 0 || videoIndex >= _videoManager!.videos.length) {
      return;
    }
    
    // Trigger preloading around new position
    _videoManager!.preloadAroundIndex(videoIndex);
    
    // Batch fetch profiles for videos around current position
    _batchFetchProfilesAroundIndex(videoIndex);
    
    // Update video playback states with both old and new indices
    _updateVideoPlayback(videoIndex, previousIndex);
    
    // Discovery feed disabled - only show curated vines
    // Original code: trigger discovery loading when approaching end of primary videos
    // final primaryCount = _videoManager!.primaryVideoCount;
    // if (primaryCount > 0 && videoIndex >= primaryCount - 3 && _videoEventBridge != null) {
    //   _videoEventBridge!.triggerDiscoveryFeed();
    // }
  }

  void _updateVideoPlayback(int videoIndex, int previousPageIndex) {
    if (_videoManager == null) return;
    
    final videos = _videoManager!.videos;
    if (videoIndex < 0 || videoIndex >= videos.length) return;
    
    // Immediately pause ALL videos first to ensure clean state
    _pauseAllVideos();
    
    // Then play only the current video
    final currentVideo = videos[videoIndex];
    _playVideo(currentVideo.id);
  }

  void _playVideo(String videoId) {
    if (!_isInitialized || _videoManager == null) return;
    
    try {
      // The video will be played by the VideoFeedItem when it detects it's active
      // We just need to ensure the video is preloaded
      _videoManager!.preloadVideo(videoId);
      Log.debug('Requested play for video: ${videoId.substring(0, 8)}...', name: 'FeedScreenV2', category: LogCategory.ui);
    } catch (e) {
      Log.error('Error playing video $videoId: $e', name: 'FeedScreenV2', category: LogCategory.ui);
    }
  }


  void _pauseAllVideos() {
    if (!_isInitialized || _videoManager == null) return;
    
    try {
      _videoManager!.pauseAllVideos();
      Log.debug('Paused all videos in feed', name: 'FeedScreenV2', category: LogCategory.ui);
    } catch (e) {
      Log.error('Error pausing all videos: $e', name: 'FeedScreenV2', category: LogCategory.ui);
    }
  }

  /// Public method to pause videos from external sources (like navigation)
  void pauseVideos() {
    _pauseAllVideos();
  }
  
  /// Public method to resume videos from external sources (like navigation)
  void resumeVideos() {
    _resumeCurrentVideo();
    
    // Also trigger preloading around current position to reload videos that were stopped
    if (_videoManager != null && _videoManager!.videos.isNotEmpty) {
      _videoManager!.preloadAroundIndex(_currentIndex);
      Log.debug('▶️ Triggered preloading around index $_currentIndex when resuming feed', name: 'FeedScreenV2', category: LogCategory.ui);
    }
  }

  /// Apply context-specific filtering to video list
  void _applyContextFiltering() {
    if (_videoManager == null) return;
    
    switch (widget.context) {
      case FeedContext.general:
        // No filtering - show all videos
        break;
        
      case FeedContext.hashtag:
        if (widget.contextValue != null) {
          // Filter videos by hashtag
          _filterVideosByHashtag(widget.contextValue!);
        }
        break;
        
      case FeedContext.editorsPicks:
        // Filter to show only editor's picks (could be based on tags or metadata)
        _filterEditorsPicks();
        break;
        
      case FeedContext.trending:
        // Filter to show trending content
        _filterTrendingContent();
        break;
        
      case FeedContext.userProfile:
        if (widget.contextValue != null) {
          // Filter videos by user pubkey
          _filterVideosByUser(widget.contextValue!);
        }
        break;
    }
  }

  void _filterVideosByHashtag(String hashtag) {
    // TODO: Implement hashtag filtering
    // This would filter _videoManager!.videos to only include videos with the hashtag
    Log.verbose('Filtering by hashtag: $hashtag', name: 'FeedScreenV2', category: LogCategory.ui);
  }

  void _filterEditorsPicks() {
    // TODO: Implement editor's picks filtering
    // This would filter _videoManager!.videos to only include curated content
    debugPrint('⭐ Filtering for editor\'s picks');
  }

  void _filterTrendingContent() {
    // TODO: Implement trending content filtering
    // This would filter _videoManager!.videos to only include trending videos
    Log.debug('� Filtering for trending content', name: 'FeedScreenV2', category: LogCategory.ui);
  }

  void _filterVideosByUser(String pubkey) {
    // TODO: Implement user filtering
    // This would filter _videoManager!.videos to only include videos by specific user
    Log.verbose('Filtering by user: ${pubkey.substring(0, 8)}...', name: 'FeedScreenV2', category: LogCategory.ui);
  }

  /// Set initial video position if starting video is provided
  void _setInitialPosition() {
    if (widget.startingVideo == null || _videoManager == null) return;
    
    final videos = _videoManager!.videos;
    final startIndex = videos.indexWhere((video) => video.id == widget.startingVideo!.id);
    
    if (startIndex >= 0) {
      _currentIndex = startIndex;
      // Update page controller to start at the correct position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(startIndex);
        }
      });
      Log.debug('Starting feed at video ${startIndex + 1}/${videos.length}', name: 'FeedScreenV2', category: LogCategory.ui);
    }
  }

  void _resumeCurrentVideo() {
    if (!_isInitialized || _videoManager == null) return;
    
    final videos = _videoManager!.videos;
    if (_currentIndex < videos.length) {
      final currentVideo = videos[_currentIndex];
      
      // Check if video needs to be preloaded first
      final videoState = _videoManager!.getVideoState(currentVideo.id);
      if (videoState != null && videoState.loadingState == VideoLoadingState.notLoaded) {
        Log.debug('Current video needs reload, preloading: ${currentVideo.id.substring(0, 8)}...', name: 'FeedScreenV2', category: LogCategory.ui);
        _videoManager!.preloadVideo(currentVideo.id);
      }
      
      _playVideo(currentVideo.id);
    }
  }
  
  /// Get the currently displayed video
  VideoEvent? getCurrentVideo() {
    if (!_isInitialized || _videoManager == null) return null;
    
    final videos = _videoManager!.videos;
    if (_currentIndex >= 0 && _currentIndex < videos.length) {
      return videos[_currentIndex];
    }
    return null;
  }
  
  /// Scroll to top and refresh the feed
  void scrollToTopAndRefresh() {
    // Scroll to top
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
      
      // Trigger refresh after scroll completes
      Future.delayed(const Duration(milliseconds: 600), () {
        _handleRefresh();
      });
    } else {
      // If already at top or no clients, just refresh
      _handleRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'OpenVines',
          style: GoogleFonts.pacifico(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false, // AppBar handles top safe area
        bottom: false, // Let videos extend to bottom for full screen
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!_isInitialized) {
      return _buildLoadingState();
    }

    // If video manager is not available, show loading state
    if (_videoManager == null) {
      return _buildLoadingState();
    }

    // Use direct video manager access instead of Consumer when available
    final videos = _videoManager!.videos;
    
    if (videos.isEmpty) {
      return _buildEmptyState();
    }

    return _buildVideoFeed(videos);
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading videos...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Colors.white54,
          ),
          SizedBox(height: 16),
          Text(
            'No videos available',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Check your connection and try again',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoFeed(List<VideoEvent> videos) {
    return Semantics(
      label: 'Video feed',
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              // Track user scrolling to prevent rebuilds during interaction
              if (notification is ScrollStartNotification) {
                _isUserScrolling = true;
                Log.info('� User started scrolling', name: 'FeedScreenV2', category: LogCategory.ui);
                
                // Immediately pause all videos when scrolling starts
                _pauseAllVideos();
              } else if (notification is ScrollEndNotification) {
                _isUserScrolling = false;
                Log.info('� User stopped scrolling', name: 'FeedScreenV2', category: LogCategory.ui);
                
                // Check for pull-to-refresh at the top
                if (_currentIndex == 0 && notification.metrics.pixels < -50) {
                  _handleRefresh();
                }
                
                // Resume the current video after scrolling ends
                if (_videoManager != null && videos.isNotEmpty && _currentIndex < videos.length) {
                  final currentVideo = videos[_currentIndex];
                  _playVideo(currentVideo.id);
                }
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: _onPageChanged,
              itemCount: _calculateItemCount(videos.length),
              pageSnapping: true,
              itemBuilder: (context, index) {
                // Check if this is the transition indicator position
                if (_shouldShowTransitionAtIndex(index)) {
                  return FeedTransitionIndicator(
                    followingCount: _videoManager?.primaryVideoCount ?? 0,
                    discoveryCount: _videoManager?.discoveryVideoCount ?? 0,
                  );
                }
                
                // Adjust index to account for transition indicator
                final videoIndex = _adjustVideoIndex(index);
                
                // Bounds checking
                if (videoIndex < 0 || videoIndex >= videos.length) {
                  return _buildErrorItem('Index out of bounds');
                }

                final video = videos[videoIndex];
                final isActive = index == _currentIndex;

                // Check if we're near the end and should load more videos
                _checkForPagination(videoIndex, videos.length);

                // Error boundary for individual videos
                return _buildVideoItemWithErrorBoundary(video, isActive);
              },
            ),
          ),
          
          // Pull-to-refresh indicator overlay
          if (_isRefreshing && _currentIndex == 0)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Refreshing feed...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Calculate total item count including transition indicator if needed
  int _calculateItemCount(int videoCount) {
    if (_videoManager == null || videoCount == 0) return videoCount;
    
    // Check if we should show transition indicator
    final primaryCount = _videoManager!.primaryVideoCount;
    final discoveryCount = _videoManager!.discoveryVideoCount;
    
    // Only show transition if we have both primary and discovery videos
    if (primaryCount > 0 && discoveryCount > 0) {
      return videoCount + 1; // Add 1 for the transition indicator
    }
    
    return videoCount;
  }
  
  /// Check if the current index should show the transition indicator
  bool _shouldShowTransitionAtIndex(int index) {
    if (_videoManager == null) return false;
    
    final primaryCount = _videoManager!.primaryVideoCount;
    final discoveryCount = _videoManager!.discoveryVideoCount;
    
    // Only show transition if we have both types of videos
    if (primaryCount == 0 || discoveryCount == 0) return false;
    
    // Transition shows at the position after all primary videos
    return index == primaryCount;
  }
  
  /// Adjust video index to account for transition indicator
  int _adjustVideoIndex(int pageIndex) {
    if (_videoManager == null) return pageIndex;
    
    final primaryCount = _videoManager!.primaryVideoCount;
    final discoveryCount = _videoManager!.discoveryVideoCount;
    
    // If we don't have both types, no adjustment needed
    if (primaryCount == 0 || discoveryCount == 0) return pageIndex;
    
    // If index is before transition position, no adjustment
    if (pageIndex < primaryCount) return pageIndex;
    
    // If index is the transition position, this shouldn't be called
    // but return safe value anyway
    if (pageIndex == primaryCount) return -1;
    
    // If index is after transition, subtract 1 to account for indicator
    return pageIndex - 1;
  }

  Widget _buildVideoItemWithErrorBoundary(VideoEvent video, bool isActive) {
    try {
      return VideoFeedItem(
        video: video,
        isActive: isActive,
        onVideoError: (error) => _handleVideoError(video.id, error),
      );
    } catch (e) {
      // Error boundary - prevent one bad video from crashing entire feed
      Log.error('FeedScreenV2: Error creating video item ${video.id}: $e', name: 'FeedScreenV2', category: LogCategory.ui);
      return _buildErrorItem('Error loading video: ${video.title ?? video.id}');
    }
  }

  Widget _buildErrorItem(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go Back'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    // Trigger refresh
                    setState(() {});
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleVideoError(String videoId, String error) {
    Log.error('FeedScreenV2: Video error for $videoId: $error', name: 'FeedScreenV2', category: LogCategory.ui);
    // Error handling would be implemented here
    // For now, just log the error
  }

  /// Check if we're near the end of the video list and should load more content
  void _checkForPagination(int currentIndex, int totalVideos) {
    // Only trigger pagination if we have a video event bridge
    if (_videoEventBridge == null) return;
    
    // Check if we're near the end (within 5 videos)
    const paginationThreshold = 5;
    final isNearEnd = (totalVideos - currentIndex) <= paginationThreshold;
    
    if (!isNearEnd) return;
    
    // Prevent too frequent requests (minimum 3 seconds between requests)
    final now = DateTime.now();
    if (_lastPaginationRequest != null && 
        now.difference(_lastPaginationRequest!).inSeconds < 3) {
      return;
    }
    
    Log.debug('� Near end of feed (${totalVideos - currentIndex} videos left), loading more...', name: 'FeedScreenV2', category: LogCategory.ui);
    _loadMoreVideos();
  }
  
  /// Load more videos from the backend
  Future<void> _loadMoreVideos() async {
    _lastPaginationRequest = DateTime.now();
    
    try {
      await _videoEventBridge!.loadMoreEvents();
      Log.info('Successfully loaded more videos', name: 'FeedScreenV2', category: LogCategory.ui);
    } catch (e) {
      Log.error('Failed to load more videos: $e', name: 'FeedScreenV2', category: LogCategory.ui);
      // Show a subtle error indicator to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load more videos'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.grey[800],
          ),
        );
      }
    }
  }

  /// Handle pull-to-refresh functionality
  Future<void> _handleRefresh() async {
    if (_isRefreshing || _videoEventBridge == null) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      Log.info('🔄 Pull-to-refresh triggered - refreshing feed', name: 'FeedScreenV2', category: LogCategory.ui);
      await _videoEventBridge!.refreshFeed();
      Log.info('✅ Feed refresh completed', name: 'FeedScreenV2', category: LogCategory.ui);
    } catch (e) {
      Log.error('❌ Feed refresh failed: $e', name: 'FeedScreenV2', category: LogCategory.ui);
      
      // Show error feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to refresh feed'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }
  
  /// Batch fetch profiles for videos around the current position
  void _batchFetchProfilesAroundIndex(int currentIndex) {
    if (_userProfileService == null || _videoManager == null) return;
    
    final videos = _videoManager!.videos;
    if (videos.isEmpty) return;
    
    // Define window of videos to prefetch profiles for
    const preloadRadius = 3; // Preload profiles for ±3 videos
    final startIndex = (currentIndex - preloadRadius).clamp(0, videos.length - 1);
    final endIndex = (currentIndex + preloadRadius).clamp(0, videos.length - 1);
    
    // Collect unique pubkeys that need profile fetching
    final pubkeysToFetch = <String>{};
    
    for (int i = startIndex; i <= endIndex; i++) {
      final video = videos[i];
      
      // Only add pubkeys that aren't already cached or being fetched
      if (!_userProfileService!.hasProfile(video.pubkey) && 
          !_profilesBeingFetched.contains(video.pubkey)) {
        pubkeysToFetch.add(video.pubkey);
      }
    }
    
    if (pubkeysToFetch.isEmpty) return;
    
    // Mark profiles as being fetched to prevent duplicate requests
    _profilesBeingFetched.addAll(pubkeysToFetch);
    
    Log.debug('🔄 Batch fetching ${pubkeysToFetch.length} profiles for videos around index $currentIndex', 
        name: 'FeedScreenV2', category: LogCategory.ui);
    
    // Batch fetch profiles
    _userProfileService!.fetchMultipleProfiles(pubkeysToFetch.toList()).then((_) {
      // Remove from tracking set after fetching
      _profilesBeingFetched.removeAll(pubkeysToFetch);
    }).catchError((error) {
      Log.error('Failed to batch fetch profiles: $error', name: 'FeedScreenV2', category: LogCategory.ui);
      _profilesBeingFetched.removeAll(pubkeysToFetch);
    });
  }
  
  // Note: Keyboard navigation methods removed to avoid unused warnings
  // Would be implemented for accessibility support when needed
}

/// Error widget for video loading failures
class VideoErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onGoBack;

  const VideoErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Network error',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (onGoBack != null || onRetry != null) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onGoBack != null) ...[
                    ElevatedButton(
                      onPressed: onGoBack,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Go Back'),
                    ),
                    if (onRetry != null) const SizedBox(width: 16),
                  ],
                  if (onRetry != null)
                    ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}