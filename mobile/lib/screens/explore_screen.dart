// ABOUTME: Explore screen showing trending content, Editor's Picks, and Popular Now sections
// ABOUTME: Displays curated content similar to original Vine's explore tab

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/vine_theme.dart';
import '../services/video_event_service.dart';
import '../services/explore_video_manager.dart';
import '../services/hashtag_service.dart';
import '../models/curation_set.dart';
import '../models/video_event.dart';
import 'search_screen.dart';
import 'hashtag_feed_screen.dart';
import '../widgets/video_preview_tile.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedHashtag;
  String? _playingVideoId;

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


  Widget _buildEditorsPicks() {
    return Consumer2<ExploreVideoManager, HashtagService>(
      builder: (context, exploreVideoManager, hashtagService, child) {
        // Get editor's picks from explore video manager (managed through VideoManager)
        final editorsPicks = exploreVideoManager.getVideosForType(CurationSetType.editorsPicks);
        
        // VideoEventBridge handles subscription during app initialization
        
        if (exploreVideoManager.isLoading && editorsPicks.isEmpty) {
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
        
        // Get editor's pick hashtags
        final editorsHashtags = hashtagService.getEditorsPicks(limit: 10);
        
        // Display as a featured list with larger thumbnails
        return Column(
          children: [
            // Editor's pick hashtags
            if (editorsHashtags.isNotEmpty) ...[
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: editorsHashtags.length,
                  itemBuilder: (context, index) {
                    final hashtag = editorsHashtags[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text('#$hashtag'),
                        onPressed: () {
                          debugPrint('🔗 Navigating to hashtag feed from editor\'s picks: #$hashtag');
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (context) => HashtagFeedScreen(hashtag: hashtag),
                            ),
                          );
                        },
                        backgroundColor: VineTheme.cardBackground,
                        labelStyle: const TextStyle(
                          color: VineTheme.primaryText,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: VineTheme.secondaryText, height: 1),
              const SizedBox(height: 8),
            ],
            
            // Video list - responsive layout
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  // For wide screens, show grid layout; for narrow screens, show list
                  if (screenWidth > 900) {
                    // Grid layout for desktop
                    final crossAxisCount = screenWidth < 1200 ? 2 : 3;
                    return GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 16/9, // Wide aspect ratio for featured content
                      ),
                      itemCount: editorsPicks.length,
                      itemBuilder: (context, index) {
                        final video = editorsPicks[index];
                        return _buildEditorsPickCard(video);
                      },
                    );
                  } else {
                    // List layout for mobile/tablet
                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: editorsPicks.length,
                      itemBuilder: (context, index) {
                        final video = editorsPicks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildEditorsPickCard(video),
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditorsPickCard(VideoEvent video) {
    final isPlaying = _playingVideoId == video.id;
    
    debugPrint('🎬 Building editor\'s pick card: ${video.id.substring(0, 8)}..., isPlaying: $isPlaying, hasVideo: ${video.hasVideo}, thumbnailUrl: ${video.effectiveThumbnailUrl}');
    
    return Container(
      height: 250, // Increased height for better video display
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Use VideoPreviewTile for automatic playback
                      VideoPreviewTile(
                        video: video,
                        isActive: isPlaying,
                        onTap: () {
                          setState(() {
                            _playingVideoId = isPlaying ? null : video.id;
                          });
                        },
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
    );
  }

  Widget _buildPopularNow() {
    return Consumer2<ExploreVideoManager, HashtagService>(
      builder: (context, exploreVideoManager, hashtagService, child) {
        // Get trending videos from explore video manager (managed through VideoManager)
        final videos = exploreVideoManager.getVideosForType(CurationSetType.trending);
        
        // VideoEventBridge handles subscription during app initialization
        
        if (exploreVideoManager.isLoading && videos.isEmpty) {
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
        
        // Display videos in a responsive grid layout
        final screenWidth = MediaQuery.of(context).size.width;
        // Calculate columns based on screen width
        // Mobile: 2 columns, Tablet: 3-4 columns, Desktop: 4-6 columns
        final crossAxisCount = screenWidth < 600 ? 2 : 
                               screenWidth < 900 ? 3 : 
                               screenWidth < 1200 ? 4 : 
                               screenWidth < 1600 ? 5 : 6;
        
        return GridView.builder(
          padding: const EdgeInsets.all(1),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
            childAspectRatio: 1,
          ),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _playingVideoId = _playingVideoId == video.id ? null : video.id;
                });
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.black,
                    child: VideoPreviewTile(
                      video: video,
                      isActive: _playingVideoId == video.id,
                      onTap: () {
                        setState(() {
                          _playingVideoId = _playingVideoId == video.id ? null : video.id;
                        });
                      },
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
    return Consumer3<ExploreVideoManager, VideoEventService, HashtagService>(
      builder: (context, exploreVideoManager, videoService, hashtagService, child) {
        final trendingHashtags = hashtagService.getTrendingHashtags(limit: 30);
        
        // Get videos based on selection
        late final List<VideoEvent> videos;
        if (_selectedHashtag != null) {
          // Filter by specific hashtag
          videos = hashtagService.getVideosByHashtags([_selectedHashtag!]);
        } else {
          // Use trending from explore video manager, fallback to recent videos
          final trendingVideos = exploreVideoManager.getVideosForType(CurationSetType.trending);
          videos = trendingVideos.isNotEmpty 
              ? trendingVideos 
              : videoService.getRecentVideoEvents(hours: 24);
        }

        return Column(
          children: [
            // Hashtag filter chips
            if (trendingHashtags.isNotEmpty) ...[
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: trendingHashtags.length + 1, // +1 for "All" chip
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
                    
                    final hashtag = trendingHashtags[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onLongPress: () {
                          // Navigate to full hashtag feed on long press
                          debugPrint('🔗 Navigating to hashtag feed from trending (long press): #$hashtag');
                          Navigator.of(context, rootNavigator: true).push(
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
                      padding: const EdgeInsets.all(8),
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _playingVideoId = _playingVideoId == video.id ? null : video.id;
                              });
                            },
                            child: Container(
                              height: 250,  // Increased height for better video display
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Use VideoPreviewTile for automatic playback
                                  VideoPreviewTile(
                                    video: video,
                                    isActive: _playingVideoId == video.id,
                                    onTap: () {
                                      setState(() {
                                        _playingVideoId = _playingVideoId == video.id ? null : video.id;
                                      });
                                    },
                                  ),
                                  // Video info overlay
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
                    ),
            ),
          ],
        );
      },
    );
  }
}