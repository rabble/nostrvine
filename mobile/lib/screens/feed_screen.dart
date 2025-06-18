import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_feed_provider.dart';
import '../models/video_event.dart';
import '../widgets/video_feed_item.dart';
import '../services/connection_status_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
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
        ],
      ),
      body: Consumer<VideoFeedProvider>(
        builder: (context, provider, child) {
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
          
          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: provider.videoEvents.isNotEmpty ? null : 0, // Infinite scroll if we have videos
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              
              final readyVideoCount = provider.videoEvents.length;
              if (readyVideoCount > 0) {
                // Use modulo to wrap around if we reach the end
                final actualIndex = index % readyVideoCount;
                
                // Load more when getting close to the end of ready videos
                if (actualIndex >= readyVideoCount - 3) {
                  provider.loadMoreEvents();
                }
                // Preload videos around current index in the full video list
                provider.preloadVideosAroundIndex(actualIndex);
              }
            },
            itemBuilder: (context, index) {
              final readyVideoCount = provider.videoEvents.length;
              if (readyVideoCount == 0) return const SizedBox.shrink();
              
              // Use modulo to repeat videos if we reach the end
              final actualIndex = index % readyVideoCount;
              final videoEvent = provider.videoEvents[actualIndex];
              
              return SizedBox(
                height: MediaQuery.of(context).size.height,
                child: VideoFeedItem(
                  videoEvent: videoEvent,
                  isActive: index == _currentPage,
                  videoCacheService: provider.videoCacheService,
                  userProfileService: provider.userProfileService,
                  onLike: () => _toggleLike(videoEvent),
                  onComment: () => _openComments(videoEvent),
                  onShare: () => _shareVine(videoEvent),
                  onMoreOptions: () => _showMoreOptions(videoEvent),
                  onUserTap: () => _openUserProfile(videoEvent.pubkey),
                ),
              );
            },
          );
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