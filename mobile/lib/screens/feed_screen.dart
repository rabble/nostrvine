import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/video_feed_provider.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';
import '../widgets/video_feed_item.dart';
import '../services/connection_status_service.dart';
import '../services/seen_videos_service.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../services/social_service.dart';
import 'profile_screen.dart';
import '../theme/vine_theme.dart';
import '../utils/video_system_debugger.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _lastLoggedVideoCount = -1;
  int _lastRebuildTime = 0;
  int _rebuildCount = 0;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize video feed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFeed();
    });
  }
  
  void _initializeFeed() async {
    final provider = context.read<VideoFeedProvider>();
    if (!provider.isInitialized) {
      await provider.initialize();
      // Videos will start appearing automatically as they become ready
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Removed verbose logging to reduce noise
    return VideoSystemDebugOverlay(
      child: GestureDetector(
        // Debug gesture: Triple-tap top-right corner to toggle debug overlay
        onTapDown: (details) {
          if (kDebugMode) {
            final screenWidth = MediaQuery.of(context).size.width;
            final tapX = details.globalPosition.dx;
            if (tapX > screenWidth * 0.85) { // Top-right 15% of screen
              _handleDebugTap();
            }
          }
        },
        child: Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          // Main video content
          Consumer<VideoFeedProvider>(
            builder: (context, provider, child) {
              // Debug: Track rebuild frequency
              final now = DateTime.now().millisecondsSinceEpoch;
              _rebuildCount++;
              
              if (now - _lastRebuildTime < 100) { // If rebuilding faster than 100ms
                if (_rebuildCount % 10 == 0) { // Only log every 10th rapid rebuild
                  debugPrint('⚠️ RAPID REBUILDS: #$_rebuildCount in ${now - _lastRebuildTime}ms');
                }
              }
              _lastRebuildTime = now;
              
              // Only log when video count changes to reduce noise
              if (_lastLoggedVideoCount != provider.readyVideos.length) {
                _lastLoggedVideoCount = provider.readyVideos.length;
                debugPrint('📺 FeedScreen Consumer: readyVideos changed to ${provider.readyVideos.length}');
              }
          
          if (!provider.isInitialized && provider.isLoading) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.8,
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 24),
                        Text(
                          'Connecting to Nostr relays...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Setting up your decentralized video feed',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          
          if (provider.error != null) {
            return Consumer<ConnectionStatusService>(
              builder: (context, connectionService, child) {
                final isOffline = !connectionService.isOnline;
                
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.8,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isOffline ? Icons.wifi_off : Icons.error_outline, 
                              color: isOffline ? Colors.orange : Colors.red, 
                              size: 64
                            ),
                            const SizedBox(height: 24),
                            Text(
                              isOffline ? 'No Internet Connection' : 'Error: ${provider.error}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isOffline 
                                ? 'Check your internet connection and try again'
                                : 'Unable to load video feed',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: isOffline ? null : () => provider.retry(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              ),
                              child: Text(isOffline ? 'Waiting for connection...' : 'Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }
          
          if (provider.videoEvents.isEmpty) {
            return Consumer<ConnectionStatusService>(
              builder: (context, connectionService, child) {
                final isOffline = !connectionService.isOnline;
                
                return RefreshIndicator(
                  onRefresh: isOffline ? () async {} : () => provider.refreshFeed(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Center(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.8,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isOffline ? Icons.wifi_off : Icons.video_library_outlined, 
                                color: Colors.white54, 
                                size: 64
                              ),
                              const SizedBox(height: 24),
                              Text(
                                isOffline ? 'Offline' : 'Finding videos...',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isOffline 
                                  ? 'Connect to the internet to load videos'
                                  : 'Searching Nostr relays for video content',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (!isOffline) ...[
                                const SizedBox(height: 20),
                                const CircularProgressIndicator(
                                  color: Colors.white54,
                                  strokeWidth: 2,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }
          
          // Removed redundant logging since we already track video count changes above
          
          // Wrap PageView with desktop-friendly scroll behavior
          final pageView = PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            // Enable desktop-friendly scrolling for macOS
            physics: kIsWeb || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux
                ? const AlwaysScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            itemCount: provider.videoEvents.isNotEmpty ? provider.videoEvents.length : provider.readyVideos.length, // Allow swiping through all videos
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              
              final allVideoCount = provider.videoEvents.length;
              final readyVideoCount = provider.readyVideos.length;
              final isSubscribed = provider.isSubscribed;
              final canLoadMore = provider.canLoadMore;
              
              debugPrint('📱 Page changed to video $index/$allVideoCount (ready: $readyVideoCount, subscribed: $isSubscribed, canLoadMore: $canLoadMore)');
              
              if (allVideoCount > 0) {
                // Auto-skip permanently failed videos due to server config errors
                _handleAutoSkipIfNeeded(index, provider);
                
                // Load more when getting close to the end of all videos
                if (index >= allVideoCount - 3) {
                  debugPrint('📱 Near end of videos ($index/$allVideoCount), loading more...');
                  if (canLoadMore) {
                    provider.loadMoreEvents();
                  } else {
                    debugPrint('⚠️ Cannot load more events - subscription may have stopped');
                  }
                }
                // Preload videos around current index - this will trigger preloading for videos that aren't ready yet
                provider.preloadVideosAroundIndex(index);
              } else {
                debugPrint('⚠️ No videos available for preloading');
              }
            },
            itemBuilder: (context, index) {
              final allVideoCount = provider.videoEvents.length;
              
              if (allVideoCount == 0 || index >= allVideoCount) {
                debugPrint('⚠️ Invalid video index: $index/$allVideoCount');
                return const SizedBox.shrink();
              }
              
              // Use all videos, but check if they're ready for playback
              final videoEvent = provider.videoEvents[index];
              final isVideoReady = provider.getVideoState(videoEvent.id)?.isReady == true;
              // TEMPORARILY DISABLED: Reduce debug spam during infinite rebuild investigation
              // if (index == _currentPage) {
              //   debugPrint('📱 Building VideoFeedItem for ${videoEvent.id.substring(0, 8)} at index $index (active: true)');
              // }
              
              
              return SizedBox(
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                child: Consumer<SeenVideosService>(
                  builder: (context, seenVideosService, child) {
                    // Show loading state for videos that aren't ready yet
                    if (!isVideoReady) {
                      return Container(
                        height: MediaQuery.of(context).size.height,
                        width: MediaQuery.of(context).size.width,
                        color: Colors.black,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                'Loading video...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    return VideoFeedItem(
                      videoEvent: videoEvent,
                      isActive: index == _currentPage,
                      videoCacheService: provider.videoCacheService, // Legacy compatibility
                      videoController: provider.getController(videoEvent.id), // New: Direct controller from VideoManager
                      videoState: provider.getVideoState(videoEvent.id), // New: Video state from VideoManager
                      userProfileService: provider.userProfileService,
                      seenVideosService: seenVideosService,
                      onComment: () => _openComments(videoEvent),
                      onShare: () => _shareVine(videoEvent),
                      onMoreOptions: () => _showMoreOptions(videoEvent),
                      onUserTap: () => _openUserProfile(videoEvent.pubkey),
                    );
                  },
                ),
              );
            },
          );
          
          // Return PageView with desktop-friendly scroll behavior on supported platforms
          if (kIsWeb || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) {
            return ScrollConfiguration(
              behavior: const DesktopScrollBehavior(),
              child: pageView,
            );
          } else {
            return pageView;
          }
        },
      ),
          
          // Vine-style transparent overlay UI
          _buildVineOverlay(),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildVineOverlay() {
    return SafeArea(
      child: Stack(
        children: [
          // Top bar with Vine logo and search
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Text(
                    'Vine',
                    style: TextStyle(
                      color: VineTheme.whiteText,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: VineTheme.whiteText,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    onPressed: () {
                      // TODO: Implement search functionality
                    },
                  ),
                  // Debug menu (only in debug mode)
                  if (kDebugMode)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: VineTheme.whiteText),
                      onSelected: (value) async {
                        if (value == 'clear_seen') {
                          final seenVideosService = context.read<SeenVideosService>();
                          final feedProvider = context.read<VideoFeedProvider>();
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          await seenVideosService.clearSeenVideos();
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(content: Text('Cleared seen videos history')),
                            );
                            feedProvider.refreshFeed();
                          }
                        } else if (value == 'toggle_debug') {
                          VideoSystemDebugger().toggleDebugOverlay();
                        } else if (value == 'system_legacy') {
                          VideoSystemDebugger().switchToSystem(VideoSystem.legacy);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Switched to Legacy VideoCacheService')),
                          );
                        } else if (value == 'system_manager') {
                          VideoSystemDebugger().switchToSystem(VideoSystem.manager);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Switched to VideoManagerService')),
                          );
                        } else if (value == 'system_hybrid') {
                          VideoSystemDebugger().switchToSystem(VideoSystem.hybrid);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Switched to Hybrid mode (current)')),
                          );
                        } else if (value == 'debug_report') {
                          final report = VideoSystemDebugger().getComparisonReport();
                          debugPrint(report);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Debug report printed to console')),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'clear_seen', child: Text('Clear Seen Videos')),
                        const PopupMenuItem(value: 'toggle_debug', child: Text('Toggle Debug Overlay')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'system_hybrid', child: Text('🔀 Hybrid Mode (Current)')),
                        const PopupMenuItem(value: 'system_manager', child: Text('⚡ VideoManagerService')),
                        const PopupMenuItem(value: 'system_legacy', child: Text('🏛️ VideoCacheService (Legacy)')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'debug_report', child: Text('📊 Performance Report')),
                      ],
                    ),
                ],
              ),
            ),
          ),
          
          // Right side action buttons (Vine-style)
          Positioned(
            right: 12,
            bottom: 100,
            child: Consumer<VideoFeedProvider>(
              builder: (context, provider, child) {
                if (provider.videoEvents.isEmpty) return const SizedBox.shrink();
                
                final videoEvent = provider.videoEvents[_currentPage];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Like button with real SocialService integration
                    Consumer<SocialService>(
                      builder: (context, socialService, child) {
                        final isLiked = socialService.isLiked(videoEvent.id);
                        final cachedLikeCount = socialService.getCachedLikeCount(videoEvent.id);
                        
                        return FutureBuilder<Map<String, dynamic>>(
                          future: cachedLikeCount == null 
                              ? socialService.getLikeStatus(videoEvent.id)
                              : Future.value({'count': cachedLikeCount, 'user_liked': isLiked}),
                          builder: (context, snapshot) {
                            final likeCount = snapshot.data?['count'] ?? 0;
                            final userLiked = snapshot.data?['user_liked'] ?? isLiked;
                            
                            return _buildActionButton(
                              icon: Icons.favorite_border,
                              filledIcon: Icons.favorite,
                              count: likeCount > 0 ? _formatCount(likeCount) : '',
                              isActive: userLiked,
                              onTap: () => _likeVideo(videoEvent, socialService),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Comment button  
                    _buildActionButton(
                      icon: Icons.chat_bubble_outline,
                      filledIcon: Icons.chat_bubble,
                      count: '0', // TODO: Get real comment count
                      isActive: false,
                      onTap: () => _openComments(videoEvent),
                    ),
                    const SizedBox(height: 24),
                    
                    // Share button
                    _buildActionButton(
                      icon: Icons.share_outlined,
                      filledIcon: Icons.share,
                      count: '',
                      isActive: false,
                      onTap: () => _shareVine(videoEvent),
                    ),
                    const SizedBox(height: 24),
                    
                    // More options button
                    _buildActionButton(
                      icon: Icons.more_horiz,
                      filledIcon: Icons.more_horiz,
                      count: '',
                      isActive: false,
                      onTap: () => _showMoreOptions(videoEvent),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Bottom user info overlay (Vine-style)
          Positioned(
            left: 12,
            right: 80, // Leave space for action buttons
            bottom: 20,
            child: Consumer<VideoFeedProvider>(
              builder: (context, provider, child) {
                if (provider.videoEvents.isEmpty) return const SizedBox.shrink();
                
                final videoEvent = provider.videoEvents[_currentPage];
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Username row
                      GestureDetector(
                        onTap: () => _openUserProfile(videoEvent.pubkey),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: VineTheme.vineGreen,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Consumer<UserProfileService>(
                                builder: (context, userProfileService, child) {
                                  final profile = userProfileService.getCachedProfile(videoEvent.pubkey);
                                  return Text(
                                    profile?.displayName ?? 'Anonymous',
                                    style: const TextStyle(
                                      color: VineTheme.whiteText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(0, 1),
                                          blurRadius: 2,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Follow button (for other users)
                            Consumer<AuthService>(
                              builder: (context, authService, child) {
                                if (videoEvent.pubkey == authService.currentPublicKeyHex) {
                                  return const SizedBox.shrink();
                                }
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white, width: 1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Follow',
                                    style: TextStyle(
                                      color: VineTheme.whiteText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // Video title/description
                      if (videoEvent.title?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          videoEvent.title!,
                          style: const TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 14,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 2,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      
                      // Hashtags (if any)
                      if (videoEvent.hashtags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: videoEvent.hashtags.take(3).map((hashtag) => Text(
                            '#$hashtag',
                            style: const TextStyle(
                              color: VineTheme.vineGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                  color: Colors.black87,
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required IconData filledIcon,
    required String count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? filledIcon : icon,
            color: isActive ? VineTheme.vineGreen : VineTheme.whiteText,
            size: 32,
            shadows: const [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 4,
                color: Colors.black87,
              ),
            ],
          ),
          if (count.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              count,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black87,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _likeVideo(VideoEvent videoEvent, SocialService socialService) async {
    try {
      await socialService.toggleLike(videoEvent.id, videoEvent.pubkey);
      debugPrint('✅ Successfully toggled like for video: ${videoEvent.id.substring(0, 8)}');
    } catch (e) {
      debugPrint('❌ Failed to toggle like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to like video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Format large numbers (e.g., 1234 -> "1.2K")
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  // Debug tap counter for triple-tap detection
  int _debugTapCount = 0;
  Timer? _debugTapTimer;

  void _handleDebugTap() {
    _debugTapCount++;
    _debugTapTimer?.cancel();
    
    if (_debugTapCount >= 3) {
      // Triple-tap detected - toggle debug overlay
      VideoSystemDebugger().toggleDebugOverlay();
      _debugTapCount = 0;
    } else {
      // Reset counter after 1 second
      _debugTapTimer = Timer(const Duration(seconds: 1), () {
        _debugTapCount = 0;
      });
    }
  }

  /// Auto-skip videos that are permanently failed due to server configuration errors
  void _handleAutoSkipIfNeeded(int currentIndex, VideoFeedProvider provider) {
    if (currentIndex >= provider.videoEvents.length) return;
    
    final videoEvent = provider.videoEvents[currentIndex];
    final videoState = provider.getVideoState(videoEvent.id);
    
    // Check if current video is permanently failed due to server config error
    if (videoState?.loadingState == VideoLoadingState.permanentlyFailed && 
        videoState?.errorMessage == 'SERVER_CONFIG_ERROR') {
      
      debugPrint('🔄 Auto-skipping permanently failed video: ${videoEvent.id.substring(0, 8)}');
      
      // Auto-advance to next video after a brief delay to show the error state
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _currentPage == currentIndex && currentIndex < provider.videoEvents.length - 1) {
          debugPrint('⏭️ Auto-advancing to next video...');
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }


  void _openComments(VideoEvent videoEvent) {
    // TODO: Implement comments functionality with threaded replies
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening comments for ${videoEvent.id.substring(0, 8)}...')),
    );
  }

  void _shareVine(VideoEvent videoEvent) {
    // TODO: Implement share functionality with Nostr event links
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sharing video: ${videoEvent.title ?? "Video"}')),
    );
  }

  void _showMoreOptions(VideoEvent videoEvent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.white),
              title: const Text('Report Content', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement content reporting
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.white),
              title: const Text('Block User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement user blocking
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white),
              title: const Text('Copy Event ID', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Copy Nostr event ID to clipboard
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.white),
              title: const Text('View Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openUserProfile(videoEvent.pubkey);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _openUserProfile(String pubkey) {
    // Navigate to the profile screen to view user profile
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfileScreen(profilePubkey: pubkey),
      ),
    );
  }
}

/// Custom scroll behavior for desktop platforms that enables mouse drag scrolling
class DesktopScrollBehavior extends ScrollBehavior {
  const DesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}