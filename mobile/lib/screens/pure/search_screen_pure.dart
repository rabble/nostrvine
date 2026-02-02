// ABOUTME: Pure search screen using revolutionary Riverpod architecture
// ABOUTME: Searches for videos, users, and hashtags using composition architecture

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/search_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Pure search screen using revolutionary single-controller Riverpod architecture
class SearchScreenPure extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'search';

  /// Path for this route.
  static const path = '/search';

  /// Path for this route with term.
  static const pathWithTerm = '/search/:searchTerm';

  /// Path for this route with index.
  static const pathWithIndex = '/search/:index';

  /// Path for this route with term and index.
  static const pathWithTermAndIndex = '/search/:searchTerm/:index';

  /// Build path for grid mode or specific index.
  static String pathForTerm({String? term, int? index}) {
    if (term == null) {
      if (index == null) return path;
      return '$path/$index';
    }
    final encodedTerm = Uri.encodeComponent(term);
    if (index == null) return '$path/$encodedTerm';
    return '$path/$encodedTerm/$index';
  }

  const SearchScreenPure({super.key, this.embedded = false});

  final bool
  embedded; // When true, renders without Scaffold/AppBar (for embedding in ExploreScreen)

  @override
  ConsumerState<SearchScreenPure> createState() => _SearchScreenPureState();
}

class _SearchScreenPureState extends ConsumerState<SearchScreenPure>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late TabController _tabController;

  List<VideoEvent> _videoResults = [];
  List<String> _userResults = [];
  List<String> _hashtagResults = [];

  bool _isSearching = false;
  bool _isSearchingExternal = false;
  bool _isSearchingWebSocket = false; // Track WebSocket search phase separately
  String _currentQuery = '';
  Timer? _debounceTimer;
  int _searchGeneration = 0; // Prevents race conditions between search phases

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);

    // Initialize search term from URL if present
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final pageContext = ref.read(pageContextProvider);
        pageContext.whenData((ctx) {
          if (ctx.type == RouteType.search &&
              ctx.searchTerm != null &&
              ctx.searchTerm!.isNotEmpty) {
            // Set search controller text and trigger search
            // Pass updateUrl: false to avoid infinite loop during initialization
            _searchController.text = ctx.searchTerm!;
            _performSearch(ctx.searchTerm!, updateUrl: false);
            Log.info(
              '🔍 SearchScreenPure: Initialized with search term: ${ctx.searchTerm}',
              category: LogCategory.video,
            );
          } else {
            // Request focus for empty search
            _searchFocusNode.requestFocus();
          }
        });
      }
    });

    Log.info('🔍 SearchScreenPure: Initialized', category: LogCategory.video);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    _debounceTimer?.cancel();
    super.dispose();

    Log.info('🔍 SearchScreenPure: Disposed', category: LogCategory.video);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (query == _currentQuery) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _performSearch(query);
      }
    });
  }

  void _performSearch(String query, {bool updateUrl = true}) async {
    if (query.isEmpty) {
      setState(() {
        _videoResults = [];
        _userResults = [];
        _hashtagResults = [];
        _isSearching = false;
        _currentQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _currentQuery = query;
    });

    Log.info(
      '🔍 SearchScreenPure: Local search for: $query',
      category: LogCategory.video,
    );

    try {
      final videoEventService = ref.read(videoEventServiceProvider);
      final videos = videoEventService.discoveryVideos;
      final profileService = ref.read(userProfileServiceProvider);
      final blocklistService = ref.read(contentBlocklistServiceProvider);

      Log.debug(
        '🔍 SearchScreenPure: Filtering ${videos.length} cached videos',
        category: LogCategory.video,
      );

      final users = <String>{};

      // Use fuzzy search and filter out blocked users
      final matchingProfiles = SearchUtils.searchProfiles(
        query,
        profileService.allProfiles.values.where(
          (p) => !blocklistService.shouldFilterFromFeeds(p.pubkey),
        ),
        minScore: 0.3,
        limit: 50,
      );

      _userResults.addAll(matchingProfiles.map((p) => p.pubkey));

      final filteredVideos = videos.where((video) {
        // Filter out blocked users first
        if (blocklistService.shouldFilterFromFeeds(video.pubkey)) {
          return false;
        }

        final creatorName = profileService.getDisplayName(video.pubkey);
        final score = SearchUtils.matchVideo(
          query: query,
          title: video.title,
          content: video.content,
          hashtags: video.hashtags,
          creatorName: creatorName,
        );
        return score >= 0.3;
      }).toList();

      final hashtags = <String>{};

      for (final video in filteredVideos) {
        for (final tag in video.hashtags) {
          if (tag.toLowerCase().contains(query.toLowerCase())) {
            hashtags.add(tag);
          }
        }
        if (!blocklistService.shouldFilterFromFeeds(video.pubkey)) {
          users.add(video.pubkey);
        }
      }

      filteredVideos.sort(VideoEvent.compareByLoopsThenTime);

      if (mounted) {
        setState(() {
          _videoResults = filteredVideos;
          _hashtagResults = hashtags.take(20).toList();
          _userResults = users.take(20).toList();
          _isSearching = false;
        });
        ref.read(searchScreenVideosProvider.notifier).state = filteredVideos;
      }

      Log.info(
        '🔍 SearchScreenPure: Local results: ${filteredVideos.length} videos',
        category: LogCategory.video,
      );

      unawaited(_searchExternalRelays());
    } catch (e) {
      Log.error(
        '🔍 SearchScreenPure: Local search failed: $e',
        category: LogCategory.video,
      );

      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  /// Search external sources for more results
  ///
  /// Strategy: Try Funnelcake REST API first (fast), then WebSocket NIP-50 (slower)
  /// Results flow incrementally - REST results appear first, WS results merge in
  ///
  /// Uses a generation counter to prevent race conditions when queries change
  /// mid-search - stale results from old queries are discarded.
  Future<void> _searchExternalRelays() async {
    if (_currentQuery.isEmpty || _isSearchingExternal) return;

    // Increment generation to invalidate any in-flight searches
    final generation = ++_searchGeneration;

    setState(() {
      _isSearchingExternal = true;
    });

    final querySnapshot = _currentQuery;
    final blocklistService = ref.read(contentBlocklistServiceProvider);
    final profileService = ref.read(userProfileServiceProvider);

    // Helper to check if this search is still valid
    bool isSearchStale() => !mounted || _searchGeneration != generation;

    // Check if Funnelcake REST API is available
    final funnelcakeAvailable =
        ref.read(funnelcakeAvailableProvider).asData?.value ?? false;

    Log.info(
      '🔍 SearchScreenPure: External search for "$querySnapshot" '
      '(funnelcake: $funnelcakeAvailable)',
      category: LogCategory.video,
    );

    // ===== PHASE 1: Funnelcake REST API (fast) =====
    if (funnelcakeAvailable) {
      try {
        final analyticsService = ref.read(analyticsApiServiceProvider);

        Log.debug(
          '🔍 SearchScreenPure: Trying Funnelcake REST search...',
          category: LogCategory.video,
        );

        final restResults = await analyticsService.searchVideos(
          query: querySnapshot,
          limit: 100,
        );

        // Filter out blocked users
        final filteredRestResults = restResults
            .where(
              (video) => !blocklistService.shouldFilterFromFeeds(video.pubkey),
            )
            .toList();

        if (filteredRestResults.isNotEmpty && !isSearchStale()) {
          // Merge REST results with local results
          _mergeAndUpdateResults(
            newVideos: filteredRestResults,
            blocklistService: blocklistService,
            profileService: profileService,
            querySnapshot: querySnapshot,
            generation: generation,
          );

          Log.info(
            '🔍 SearchScreenPure: REST search returned '
            '${filteredRestResults.length} results',
            category: LogCategory.video,
          );
        }
      } catch (e) {
        Log.warning(
          '🔍 SearchScreenPure: REST search failed, continuing to WebSocket: $e',
          category: LogCategory.video,
        );
      }
    }

    // ===== PHASE 2: WebSocket NIP-50 search (slower, more comprehensive) =====
    // Always run WebSocket search to catch results not in Funnelcake
    if (!isSearchStale()) {
      setState(() {
        _isSearchingWebSocket = true;
      });

      try {
        final videoEventService = ref.read(videoEventServiceProvider);

        Log.debug(
          '🔍 SearchScreenPure: Starting WebSocket NIP-50 search...',
          category: LogCategory.video,
        );

        // Search external relays via NIP-50
        await videoEventService.searchVideos(querySnapshot, limit: 100);

        final wsResults = videoEventService.searchResults
            .where(
              (video) => !blocklistService.shouldFilterFromFeeds(video.pubkey),
            )
            .toList();

        // Also search for users via WebSocket
        await profileService.searchUsers(querySnapshot, limit: 100);

        // Use fuzzy search and filter out blocked users
        final matchingRemoteUsers = SearchUtils.searchProfiles(
          querySnapshot,
          profileService.allProfiles.values.where(
            (p) => !blocklistService.shouldFilterFromFeeds(p.pubkey),
          ),
          minScore: 0.3,
          limit: 50,
        ).map((p) => p.pubkey).toList();

        if (!isSearchStale()) {
          // Merge WebSocket results
          _mergeAndUpdateResults(
            newVideos: wsResults,
            newUsers: matchingRemoteUsers,
            blocklistService: blocklistService,
            profileService: profileService,
            querySnapshot: querySnapshot,
            generation: generation,
          );

          Log.info(
            '🔍 SearchScreenPure: WebSocket search returned '
            '${wsResults.length} results',
            category: LogCategory.video,
          );
        }
      } catch (e) {
        // Use warning level since this is recoverable - partial results may exist
        Log.warning(
          '🔍 SearchScreenPure: WebSocket search failed: $e',
          category: LogCategory.video,
        );
      }
    }

    // ===== Complete =====
    if (mounted) {
      setState(() {
        _isSearchingExternal = false;
        _isSearchingWebSocket = false;
      });

      Log.info(
        '🔍 SearchScreenPure: External search complete '
        '(total: ${_videoResults.length} videos)',
        category: LogCategory.video,
      );
    }
  }

  /// Merge new results with existing results and update UI
  ///
  /// Uses generation counter to ensure we don't update UI with stale results
  /// from a previous search that completed after the user changed queries.
  void _mergeAndUpdateResults({
    required List<VideoEvent> newVideos,
    List<String>? newUsers,
    required ContentBlocklistService blocklistService,
    required UserProfileService profileService,
    required String querySnapshot,
    required int generation,
  }) {
    // Check if this search is still valid before updating
    if (!mounted || _searchGeneration != generation) {
      Log.debug(
        '🔍 SearchScreenPure: Discarding stale results for "$querySnapshot"',
        category: LogCategory.video,
      );
      return;
    }

    // Combine existing + new results
    final allVideos = [..._videoResults, ...newVideos];

    // Deduplicate by video ID
    final seenIds = <String>{};
    final uniqueVideos = allVideos.where((video) {
      if (seenIds.contains(video.id)) return false;
      seenIds.add(video.id);
      return true;
    }).toList();

    // Sort: by loops then time
    uniqueVideos.sort(VideoEvent.compareByLoopsThenTime);

    // Extract all unique hashtags and users from combined results
    final allHashtags = <String>{};
    final allUsers = <String>{..._userResults};
    if (newUsers != null) {
      allUsers.addAll(newUsers);
    }

    for (final video in uniqueVideos) {
      for (final tag in video.hashtags) {
        if (tag.toLowerCase().contains(querySnapshot.toLowerCase())) {
          allHashtags.add(tag);
        }
      }
      if (!blocklistService.shouldFilterFromFeeds(video.pubkey)) {
        allUsers.add(video.pubkey);
      }
    }

    setState(() {
      _videoResults = uniqueVideos;
      _hashtagResults = allHashtags.take(20).toList();
      _userResults = allUsers.take(20).toList();
    });
    // Update provider so active video system can access merged search results
    ref.read(searchScreenVideosProvider.notifier).state = uniqueVideos;
  }

  @override
  Widget build(BuildContext context) {
    final pageContext = ref.watch(pageContextProvider);
    final isInFeedMode = pageContext.maybeWhen(
      data: (ctx) => ctx.type == RouteType.search && ctx.videoIndex != null,
      orElse: () => false,
    );

    if (isInFeedMode && _videoResults.isNotEmpty) {
      final videoIndex = pageContext.asData?.value.videoIndex ?? 0;
      final safeIndex = videoIndex.clamp(0, _videoResults.length - 1);

      return ExploreVideoScreenPure(
        startingVideo: _videoResults[safeIndex],
        videoList: _videoResults,
        contextTitle: 'Search: $_currentQuery',
        startingIndex: safeIndex,
        // No onBackToGrid needed - AppShell's AppBar back button handles this
      );
    }

    // Otherwise show search grid UI
    final searchBar = SizedBox(
      height: 48,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: const TextStyle(color: VineTheme.whiteText),
        decoration: InputDecoration(
          hintText: 'Find something cool...',
          hintStyle: TextStyle(
            color: VineTheme.whiteText.withValues(alpha: 0.6),
          ),
          filled: true,
          fillColor: VineTheme.iconButtonBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: _isSearching
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: Padding(
                      padding: EdgeInsets.all(2),
                      child: CircularProgressIndicator(
                        color: VineTheme.vineGreen,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : SvgPicture.asset(
                    'assets/icon/search.svg',
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF818E8A),
                      BlendMode.srcIn,
                    ),
                  ),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: VineTheme.whiteText),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : null,
        ),
      ),
    );

    final tabBar = TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: const EdgeInsets.only(left: 16),
      indicatorColor: VineTheme.tabIndicatorGreen,
      indicatorWeight: 4,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelColor: VineTheme.whiteText,
      unselectedLabelColor: VineTheme.tabIconInactive,
      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
      labelStyle: VineTheme.tabTextStyle(),
      unselectedLabelStyle: VineTheme.tabTextStyle(
        color: VineTheme.tabIconInactive,
      ),
      tabs: [
        Tab(text: 'Videos (${_videoResults.length})'),
        Tab(text: 'Users (${_userResults.length})'),
        Tab(text: 'Hashtags (${_hashtagResults.length})'),
      ],
    );

    final tabContent = TabBarView(
      controller: _tabController,
      children: [_buildVideosTab(), _buildUsersTab(), _buildHashtagsTab()],
    );

    // Embedded mode: return content without scaffold
    if (widget.embedded) {
      return Container(
        color: VineTheme.backgroundColor, // Ensure visible background
        child: Column(
          children: [
            Container(
              color: VineTheme.navGreen,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: searchBar,
            ),
            Container(color: VineTheme.navGreen, child: tabBar),
            Expanded(child: tabContent),
          ],
        ),
      );
    }

    // Standalone mode: return full scaffold with app bar
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.cardBackground,
        leading: Semantics(
          identifier: 'search_back_button',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
            onPressed: context.pop,
          ),
        ),
        title: searchBar,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: tabBar,
        ),
      ),
      body: tabContent,
    );
  }

  Widget _buildVideosTab() {
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      );
    }

    if (_currentQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'Search for videos',
              style: TextStyle(color: VineTheme.primaryText, fontSize: 18),
            ),
            Text(
              'Enter keywords, hashtags, or user names',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Show search status indicator
        if (_isSearchingExternal)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: VineTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: VineTheme.vineGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VineTheme.vineGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isSearchingWebSocket
                            ? 'Searching Nostr relays...'
                            : 'Searching servers...',
                        style: TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_videoResults.isNotEmpty)
                        Text(
                          '${_videoResults.length} results found',
                          style: TextStyle(
                            color: VineTheme.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Video grid
        Expanded(
          child: ComposableVideoGrid(
            key: const Key('search-videos-grid'),
            videos: _videoResults,
            onVideoTap: (videos, index) {
              Log.info(
                '🔍 SearchScreenPure: Tapped video at index $index',
                category: LogCategory.video,
              );
              // Navigate using GoRouter to enable router-driven video playback
              context.go(
                SearchScreenPure.pathForTerm(
                  term: _currentQuery.isNotEmpty ? _currentQuery : null,
                  index: index,
                ),
              );
            },
            emptyBuilder: () => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library,
                    size: 64,
                    color: VineTheme.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSearchingExternal
                        ? 'Searching servers for "$_currentQuery"...'
                        : 'No videos found for "$_currentQuery"',
                    style: TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      );
    }

    if (_currentQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'Search for users',
              style: TextStyle(color: VineTheme.primaryText, fontSize: 18),
            ),
            Text(
              'Find content creators and friends',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          ],
        ),
      );
    }

    if (_userResults.isEmpty && !_isSearchingExternal) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'No users found for "$_currentQuery"',
              style: TextStyle(color: VineTheme.primaryText, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or check spelling',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Sort users: those with display names first, unnamed users last
    final sortedUsers = List<String>.from(_userResults);
    final profileService = ref.watch(userProfileServiceProvider);

    sortedUsers.sort((a, b) {
      final profileA = profileService.getCachedProfile(a);
      final profileB = profileService.getCachedProfile(b);

      final hasNameA =
          profileA?.bestDisplayName != null &&
          !profileA!.bestDisplayName.startsWith('npub') &&
          !profileA.bestDisplayName.startsWith('@');
      final hasNameB =
          profileB?.bestDisplayName != null &&
          !profileB!.bestDisplayName.startsWith('npub') &&
          !profileB.bestDisplayName.startsWith('@');

      // Users with names come first
      if (hasNameA && !hasNameB) return -1;
      if (!hasNameA && hasNameB) return 1;
      return 0;
    });

    return Column(
      children: [
        // Show search status indicator for users
        if (_isSearchingExternal)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: VineTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: VineTheme.vineGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VineTheme.vineGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Searching for more users...',
                    style: TextStyle(color: VineTheme.whiteText, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        // User list
        Expanded(
          child: sortedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: VineTheme.vineGreen,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Searching for "$_currentQuery"...',
                        style: TextStyle(
                          color: VineTheme.primaryText,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedUsers.length,
                  itemBuilder: (context, index) {
                    final userPubkey = sortedUsers[index];

                    return UserProfileTile(
                      pubkey: userPubkey,
                      showFollowButton: false,
                      onTap: () {
                        Log.info(
                          '🔍 SearchScreenPure: Tapped user: $userPubkey',
                          category: LogCategory.video,
                        );
                        context.pushOtherProfile(userPubkey);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHashtagsTab() {
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      );
    }

    if (_currentQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tag, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'Search for hashtags',
              style: TextStyle(color: VineTheme.primaryText, fontSize: 18),
            ),
            Text(
              'Discover trending topics and content',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          ],
        ),
      );
    }

    if (_hashtagResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tag_outlined, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'No hashtags found for "$_currentQuery"',
              style: TextStyle(color: VineTheme.primaryText, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _hashtagResults.length,
      itemBuilder: (context, index) {
        final hashtag = _hashtagResults[index];
        return Card(
          color: VineTheme.cardBackground,
          child: ListTile(
            leading: Icon(Icons.tag, color: VineTheme.vineGreen),
            title: Text(
              '#$hashtag',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Tap to view videos with this hashtag',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
            onTap: () {
              Log.info(
                '🔍 SearchScreenPure: Tapped hashtag: $hashtag',
                category: LogCategory.video,
              );
              // Navigate using GoRouter
              context.go(HashtagScreenRouter.pathForTag(hashtag));
            },
          ),
        );
      },
    );
  }
}
