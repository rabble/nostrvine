import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/video_feed_provider.dart';
import '../models/video_event.dart';
import '../widgets/video_feed_item.dart';
import '../services/connection_status_service.dart';
import '../services/seen_videos_service.dart';
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
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        elevation: 1,
        title: const Text(
          'NostrVine',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: VineTheme.whiteText),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: VineTheme.whiteText),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
          // Debug option to clear seen videos
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
                    // Refresh the feed to show previously seen videos
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
                const PopupMenuItem(
                  value: 'clear_seen',
                  child: Text('Clear Seen Videos'),
                ),
                const PopupMenuItem(
                  value: 'toggle_debug',
                  child: Text('Toggle Debug Overlay'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'system_hybrid',
                  child: Text('🔀 Hybrid Mode (Current)'),
                ),
                const PopupMenuItem(
                  value: 'system_manager',
                  child: Text('⚡ VideoManagerService'),
                ),
                const PopupMenuItem(
                  value: 'system_legacy',
                  child: Text('🏛️ VideoCacheService (Legacy)'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'debug_report',
                  child: Text('📊 Performance Report'),
                ),
              ],
            ),
        ],
      ),
      body: Consumer<VideoFeedProvider>(
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
            itemCount: provider.videoEvents.length > 0 ? provider.videoEvents.length : provider.readyVideos.length, // Allow swiping through all videos
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
              final readyVideoCount = provider.readyVideos.length;
              
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
                child: Consumer<SeenVideosService>(
                  builder: (context, seenVideosService, child) {
                    // Show loading state for videos that aren't ready yet
                    if (!isVideoReady) {
                      return Container(
                        height: MediaQuery.of(context).size.height,
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
        ),
      ),
    );
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
    // TODO: Navigate to user profile screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening profile for user: ${pubkey.substring(0, 8)}...')),
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