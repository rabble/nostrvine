// ABOUTME: Explore screen showing trending content, Editor's Picks, and Popular Now sections
// ABOUTME: Displays curated content similar to original Vine's explore tab

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/vine_theme.dart';
import '../services/video_event_service.dart';
import '../services/video_manager_interface.dart';
import '../widgets/video_feed_item.dart';
import 'search_screen.dart';
import 'hashtag_feed_screen.dart';
import '../utils/feed_navigation.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedHashtag;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        elevation: 0,
        title: const Text(
          'Explore',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: VineTheme.whiteText),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: VineTheme.whiteText,
          indicatorWeight: 2,
          labelColor: VineTheme.whiteText,
          unselectedLabelColor: VineTheme.whiteText.withValues(alpha: 0.7),
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "EDITOR'S PICKS"),
            Tab(text: 'POPULAR NOW'),
            Tab(text: 'TRENDING'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEditorsPicks(),
          _buildPopularNow(),
          _buildTrending(),
        ],
      ),
    );
  }

  /// Ensure video is registered with VideoManager before displaying
  Future<void> _ensureVideoRegistered(BuildContext context, dynamic video) async {
    try {
      final videoManager = Provider.of<IVideoManager>(context, listen: false);
      final videoState = videoManager.getVideoState(video.id);
      
      if (videoState == null) {
        // Video not registered, add it to VideoManager
        await videoManager.addVideoEvent(video);
        debugPrint('📋 Registered video ${video.id.substring(0, 8)}... with VideoManager');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to register video ${video.id}: $e');
    }
  }

  Widget _buildEditorsPicks() {
    return Consumer<VideoEventService>(
      builder: (context, videoService, child) {
        // For editor's picks, we'll show all videos (no time limit)
        // In a real app, this might be curated by moderators
        final allVideos = videoService.videoEvents;
        
        // Sort by creation date, newest first
        final sortedVideos = List.from(allVideos)
          ..sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
        
        // Take up to 20 videos for editor's picks
        final editorsPicks = sortedVideos.take(20).toList();
        
        // VideoEventBridge handles subscription during app initialization
        
        if (videoService.isLoading && editorsPicks.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              color: VineTheme.vineGreen,
            ),
          );
        }
        
        if (editorsPicks.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_outline,
                  size: 64,
                  color: VineTheme.secondaryText,
                ),
                SizedBox(height: 16),
                Text(
                  "Editor's Picks",
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Curated videos selected by our\ncommunity moderators.',
                  style: TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        // Display as a featured list with larger thumbnails
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: editorsPicks.length,
          itemBuilder: (context, index) {
            final video = editorsPicks[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () async {
                  // Ensure video is registered with VideoManager first
                  await _ensureVideoRegistered(context, video);
                  
                  if (!mounted) return;
                  
                  if (context.mounted) {
                    // Navigate to editor's picks feed starting with this video
                    FeedNavigation.goToEditorsPicks(context, video);
                  }
                },
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: video.thumbnailUrl != null
                            ? Image.network(
                                video.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.play_circle_outline,
                                      color: Colors.white54,
                                      size: 64,
                                    ),
                                  );
                                },
                              )
                            : const Center(
                                child: Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white54,
                                  size: 64,
                                ),
                              ),
                      ),
                      // Play button overlay
                      const Center(
                        child: Icon(
                          Icons.play_circle_filled,
                          color: Colors.white70,
                          size: 64,
                        ),
                      ),
                      // Info overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.9),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: VineTheme.vineGreen,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    "EDITOR'S PICK",
                                    style: TextStyle(
                                      color: VineTheme.vineGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (video.title != null)
                                Text(
                                  video.title!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (video.hashtags.isNotEmpty)
                                Text(
                                  video.hashtags.map((tag) => '#$tag').join(' '),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPopularNow() {
    return Consumer<VideoEventService>(
      builder: (context, videoService, child) {
        // Get recent videos from the last 24 hours
        final videos = videoService.getRecentVideoEvents(hours: 24);
        
        // VideoEventBridge handles subscription during app initialization
        
        if (videoService.isLoading && videos.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              color: VineTheme.vineGreen,
            ),
          );
        }
        
        if (videos.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  size: 64,
                  color: VineTheme.secondaryText,
                ),
                SizedBox(height: 16),
                Text(
                  'Popular Now',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Videos getting the most likes\nand shares right now.',
                  style: TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        // Display videos in a grid layout similar to original Vine
        return GridView.builder(
          padding: const EdgeInsets.all(1),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
            childAspectRatio: 1,
          ),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return GestureDetector(
              onTap: () async {
                // Ensure video is registered with VideoManager first
                await _ensureVideoRegistered(context, video);
                
                if (!mounted) return;
                
                // Navigate to full screen video view
                if (context.mounted) {
                  Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      backgroundColor: Colors.black,
                      body: Stack(
                        children: [
                          Center(
                            child: VideoFeedItem(
                              video: video,
                              isActive: true,
                            ),
                          ),
                          SafeArea(
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.black,
                    child: video.thumbnailUrl != null
                        ? Image.network(
                            video.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white54,
                                  size: 48,
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white54,
                              size: 48,
                            ),
                          ),
                  ),
                  // Overlay with play icon
                  const Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      color: Colors.white70,
                      size: 48,
                    ),
                  ),
                  // Video info overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (video.title != null)
                            Text(
                              video.title!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (video.hashtags.isNotEmpty)
                            Text(
                              video.hashtags.map((tag) => '#$tag').join(' '),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrending() {
    return Consumer<VideoEventService>(
      builder: (context, videoService, child) {
        final allHashtags = videoService.getAllHashtags().toList();
        final videos = _selectedHashtag != null 
            ? videoService.getVideoEventsByHashtags([_selectedHashtag!])
            : videoService.getRecentVideoEvents(hours: 24);

        return Column(
          children: [
            // Hashtag filter chips
            if (allHashtags.isNotEmpty) ...[
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: allHashtags.length + 1, // +1 for "All" chip
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // "All" chip
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('All'),
                          selected: _selectedHashtag == null,
                          onSelected: (selected) {
                            setState(() {
                              _selectedHashtag = null;
                            });
                          },
                          backgroundColor: VineTheme.cardBackground,
                          selectedColor: VineTheme.vineGreen,
                          labelStyle: TextStyle(
                            color: _selectedHashtag == null 
                                ? VineTheme.whiteText 
                                : VineTheme.primaryText,
                            fontWeight: _selectedHashtag == null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }
                    
                    final hashtag = allHashtags[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onLongPress: () {
                          // Navigate to full hashtag feed on long press
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => HashtagFeedScreen(hashtag: hashtag),
                            ),
                          );
                        },
                        child: FilterChip(
                          label: Text('#$hashtag'),
                          selected: _selectedHashtag == hashtag,
                          onSelected: (selected) {
                            setState(() {
                              _selectedHashtag = selected ? hashtag : null;
                            });
                          },
                          backgroundColor: VineTheme.cardBackground,
                          selectedColor: VineTheme.vineGreen,
                          labelStyle: TextStyle(
                            color: _selectedHashtag == hashtag 
                                ? VineTheme.whiteText 
                                : VineTheme.primaryText,
                            fontWeight: _selectedHashtag == hashtag ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: VineTheme.secondaryText, height: 1),
            ],
            
            // Video list
            Expanded(
              child: videos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedHashtag != null 
                                ? Icons.tag 
                                : Icons.local_fire_department_outlined,
                            size: 64,
                            color: VineTheme.secondaryText,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedHashtag != null 
                                ? 'No videos found for #$_selectedHashtag'
                                : 'No trending videos yet',
                            style: const TextStyle(
                              color: VineTheme.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedHashtag != null
                                ? 'Try a different hashtag or check back later'
                                : 'Check back later for trending content',
                            style: const TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        return FutureBuilder(
                          future: _ensureVideoRegistered(context, video),
                          builder: (context, snapshot) {
                            // While registering, show a placeholder
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Container(
                                height: 200,
                                color: Colors.black,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: VineTheme.vineGreen,
                                  ),
                                ),
                              );
                            }
                            
                            return GestureDetector(
                              onTap: () {
                                if (_selectedHashtag != null) {
                                  // Navigate to hashtag feed
                                  FeedNavigation.goToHashtagFeed(context, video, _selectedHashtag!);
                                } else {
                                  // Navigate to trending feed
                                  FeedNavigation.goToTrendingFeed(context, video);
                                }
                              },
                              child: VideoFeedItem(
                                video: video,
                                isActive: false,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}