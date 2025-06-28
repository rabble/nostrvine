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
import '../widgets/video_explore_tile.dart';
import '../widgets/video_feed_item.dart';
import '../widgets/video_fullscreen_overlay.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  String? _selectedHashtag;
  String? _playingVideoId;
  int _currentVideoIndex = 0;
  List<VideoEvent> _currentTabVideos = [];
  bool _isInFeedMode = false; // Track if we're in full feed mode vs grid mode

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Listen for tab changes to close video and reset state
    _tabController.addListener(_onTabChanged);
    
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }
  
  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      // Pause any playing videos when switching tabs
      final exploreVideoManager = Provider.of<ExploreVideoManager>(context, listen: false);
      exploreVideoManager.pauseAllVideos();
      
      // Close the currently playing video overlay if any and return to grid mode
      if (_playingVideoId != null || _isInFeedMode) {
        setState(() {
          _playingVideoId = null;
          _currentVideoIndex = 0;
          _currentTabVideos = [];
          _isInFeedMode = false; // Return to grid mode when switching tabs
        });
      }
      
      // Reset video index for all tabs
      setState(() {
        _currentVideoIndex = 0;
      });
    }
  }

  /// Handle video tap to enter feed mode
  void _enterFeedMode(List<VideoEvent> videos, int startIndex) {
    setState(() {
      _isInFeedMode = true;
      _currentTabVideos = videos;
      _currentVideoIndex = startIndex;
      _playingVideoId = videos[startIndex].id;
    });
  }
  
  /// Exit feed mode and return to grid view
  void _exitFeedMode() {
    setState(() {
      _isInFeedMode = false;
      _playingVideoId = null;
      _currentVideoIndex = 0;
      _currentTabVideos = [];
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    
    // Pause any playing videos
    final exploreVideoManager = Provider.of<ExploreVideoManager>(context, listen: false);
    exploreVideoManager.pauseAllVideos();
    
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Only handle lifecycle for Popular Now tab with PageView
    if (_tabController.index != 1) return;
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Pause videos when app goes to background
        final exploreVideoManager = Provider.of<ExploreVideoManager>(context, listen: false);
        exploreVideoManager.pauseAllVideos();
        break;
      case AppLifecycleState.resumed:
        // Videos will auto-resume via VideoFeedItem when it rebuilds
        if (mounted) {
          setState(() {}); // Trigger rebuild
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
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
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildEditorsPicks(),
              _buildPopularNow(),
              _buildTrending(),
            ],
          ),
          // Overlay for expanded video (not for Editor's Picks which uses PageView)
          if (_playingVideoId != null && _tabController.index != 0)
            _buildExpandedVideoOverlay(),
        ],
      ),
    );
  }

  Widget _buildExpandedVideoOverlay() {
    // Get videos for current tab
    final exploreVideoManager = Provider.of<ExploreVideoManager>(context, listen: false);
    List<VideoEvent> tabVideos = [];
    
    switch (_tabController.index) {
      case 0: // Editor's Picks
        tabVideos = exploreVideoManager.getVideosForType(CurationSetType.editorsPicks);
        break;
      case 1: // Popular Now
        tabVideos = exploreVideoManager.getVideosForType(CurationSetType.trending);
        break;
      case 2: // Trending
        if (_selectedHashtag != null) {
          final hashtagService = Provider.of<HashtagService>(context, listen: false);
          tabVideos = hashtagService.getVideosByHashtags([_selectedHashtag!]);
        } else {
          final trendingVideos = exploreVideoManager.getVideosForType(CurationSetType.trending);
          if (trendingVideos.isNotEmpty) {
            tabVideos = trendingVideos;
          } else {
            final videoService = Provider.of<VideoEventService>(context, listen: false);
            tabVideos = videoService.getRecentVideoEvents(hours: 24);
          }
        }
        break;
    }
    
    // Update current tab videos if they've changed
    if (_currentTabVideos != tabVideos) {
      _currentTabVideos = tabVideos;
      // Find current video index
      _currentVideoIndex = _currentTabVideos.indexWhere((v) => v.id == _playingVideoId);
      if (_currentVideoIndex == -1) _currentVideoIndex = 0;
    }
    
    if (_currentTabVideos.isEmpty) {
      return Container(); // No videos to show
    }
    
    // Ensure current index is valid
    _currentVideoIndex = _currentVideoIndex.clamp(0, _currentTabVideos.length - 1);
    final video = _currentTabVideos[_currentVideoIndex];
    
    return VideoFullscreenOverlay(
      video: video,
      onClose: () {
        setState(() {
          _playingVideoId = null;
          _currentVideoIndex = 0;
          _currentTabVideos = [];
        });
      },
      onSwipeNext: _currentVideoIndex < _currentTabVideos.length - 1 ? () {
        setState(() {
          _currentVideoIndex++;
          _playingVideoId = _currentTabVideos[_currentVideoIndex].id;
        });
      } : null,
      onSwipePrevious: _currentVideoIndex > 0 ? () {
        setState(() {
          _currentVideoIndex--;
          _playingVideoId = _currentTabVideos[_currentVideoIndex].id;
        });
      } : null,
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
        
        // Full-screen video feed with hashtag filter at top
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
            ],
            
            // Full-screen video feed like main feed
            Expanded(
              child: PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: editorsPicks.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentVideoIndex = index;
                  });
                  
                  // Preload videos around current position
                  final exploreVideoManager = Provider.of<ExploreVideoManager>(context, listen: false);
                  exploreVideoManager.preloadCollection(CurationSetType.editorsPicks, startIndex: index);
                },
                itemBuilder: (context, index) {
                  final video = editorsPicks[index];
                  final isActive = index == _currentVideoIndex && _tabController.index == 0;
                  
                  return VideoFeedItem(
                    key: ValueKey(video.id),
                    video: video,
                    isActive: isActive,
                  );
                },
              ),
            ),
          ],
        );
      },
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
        
        // For mobile devices, show a button to enter swipeable video feed
        // For larger screens, keep the grid layout
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        
        if (isMobile) {
          // Mobile: Show videos in a swipeable PageView directly
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            onPageChanged: (index) {
              setState(() {
                _currentVideoIndex = index;
              });
              
              // Preload videos around current position
              final exploreVideoManager = Provider.of<ExploreVideoManager>(context, listen: false);
              exploreVideoManager.preloadCollection(CurationSetType.trending, startIndex: index);
            },
            itemBuilder: (context, index) {
              final video = videos[index];
              final isActive = index == _currentVideoIndex;
              
              return VideoFeedItem(
                key: ValueKey(video.id),
                video: video,
                isActive: isActive,
              );
            },
          );
        } else {
          // Desktop/Tablet: Keep existing grid with overlay
          final crossAxisCount = screenWidth < 900 ? 3 : 
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
              return VideoExploreTile(
                video: video,
                isActive: false, // Never active in grid - overlay handles playback
                onTap: () {
                  setState(() {
                    _playingVideoId = video.id;
                    // We'll let the overlay update the index when it rebuilds
                  });
                },
                onClose: () {
                  setState(() {
                    _playingVideoId = null;
                    _currentVideoIndex = 0;
                    _currentTabVideos = [];
                  });
                },
              );
            },
          );
        }
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
                          child: SizedBox(
                            height: 250,  // Increased height for better video display
                            child: VideoExploreTile(
                              video: video,
                              isActive: false, // Never active in list - overlay handles playback
                              onTap: () {
                                setState(() {
                                  _playingVideoId = video.id;
                                  // We'll let the overlay update the index when it rebuilds
                                });
                              },
                              onClose: () {
                                setState(() {
                                  _playingVideoId = null;
                                  _currentVideoIndex = 0;
                                  _currentTabVideos = [];
                                });
                              },
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