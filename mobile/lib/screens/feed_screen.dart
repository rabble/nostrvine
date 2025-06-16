import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/video_feed_provider.dart';
import '../models/video_event.dart';
import '../widgets/video_feed_item.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Initialize video feed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFeed();
    });
  }
  
  void _initializeFeed() async {
    final provider = context.read<VideoFeedProvider>();
    if (!provider.isInitialized) {
      await provider.initialize();
    }
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when near bottom
      context.read<VideoFeedProvider>().loadMoreEvents();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${provider.error}',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.retry(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          if (!provider.hasEvents) {
            return RefreshIndicator(
              onRefresh: () => provider.refreshFeed(),
              child: ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.video_library_outlined, 
                             color: Colors.white54, size: 64),
                        SizedBox(height: 16),
                        Text(
                          'No video content found',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Pull to refresh or wait for new content',
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: () => provider.refreshFeed(),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: provider.videoEvents.length + (provider.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= provider.videoEvents.length) {
                  // Loading indicator at bottom
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                }
                
                final videoEvent = provider.videoEvents[index];
                return VideoFeedItem(
                  videoEvent: videoEvent,
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