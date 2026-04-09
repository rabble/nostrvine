// ABOUTME: Pure search screen using revolutionary Riverpod architecture
// ABOUTME: Searches for videos, users, and hashtags using composition architecture

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/mixins/grid_prefetch_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/hashtag_search_view.dart';
import 'package:openvine/widgets/user_search_view.dart';
import 'package:rxdart/rxdart.dart' show StartWithExtension;

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
    with SingleTickerProviderStateMixin, GridPrefetchMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late TabController _tabController;
  late UserSearchBloc _userSearchBloc;
  late HashtagSearchBloc _hashtagSearchBloc;
  late VideoSearchBloc _videoSearchBloc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _userSearchBloc = UserSearchBloc(
      profileRepository: ref.read(profileRepositoryProvider)!,
    );
    _hashtagSearchBloc = HashtagSearchBloc(
      hashtagRepository: ref.read(hashtagRepositoryProvider),
    );
    _videoSearchBloc = VideoSearchBloc(
      videosRepository: ref.read(videosRepositoryProvider),
    );
    _searchController.addListener(_onSearchChanged);

    // Initialize search term from URL if present
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final pageContext = ref.read(pageContextProvider);
        pageContext.whenData((ctx) {
          if (ctx.type == RouteType.search &&
              ctx.searchTerm != null &&
              ctx.searchTerm!.isNotEmpty) {
            _searchController.text = ctx.searchTerm!;
            _dispatchSearch(ctx.searchTerm!);
            Log.info(
              'SearchScreenPure: Initialized with search term: '
              '${ctx.searchTerm}',
              category: LogCategory.video,
            );
          } else {
            _searchFocusNode.requestFocus();
          }
        });
      }
    });

    Log.info('SearchScreenPure: Initialized', category: LogCategory.video);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _tabController.removeListener(_onTabChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    _userSearchBloc.close();
    _hashtagSearchBloc.close();
    _videoSearchBloc.close();
    super.dispose();

    Log.info('SearchScreenPure: Disposed', category: LogCategory.video);
  }

  void _onSearchChanged() {
    _dispatchSearch(_searchController.text.trim());
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging || !mounted) return;
    setState(() {});
  }

  /// Dispatches to all blocs so every tab fetches real results and counters
  /// are accurate immediately.
  void _dispatchSearch(String query) {
    _videoSearchBloc.add(VideoSearchQueryChanged(query));
    _userSearchBloc.add(UserSearchQueryChanged(query));
    _hashtagSearchBloc.add(HashtagSearchQueryChanged(query));
  }

  int _videoCount(VideoSearchState state) => state.videos.length;

  int _userCount(UserSearchState state) => state.results.length;

  int _hashtagCount(HashtagSearchState state) => state.results.length;

  bool _isActiveTabSearching({
    required VideoSearchState videoState,
    required UserSearchState userState,
    required HashtagSearchState hashtagState,
  }) {
    return switch (_tabController.index) {
      0 => videoState.status == VideoSearchStatus.searching,
      1 => userState.status == UserSearchStatus.loading,
      2 => hashtagState.status == HashtagSearchStatus.loading,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Derive feed mode from URL (single source of truth)
    final pageContext = ref.watch(pageContextProvider);
    final isInFeedMode =
        pageContext.whenOrNull(
          data: (ctx) => ctx.type == RouteType.search && ctx.videoIndex != null,
        ) ??
        false;

    // Show fullscreen video player when in feed mode
    if (isInFeedMode) {
      return BlocBuilder<VideoSearchBloc, VideoSearchState>(
        bloc: _videoSearchBloc,
        builder: (context, videoState) {
          return _SearchFeedModeContent(
            key: const Key('search-feed'),
            searchTerm: videoState.query,
          );
        },
      );
    }

    final tabContent = TabBarView(
      controller: _tabController,
      children: const [_VideosTab(), UserSearchView(), HashtagSearchView()],
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _userSearchBloc),
        BlocProvider.value(value: _hashtagSearchBloc),
        BlocProvider.value(value: _videoSearchBloc),
      ],
      child: BlocBuilder<VideoSearchBloc, VideoSearchState>(
        bloc: _videoSearchBloc,
        builder: (context, videoState) {
          return BlocBuilder<UserSearchBloc, UserSearchState>(
            bloc: _userSearchBloc,
            builder: (context, userSearchState) {
              return BlocBuilder<HashtagSearchBloc, HashtagSearchState>(
                bloc: _hashtagSearchBloc,
                builder: (context, hashtagSearchState) {
                  final searchBar = DivineSearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    isLoading: _isActiveTabSearching(
                      videoState: videoState,
                      userState: userSearchState,
                      hashtagState: hashtagSearchState,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const DivineIcon(
                              icon: .x,
                              color: VineTheme.whiteText,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _userSearchBloc.add(const UserSearchCleared());
                              _hashtagSearchBloc.add(
                                const HashtagSearchCleared(),
                              );
                              _videoSearchBloc.add(const VideoSearchCleared());
                            },
                          )
                        : null,
                  );
                  final textScaler = MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.35);
                  final tabBar = MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: textScaler),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      padding: const EdgeInsets.only(left: 16),
                      indicatorColor: VineTheme.tabIndicatorGreen,
                      indicatorWeight: 4,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: VineTheme.transparent,
                      labelColor: VineTheme.whiteText,
                      unselectedLabelColor: VineTheme.tabIconInactive,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                      labelStyle: VineTheme.tabTextStyle(),
                      unselectedLabelStyle: VineTheme.tabTextStyle(
                        color: VineTheme.tabIconInactive,
                      ),
                      tabs: [
                        Tab(text: 'Videos (${_videoCount(videoState)})'),
                        Tab(text: 'Users (${_userCount(userSearchState)})'),
                        Tab(
                          text:
                              'Hashtags (${_hashtagCount(hashtagSearchState)})',
                        ),
                      ],
                    ),
                  );

                  final body = BlocListener<VideoSearchBloc, VideoSearchState>(
                    bloc: _videoSearchBloc,
                    listener: (context, state) {
                      ref.read(searchScreenVideosProvider.notifier).state =
                          state.videos;
                      if (state.videos.isNotEmpty) {
                        prefetchGridVideos(state.videos);
                      }
                    },
                    child: widget.embedded
                        ? Material(
                            color: VineTheme.backgroundColor,
                            child: Column(
                              children: [
                                Container(
                                  color: VineTheme.navGreen,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: searchBar,
                                ),
                                ColoredBox(
                                  color: VineTheme.navGreen,
                                  child: tabBar,
                                ),
                                Expanded(child: tabContent),
                              ],
                            ),
                          )
                        : Scaffold(
                            backgroundColor: VineTheme.backgroundColor,
                            appBar: DiVineAppBar(
                              title: '',
                              titleWidget: searchBar,
                              showBackButton: true,
                              onBackPressed: context.pop,
                              backButtonSemanticLabel: 'search_back_button',
                              backgroundColor: VineTheme.cardBackground,
                              bottom: PreferredSize(
                                preferredSize: const Size.fromHeight(48),
                                child: tabBar,
                              ),
                            ),
                            body: tabContent,
                          ),
                  );

                  return body;
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _VideosTab extends StatelessWidget {
  const _VideosTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoSearchBloc, VideoSearchState>(
      builder: (context, state) {
        if (state.status == VideoSearchStatus.searching &&
            state.videos.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          );
        }

        if (state.query.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 64, color: VineTheme.secondaryText),
                SizedBox(height: 16),
                Text(
                  'Search for videos',
                  style: TextStyle(color: VineTheme.primaryText, fontSize: 18),
                ),
                Text(
                  'Enter keywords, hashtags, or user names',
                  style: TextStyle(color: VineTheme.secondaryText),
                  textAlign: .center,
                ),
              ],
            ),
          );
        }

        return ComposableVideoGrid(
          key: const Key('search-videos-grid'),
          videos: state.videos,
          onVideoTap: (videos, index) {
            Log.info(
              'SearchScreenPure: Tapped video at index $index',
              category: LogCategory.video,
            );
            context.go(
              SearchScreenPure.pathForTerm(
                term: state.query.isNotEmpty ? state.query : null,
                index: index,
              ),
            );
          },
          emptyBuilder: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.video_library,
                  size: 64,
                  color: VineTheme.secondaryText,
                ),
                const SizedBox(height: 16),
                Text(
                  'No videos found for "${state.query}"',
                  style: const TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchFeedModeContent extends ConsumerStatefulWidget {
  const _SearchFeedModeContent({required this.searchTerm, super.key});

  final String searchTerm;

  @override
  ConsumerState<_SearchFeedModeContent> createState() =>
      _SearchFeedModeContentState();
}

class _SearchFeedModeContentState
    extends ConsumerState<_SearchFeedModeContent> {
  late final StreamController<List<VideoEvent>> _streamController;
  List<VideoEvent>? _lastVideos;

  @override
  void initState() {
    super.initState();
    _streamController = StreamController<List<VideoEvent>>.broadcast();
  }

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }

  void _pushVideos(List<VideoEvent> videos) {
    if (videos.isEmpty) return;
    if (identical(videos, _lastVideos)) return;
    _lastVideos = videos;
    if (!_streamController.isClosed) _streamController.add(videos);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(divineHostFilterVersionProvider);
    final videoEventService = ref.read(videoEventServiceProvider);
    final videos = videoEventService.filterVideoList(
      ref.watch(searchScreenVideosProvider) ?? const <VideoEvent>[],
    );
    final pageContext = ref.watch(pageContextProvider);
    final startIndex =
        pageContext.whenOrNull(data: (ctx) => ctx.videoIndex ?? 0) ?? 0;

    if (videos.isEmpty) {
      return const ColoredBox(
        color: VineTheme.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }

    _pushVideos(videos);

    final safeIndex = startIndex.clamp(0, videos.length - 1);

    return PooledFullscreenVideoFeedScreen(
      videosStream: _streamController.stream.startWith(videos),
      initialIndex: safeIndex,
      contextTitle: 'Search',
      onPageChanged: (index) {
        context.go(
          SearchScreenPure.pathForTerm(
            term: widget.searchTerm.isNotEmpty ? widget.searchTerm : null,
            index: index,
          ),
        );
      },
    );
  }
}
