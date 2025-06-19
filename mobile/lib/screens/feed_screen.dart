import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/video_feed_provider.dart';
import '../models/video_event.dart';
import '../widgets/video_feed_item.dart';
import '../services/connection_status_service.dart';
import '../services/seen_videos_service.dart';

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'NostrVine',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
          // Debug option to clear seen videos
          if (kDebugMode)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) async {
                if (value == 'clear_seen') {
                  final seenVideosService = context.read<SeenVideosService>();
                  await seenVideosService.clearSeenVideos();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cleared seen videos history')),
                    );
                    // Refresh the feed to show previously seen videos
                    context.read<VideoFeedProvider>().refreshFeed();
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear_seen',
                  child: Text('Clear Seen Videos'),
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
          if (_lastLoggedVideoCount != provider.videoEvents.length) {
            _lastLoggedVideoCount = provider.videoEvents.length;
            debugPrint('📺 FeedScreen Consumer: readyVideos changed to ${provider.videoEvents.length}');
          }
          
          if (!provider.isInitialized && provider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Connecting to Nostr relays...',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            );
          }
          
          if (provider.error != null) {
            return Consumer<ConnectionStatusService>(
              builder: (context, connectionService, child) {
                final isOffline = !connectionService.isOnline;
                
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isOffline ? Icons.wifi_off : Icons.error_outline, 
                        color: isOffline ? Colors.orange : Colors.red, 
                        size: 48
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isOffline ? 'No Internet Connection' : 'Error: ${provider.error}',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isOffline 
                          ? 'Check your internet connection and try again'
                          : 'Unable to load video feed',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: isOffline ? null : () => provider.retry(),
                        child: Text(isOffline ? 'Waiting for connection...' : 'Retry'),
                      ),
                    ],
                  ),
                );
              },
            );
          }
          
          if (!provider.hasEvents) {
            return Consumer<ConnectionStatusService>(
              builder: (context, connectionService, child) {
                final isOffline = !connectionService.isOnline;
                
                return RefreshIndicator(
                  onRefresh: isOffline ? () async {} : () => provider.refreshFeed(),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isOffline ? Icons.wifi_off : Icons.video_library_outlined, 
                          color: Colors.white54, 
                          size: 64
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isOffline ? 'Offline' : 'Finding videos...',
                          style: const TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOffline 
                            ? 'Connect to the internet to load videos'
                            : 'Searching Nostr relays for video content',
                          style: const TextStyle(color: Colors.white38, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        if (!isOffline) ...[
                          const SizedBox(height: 16),
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
            itemCount: provider.videoEvents.length, // ✅ FIXED: Use ready-to-play videos, not raw events
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              
              final readyVideoCount = provider.videoEvents.length;
              final allVideoCount = provider.allVideoEvents.length;
              final isSubscribed = provider.isSubscribed;
              final canLoadMore = provider.canLoadMore;
              
              debugPrint('📱 Page changed to video $index/$readyVideoCount (all: $allVideoCount, subscribed: $isSubscribed, canLoadMore: $canLoadMore)');
              
              if (readyVideoCount > 0) {
                // Load more when getting close to the end of ready videos
                if (index >= readyVideoCount - 3) {
                  debugPrint('📱 Near end of ready videos ($index/$readyVideoCount), loading more...');
                  if (canLoadMore) {
                    provider.loadMoreEvents();
                  } else {
                    debugPrint('⚠️ Cannot load more events - subscription may have stopped');
                  }
                }
                // Preload videos around current index using the ready video list
                provider.preloadVideosAroundIndex(index);
              } else {
                debugPrint('⚠️ No ready videos available for preloading');
              }
            },
            itemBuilder: (context, index) {
              final readyVideoCount = provider.videoEvents.length;
              if (readyVideoCount == 0 || index >= readyVideoCount) {
                debugPrint('⚠️ Invalid video index: $index/$readyVideoCount');
                return const SizedBox.shrink();
              }
              
              // ✅ FIXED: Use ready-to-play videos that have passed compatibility testing
              final videoEvent = provider.videoEvents[index];
              // TEMPORARILY DISABLED: Reduce debug spam during infinite rebuild investigation
              // if (index == _currentPage) {
              //   debugPrint('📱 Building VideoFeedItem for ${videoEvent.id.substring(0, 8)} at index $index (active: true)');
              // }
              
              
              return SizedBox(
                height: MediaQuery.of(context).size.height,
                child: Consumer<SeenVideosService>(
                  builder: (context, seenVideosService, child) {
                    return VideoFeedItem(
                      videoEvent: videoEvent,
                      isActive: index == _currentPage,
                      videoCacheService: provider.videoCacheService, // Legacy compatibility
                      videoController: provider.getController(videoEvent.id), // New: Direct controller from VideoManager
                      videoState: provider.getVideoState(videoEvent.id), // New: Video state from VideoManager
                      userProfileService: provider.userProfileService,
                      seenVideosService: seenVideosService,
                      onLike: () => _toggleLike(videoEvent),
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
    );
  }

  void _toggleLike(VideoEvent videoEvent) {
    // TODO: Implement NIP-25 reaction events for likes
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Liked video by ${videoEvent.displayPubkey}')),
    );
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