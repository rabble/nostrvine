import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/video_feed_provider.dart';
import '../models/video_event.dart';
import '../widgets/video_feed_item.dart';
import '../services/connection_status_service.dart';
import '../services/seen_videos_service.dart';
import '../services/user_profile_service.dart';
import '../utils/logger.dart';
import '../navigation/navigation_service.dart';

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
              NavigationService.goToSearch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              NavigationService.goToNotifications();
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
              
              // Enhanced structured logging for debugging index mismatches
              if (readyVideoCount > 0 && index < readyVideoCount) {
                appLog(
                  LogCategory.UI, '📱', 'Page Changed',
                  videoId: provider.videoEvents[index].id,
                  details: {
                    'index': index,
                    'readyCount': readyVideoCount,
                    'allCount': allVideoCount,
                    'isSubscribed': isSubscribed,
                    'canLoadMore': canLoadMore,
                  },
                );
              } else {
                appLog(
                  LogCategory.ERROR, '⚠️', 'Invalid Page Index',
                  details: {
                    'index': index,
                    'readyCount': readyVideoCount,
                    'allCount': allVideoCount,
                  },
                );
              }
              
              if (readyVideoCount > 0) {
                // Load more when getting close to the end of ready videos
                if (index >= readyVideoCount - 3) {
                  appLog(LogCategory.UI, '📱', 'Near end of ready videos, loading more...', details: {
                    'index': index,
                    'readyCount': readyVideoCount,
                    'canLoadMore': canLoadMore,
                  });
                  if (canLoadMore) {
                    provider.loadMoreEvents();
                  } else {
                    appLog(LogCategory.ERROR, '⚠️', 'Cannot load more events - subscription may have stopped');
                  }
                }
                // Preload videos around current index using the ready video list
                provider.preloadVideosAroundIndex(index);
              } else {
                appLog(LogCategory.ERROR, '⚠️', 'No ready videos available for preloading');
              }
            },
            itemBuilder: (context, index) {
              final readyVideoCount = provider.videoEvents.length;
              if (readyVideoCount == 0 || index >= readyVideoCount) {
                debugPrint('⚠️ Invalid video index: $index/$readyVideoCount');
                return Container(
                  height: MediaQuery.of(context).size.height,
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  ),
                );
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
                      videoCacheService: provider.videoCacheService,
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
                _copyEventIdToClipboard(videoEvent);
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

  void _copyEventIdToClipboard(VideoEvent videoEvent) async {
    try {
      // Show option dialog for copy format
      final format = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Copy Format', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Choose the format for copying the event ID:',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'hex'),
              child: const Text('Event ID (hex)', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'nevent'),
              child: const Text('nevent format', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      );

      if (format == null) return;

      String textToCopy;
      String formatName;
      
      if (format == 'hex') {
        textToCopy = videoEvent.id;
        formatName = 'Event ID';
      } else {
        // Create nevent format (simplified version)
        // Full implementation would use proper NIP-19 encoding
        textToCopy = 'nevent1${videoEvent.id}'; // Simplified - real implementation needs proper bech32 encoding
        formatName = 'nevent';
      }

      await Clipboard.setData(ClipboardData(text: textToCopy));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$formatName copied to clipboard'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Show',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: Text('Copied $formatName', style: const TextStyle(color: Colors.white)),
                    content: SelectableText(
                      textToCopy,
                      style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to copy event ID: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy: ${e.toString()}'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }
  
  void _openUserProfile(String pubkey) {
    final displayName = context.read<UserProfileService>()
        .getCachedProfile(pubkey)?.bestDisplayName;
    NavigationService.goToUserProfile(pubkey, displayName: displayName);
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