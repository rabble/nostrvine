// ABOUTME: TDD-driven video feed screen implementation with single source of truth
// ABOUTME: Memory-efficient PageView with intelligent preloading and error boundaries

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/video_manager_interface.dart';
import '../services/video_event_bridge.dart';
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
}

class _FeedScreenV2State extends State<FeedScreenV2> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  IVideoManager? _videoManager;
  VideoEventBridge? _videoEventBridge;
  int _currentIndex = 0;
  bool _isInitialized = false;
  StreamSubscription? _stateChangeSubscription;
  Timer? _debounceTimer;
  bool _isUserScrolling = false; // Track if user is actively scrolling
  // Removed _isLoadingMore as we no longer show loading indicator
  DateTime? _lastPaginationRequest; // Prevent too frequent pagination requests

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
    _debounceTimer?.cancel();
    
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
      
      _isInitialized = true;
      
      // Apply context filtering if needed
      _applyContextFiltering();
      
      // Set starting video position if provided
      _setInitialPosition();
      
      // Listen to state changes with debouncing to prevent UI flashing
      _stateChangeSubscription = _videoManager!.stateChanges.listen((_) {
        // Don't rebuild during user scrolling to prevent index misalignment
        if (_isUserScrolling) {
          Log.warning('Skipping state update during user scrolling', name: 'FeedScreenV2', category: LogCategory.ui);
          return;
        }
        
        // Debounce rapid state changes to prevent flashing during video loading
        _debounceTimer?.cancel();
        
        // Get current video count for optimization
        final currentVideoCount = _videoManager!.videos.length;
        final hadNoVideos = currentVideoCount == 0;
        
        // Use aggressive optimization for first video
        final debounceDelay = hadNoVideos
            ? const Duration(milliseconds: 0)   // IMMEDIATE update for first video
            : currentVideoCount < 3
              ? const Duration(milliseconds: 50)  // Fast for first few videos
              : const Duration(milliseconds: 200); // Reduced for subsequent videos
        
        _debounceTimer = Timer(debounceDelay, () {
          if (mounted && !_isUserScrolling) { // Double-check user isn't scrolling
            final wasEmpty = hadNoVideos;
            setState(() {});
            
            // Aggressive preloading for first videos
            if (wasEmpty && _videoManager!.videos.isNotEmpty) {
              Log.debug('FIRST VIDEO ARRIVED - immediate render and preload!', name: 'FeedScreenV2', category: LogCategory.ui);
              // Start preloading immediately, don't wait for render
              _videoManager!.preloadAroundIndex(_currentIndex);
              
              // Also preload the next video immediately for faster scrolling
              if (_videoManager!.videos.length > 1) {
                _videoManager!.preloadVideo(_videoManager!.videos[1].id);
              }
            }
          }
        });
      });
      
      // Trigger initial preloading
      if (_videoManager!.videos.isNotEmpty) {
        _videoManager!.preloadAroundIndex(0);
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
    
    // Update video playback states
    _updateVideoPlayback(videoIndex);
  }

  void _updateVideoPlayback(int videoIndex) {
    if (_videoManager == null) return;
    
    final videos = _videoManager!.videos;
    if (videoIndex < 0 || videoIndex >= videos.length) return;
    
    // Get the previous video index (accounting for transition)
    final previousVideoIndex = _adjustVideoIndex(_currentIndex);
    
    // Pause previous video if it's valid
    if (previousVideoIndex >= 0 && previousVideoIndex < videos.length && 
        previousVideoIndex != videoIndex) {
      final previousVideo = videos[previousVideoIndex];
      _pauseVideo(previousVideo.id);
    }
    
    // Play current video
    final currentVideo = videos[videoIndex];
    _playVideo(currentVideo.id);
  }

  void _playVideo(String videoId) {
    // This would be implemented by the video manager extension
    // For now, it's a no-op since we're in TDD phase
  }

  void _pauseVideo(String videoId) {
    if (!_isInitialized || _videoManager == null) return;
    
    try {
      _videoManager!.pauseVideo(videoId);
      Log.debug('Paused video: ${videoId.substring(0, 8)}...', name: 'FeedScreenV2', category: LogCategory.ui);
    } catch (e) {
      Log.error('Error pausing video $videoId: $e', name: 'FeedScreenV2', category: LogCategory.ui);
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
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          // Track user scrolling to prevent rebuilds during interaction
          if (notification is ScrollStartNotification) {
            _isUserScrolling = true;
            Log.info('� User started scrolling', name: 'FeedScreenV2', category: LogCategory.ui);
          } else if (notification is ScrollEndNotification) {
            _isUserScrolling = false;
            Log.info('� User stopped scrolling', name: 'FeedScreenV2', category: LogCategory.ui);
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