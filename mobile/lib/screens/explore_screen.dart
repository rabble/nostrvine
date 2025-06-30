// ABOUTME: Explore screen showing trending content, Editor's Picks, and Popular Now sections
// ABOUTME: Displays curated content similar to original Vine's explore tab

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/vine_theme.dart';
import '../services/video_event_service.dart';
import '../services/explore_video_manager.dart';
import '../services/hashtag_service.dart';
import '../services/curation_service.dart';
import '../models/curation_set.dart';
import '../models/video_event.dart';
import 'search_screen.dart';
import 'hashtag_feed_screen.dart';
import '../widgets/video_explore_tile.dart';
import '../widgets/video_feed_item.dart';
import '../utils/unified_logger.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => ExploreScreenState();
}

// Made public to allow access from MainNavigationScreen
class ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
      
      // Fetch trending data when user switches to Popular Now or Trending tabs
      if (_tabController.index == 1 || _tabController.index == 2) {
        final curationService = Provider.of<CurationService>(context, listen: false);
        curationService.refreshTrendingFromAnalytics();
      }
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
      _selectedHashtag = null; // Clear hashtag when exiting
    });
  }
  
  /// Show videos for a specific hashtag
  void showHashtagVideos(String hashtag) async {
    Log.debug('📍 Showing hashtag videos for: #$hashtag', name: 'ExploreScreen', category: LogCategory.ui);
    
    // Switch to trending tab for hashtag display
    _tabController.animateTo(2);
    
    setState(() {
      _selectedHashtag = hashtag;
    });
    
    // Subscribe to hashtag videos and wait for them to load
    final hashtagService = Provider.of<HashtagService>(context, listen: false);
    await hashtagService.subscribeToHashtagVideos([hashtag]);
    
    // Force a rebuild after subscription is established
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    
    // Pause any playing videos - but only if context is still mounted
    if (mounted) {
      try {
        final exploreVideoManager = Provider.of<ExploreVideoManager>(context, listen: false);
        exploreVideoManager.pauseAllVideos();
      } catch (e) {
        // Ignore errors when context is no longer valid
      }
    }
    
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
      appBar: _isInFeedMode 
          ? AppBar(
              backgroundColor: VineTheme.vineGreen,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
                onPressed: _exitFeedMode,
              ),
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
            )
          : AppBar(
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
          // No overlay needed - feed mode handles video playback directly
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
            
            // Video content - either grid or feed mode
            Expanded(
              child: _isInFeedMode 
                  ? PageView.builder(
                      scrollDirection: Axis.vertical,
                      itemCount: _currentTabVideos.length,
                      controller: PageController(initialPage: _currentVideoIndex),
                      onPageChanged: (index) {
                        setState(() {
                          _currentVideoIndex = index;
                          _playingVideoId = _currentTabVideos[index].id;
                        });
                        
                        // Preload videos around current position
                        final exploreVideoManager = Provider.of<ExploreVideoManager>(context, listen: false);
                        exploreVideoManager.preloadCollection(CurationSetType.editorsPicks, startIndex: index);
                      },
                      itemBuilder: (context, index) {
                        final video = _currentTabVideos[index];
                        final isActive = index == _currentVideoIndex;
                        
                        return VideoFeedItem(
                          key: ValueKey(video.id),
                          video: video,
                          isActive: isActive,
                        );
                      },
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(1),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width < 600 ? 3 : 
                                       MediaQuery.of(context).size.width < 900 ? 4 : 
                                       MediaQuery.of(context).size.width < 1200 ? 5 : 6,
                        crossAxisSpacing: 1,
                        mainAxisSpacing: 1,
                        childAspectRatio: 1,
                      ),
                      itemCount: editorsPicks.length,
                      itemBuilder: (context, index) {
                        final video = editorsPicks[index];
                        return VideoExploreTile(
                          video: video,
                          isActive: false,
                          onTap: () {
                            _enterFeedMode(editorsPicks, index);
                          },
                          onClose: () {
                            _exitFeedMode();
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


  Widget _buildPopularNow() {
    return Consumer3<ExploreVideoManager, HashtagService, CurationService>(
      builder: (context, exploreVideoManager, hashtagService, curationService, child) {
        // Get trending videos from explore video manager (managed through VideoManager)
        final videos = exploreVideoManager.getVideosForType(CurationSetType.trending);
        
        // DEBUG: Check what's happening with trending data
        final rawTrending = curationService.getVideosForSetType(CurationSetType.trending);
        Log.debug('DEBUG: PopularNow UI update:', name: 'ExploreScreen', category: LogCategory.ui);
        Log.debug('  ExploreVideoManager videos: ${videos.length}', name: 'ExploreScreen', category: LogCategory.ui);
        Log.debug('  CurationService raw trending: ${rawTrending.length}', name: 'ExploreScreen', category: LogCategory.ui);
        Log.debug('  ExploreVideoManager isLoading: ${exploreVideoManager.isLoading}', name: 'ExploreScreen', category: LogCategory.ui);
        Log.debug('  CurationService isLoading: ${curationService.isLoading}', name: 'ExploreScreen', category: LogCategory.ui);
        
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
        
        // Check if we should show feed mode or grid mode
        if (_isInFeedMode) {
          // Full-screen video feed mode
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: _currentTabVideos.length,
            controller: PageController(initialPage: _currentVideoIndex),
            onPageChanged: (index) {
              setState(() {
                _currentVideoIndex = index;
                _playingVideoId = _currentTabVideos[index].id;
              });
              
              // Preload videos around current position
              exploreVideoManager.preloadCollection(CurationSetType.trending, startIndex: index);
            },
            itemBuilder: (context, index) {
              final video = _currentTabVideos[index];
              final isActive = index == _currentVideoIndex;
              
              return VideoFeedItem(
                key: ValueKey(video.id),
                video: video,
                isActive: isActive,
              );
            },
          );
        } else {
          // Grid view mode
          final screenWidth = MediaQuery.of(context).size.width;
          final crossAxisCount = screenWidth < 600 ? 3 : 
                                 screenWidth < 900 ? 4 : 
                                 screenWidth < 1200 ? 5 : 6;
          
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
                isActive: false, // Never active in grid - feed mode handles playback
                onTap: () {
                  _enterFeedMode(videos, index);
                },
                onClose: () {
                  _exitFeedMode();
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
                          Log.debug('� Navigating to hashtag feed from trending (long press): #$hashtag', name: 'ExploreScreen', category: LogCategory.ui);
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
                  : _isInFeedMode 
                      ? PageView.builder(
                          scrollDirection: Axis.vertical,
                          itemCount: _currentTabVideos.length,
                          controller: PageController(initialPage: _currentVideoIndex),
                          onPageChanged: (index) {
                            setState(() {
                              _currentVideoIndex = index;
                              _playingVideoId = _currentTabVideos[index].id;
                            });
                          },
                          itemBuilder: (context, index) {
                            final video = _currentTabVideos[index];
                            final isActive = index == _currentVideoIndex;
                            
                            return VideoFeedItem(
                              key: ValueKey(video.id),
                              video: video,
                              isActive: isActive,
                            );
                          },
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
                                  isActive: false, // Never active in list - feed mode handles playback
                                  onTap: () {
                                    _enterFeedMode(videos, index);
                                  },
                                  onClose: () {
                                    _exitFeedMode();
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