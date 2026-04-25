// ABOUTME: Profile grid view with header, stats, action buttons, and tabbed content
// ABOUTME: Reusable between own profile and others' profile screens

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/blocs/profile_collab_videos/profile_collab_videos_bloc.dart';
import 'package:openvine/blocs/profile_comments/profile_comments_bloc.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/blocs/profile_reposted_videos/profile_reposted_videos_bloc.dart';
import 'package:openvine/blocs/profile_saved_videos/profile_saved_videos_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/profile_tab_index_provider.dart';
import 'package:openvine/widgets/profile/profile_banner_layer.dart';
import 'package:openvine/widgets/profile/profile_collabs_grid.dart';
import 'package:openvine/widgets/profile/profile_comments_grid.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';
import 'package:openvine/widgets/profile/profile_liked_grid.dart';
import 'package:openvine/widgets/profile/profile_reposts_grid.dart';
import 'package:openvine/widgets/profile/profile_saved_grid.dart';
import 'package:openvine/widgets/profile/profile_videos_grid.dart';

/// Profile grid view showing header, stats, action buttons, and tabbed content.
class ProfileGridView extends ConsumerStatefulWidget {
  const ProfileGridView({
    required this.userIdHex,
    required this.isOwnProfile,
    required this.videos,
    this.profile,
    this.profileStats,
    this.displayName,
    this.onEditProfile,
    this.onBack,
    this.onMore,
    this.onOpenClips,
    this.onMessageUser,
    this.onShareProfile,
    this.onBlockedTap,
    this.scrollController,
    this.displayNameHint,
    this.avatarUrlHint,
    this.refreshNotifier,
    this.isLoadingVideos = false,
    this.videoLoadError,
    super.key,
  });

  /// The hex public key of the profile being displayed.
  final String userIdHex;

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  /// Display name for unfollow confirmation (only used for other profiles).
  final String? displayName;

  /// List of videos to display in the videos tab.
  final List<VideoEvent> videos;

  /// Optional profile owned by the parent widget.
  final UserProfile? profile;

  /// Optional cached profile stats owned by the parent widget.
  final ProfileStats? profileStats;

  /// Callback when edit profile is tapped (own profile only).
  final VoidCallback? onEditProfile;

  /// Callback for back navigation (other profiles only).
  final VoidCallback? onBack;

  /// Callback for more options menu (other profiles only).
  final VoidCallback? onMore;

  /// Callback when "Clips" button is tapped (own profile only).
  final VoidCallback? onOpenClips;

  /// Callback when "Message" button is tapped (other profiles only).
  final VoidCallback? onMessageUser;

  /// Callback when share button is tapped.
  final VoidCallback? onShareProfile;

  /// Callback when the Blocked button is tapped (other profiles only).
  final VoidCallback? onBlockedTap;

  /// Optional scroll controller for the NestedScrollView.
  final ScrollController? scrollController;

  /// Optional display name hint for users without Kind 0 profiles (e.g., classic Viners).
  final String? displayNameHint;

  /// Optional avatar URL hint for users without Kind 0 profiles.
  final String? avatarUrlHint;

  /// Notifier that triggers BLoC refresh when its value changes.
  /// Parent should call `notifier.value++` to trigger refresh.
  final ValueNotifier<int>? refreshNotifier;

  /// Whether videos are currently being loaded.
  /// When true and [videos] is empty, shows a loading indicator
  /// in the videos tab instead of the empty state.
  final bool isLoadingVideos;

  /// Error message if video loading failed, shown in the videos tab.
  final String? videoLoadError;

  @override
  ConsumerState<ProfileGridView> createState() => _ProfileGridViewState();
}

class _ProfileGridViewState extends ConsumerState<ProfileGridView>
    with TickerProviderStateMixin {
  late TabController _tabController;

  /// Direct references to BLoCs for refresh capability.
  ProfileLikedVideosBloc? _likedVideosBloc;
  ProfileRepostedVideosBloc? _repostedVideosBloc;
  ProfileCollabVideosBloc? _collabVideosBloc;
  ProfileSavedVideosBloc? _savedVideosBloc;
  ProfileCommentsBloc? _commentsBloc;

  /// Track the userIdHex the BLoCs were created for.
  String? _blocsUserIdHex;

  /// Track which tabs have been synced (lazy loading).
  bool _likedTabSynced = false;
  bool _repostsTabSynced = false;
  bool _collabsTabSynced = false;
  bool _savedTabSynced = false;
  bool _commentsTabSynced = false;

  /// Key attached to the ProfileHeaderWidget so we can measure its height
  /// and compute the tab bar top inset accordingly.
  final GlobalKey _headerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Restore the previously selected tab index (if any) so navigating back
    // from a fullscreen video doesn't drop the user on the Videos tab.
    final restoredIndex =
        ref.read(profileTabIndexProvider)[widget.userIdHex] ?? 0;
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: restoredIndex,
    );
    _tabController.addListener(_onTabChanged);
    widget.refreshNotifier?.addListener(_onRefreshRequested);
  }

  @override
  void didUpdateWidget(ProfileGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNotifier != widget.refreshNotifier) {
      oldWidget.refreshNotifier?.removeListener(_onRefreshRequested);
      widget.refreshNotifier?.addListener(_onRefreshRequested);
    }
  }

  void _onTabChanged() {
    // Trigger rebuild to update SVG icon colors
    if (mounted) setState(() {});

    // Persist the current index so a remount (triggered by navigation
    // transitions that briefly take the URL off the profile route) can
    // restore the user to the tab they were on.
    final notifier = ref.read(profileTabIndexProvider.notifier);
    notifier.state = {
      ...notifier.state,
      widget.userIdHex: _tabController.index,
    };

    _syncCurrentTabIfNeeded();
  }

  /// Dispatch the lazy-load event for the currently selected tab, unless it
  /// has already been synced this session. Extracted so it can also be
  /// triggered after BLoCs are created on first build — [_onTabChanged]
  /// doesn't fire for the initial [TabController] index.
  void _syncCurrentTabIfNeeded() {
    final index = _tabController.index;
    if (index == 1 && !_likedTabSynced && _likedVideosBloc != null) {
      _likedTabSynced = true;
      _likedVideosBloc!.add(const ProfileLikedVideosSyncRequested());
    } else if (index == 2 &&
        !_repostsTabSynced &&
        _repostedVideosBloc != null) {
      _repostsTabSynced = true;
      _repostedVideosBloc!.add(const ProfileRepostedVideosSyncRequested());
    } else if (index == 3) {
      // Own profile: 4th tab is Saved (bookmarks). Other profile: Collabs.
      if (widget.isOwnProfile) {
        if (!_savedTabSynced && _savedVideosBloc != null) {
          _savedTabSynced = true;
          _savedVideosBloc!.add(const ProfileSavedVideosSyncRequested());
        }
      } else {
        if (!_collabsTabSynced && _collabVideosBloc != null) {
          _collabsTabSynced = true;
          _collabVideosBloc!.add(const ProfileCollabVideosFetchRequested());
        }
      }
    } else if (index == 4 && !_commentsTabSynced && _commentsBloc != null) {
      _commentsTabSynced = true;
      _commentsBloc!.add(const ProfileCommentsSyncRequested());
    }
  }

  void _onRefreshRequested() {
    // Dispatch sync events to BLoCs to refresh likes/reposts
    // Only sync tabs that have been viewed (lazy load still applies)
    if (_likedTabSynced) {
      _likedVideosBloc?.add(const ProfileLikedVideosSyncRequested());
    }
    if (_repostsTabSynced) {
      _repostedVideosBloc?.add(const ProfileRepostedVideosSyncRequested());
    }
    if (_collabsTabSynced) {
      _collabVideosBloc?.add(const ProfileCollabVideosFetchRequested());
    }
    if (_savedTabSynced) {
      _savedVideosBloc?.add(const ProfileSavedVideosSyncRequested());
    }
    if (_commentsTabSynced) {
      _commentsBloc?.add(const ProfileCommentsSyncRequested());
    }
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshRequested);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    // Close the BLoCs we created
    _likedVideosBloc?.close();
    _repostedVideosBloc?.close();
    _collabVideosBloc?.close();
    _savedVideosBloc?.close();
    _commentsBloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final followRepository = ref.watch(followRepositoryProvider);
    final likesRepository = ref.watch(likesRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);
    final videosRepository = ref.watch(videosRepositoryProvider);
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final nostrService = ref.watch(nostrServiceProvider);
    final contentBlocklistRepository = ref.watch(
      contentBlocklistRepositoryProvider,
    );
    final currentUserPubkey = nostrService.publicKey;

    // Create BLoCs if not already created, or recreate if userIdHex changed
    // Store references for refresh capability
    if (_blocsUserIdHex != widget.userIdHex) {
      _likedVideosBloc?.close();
      _repostedVideosBloc?.close();
      _collabVideosBloc?.close();
      _savedVideosBloc?.close();
      _commentsBloc?.close();

      // Reset lazy load flags when switching profiles
      _likedTabSynced = false;
      _repostsTabSynced = false;
      _collabsTabSynced = false;
      _savedTabSynced = false;
      _commentsTabSynced = false;

      // Create BLoCs but DON'T sync yet - lazy load when tab is viewed
      // VideosRepository handles cache-first lookups via SQLite localStorage
      _likedVideosBloc = ProfileLikedVideosBloc(
        likesRepository: likesRepository,
        videosRepository: videosRepository,
        currentUserPubkey: currentUserPubkey,
        targetUserPubkey: widget.userIdHex,
      )..add(const ProfileLikedVideosSubscriptionRequested());
      // Sync deferred until user views Liked tab

      _repostedVideosBloc = ProfileRepostedVideosBloc(
        repostsRepository: repostsRepository,
        videosRepository: videosRepository,
        currentUserPubkey: currentUserPubkey,
        targetUserPubkey: widget.userIdHex,
      )..add(const ProfileRepostedVideosSubscriptionRequested());
      // Sync deferred until user views Reposts tab

      // 4th tab: Saved (own profile) or Collabs (other profile).
      // Only create the bloc that will actually be used.
      if (widget.isOwnProfile) {
        _savedVideosBloc = ProfileSavedVideosBloc(
          bookmarkService: ref.read(bookmarkServiceProvider.future),
          videosRepository: videosRepository,
        );
        _collabVideosBloc = null;
      } else {
        _collabVideosBloc = ProfileCollabVideosBloc(
          videosRepository: videosRepository,
          targetUserPubkey: widget.userIdHex,
        );
        _savedVideosBloc = null;
      }
      // Sync deferred until user views the 4th tab

      _commentsBloc = ProfileCommentsBloc(
        commentsRepository: commentsRepository,
        targetUserPubkey: widget.userIdHex,
      );
      // Sync deferred until user views Comments tab

      _blocsUserIdHex = widget.userIdHex;

      // Kick off the lazy sync for the currently selected tab. On a fresh
      // mount this will no-op for tab 0 (videos use [widget.videos] and
      // don't need a bloc sync) and fire the correct sync event for any
      // other restored tab. Deferred to a post-frame callback so we don't
      // emit new BLoC states during this build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncCurrentTabIfNeeded();
      });
    }

    // Build the base widget with the tab BLoCs using .value() to provide
    // our managed instances. The 4th tab's BLoC and child widget differ
    // between own profile (Saved bookmarks) and other profile (Collabs).
    final tabContent = MultiBlocProvider(
      providers: [
        BlocProvider<ProfileLikedVideosBloc>.value(value: _likedVideosBloc!),
        BlocProvider<ProfileRepostedVideosBloc>.value(
          value: _repostedVideosBloc!,
        ),
        if (widget.isOwnProfile)
          BlocProvider<ProfileSavedVideosBloc>.value(value: _savedVideosBloc!)
        else
          BlocProvider<ProfileCollabVideosBloc>.value(
            value: _collabVideosBloc!,
          ),
        BlocProvider<ProfileCommentsBloc>.value(value: _commentsBloc!),
      ],
      child: ColoredBox(
        color: VineTheme.surfaceContainerHigh,
        child: TabBarView(
          controller: _tabController,
          children: [
            ProfileVideosGrid(
              videos: widget.videos,
              userIdHex: widget.userIdHex,
              isLoading: widget.isLoadingVideos,
              errorMessage: widget.videoLoadError,
            ),
            ProfileLikedGrid(isOwnProfile: widget.isOwnProfile),
            ProfileRepostsGrid(isOwnProfile: widget.isOwnProfile),
            if (widget.isOwnProfile)
              const ProfileSavedGrid()
            else
              ProfileCollabsGrid(isOwnProfile: widget.isOwnProfile),
            ProfileCommentsGrid(isOwnProfile: widget.isOwnProfile),
          ],
        ),
      ),
    );

    final content = ClipRRect(
      borderRadius: const .vertical(bottom: .circular(30)),
      child: ColoredBox(
        color: VineTheme.surfaceBackground,
        child: DefaultTabController(
          length: 5,
          child: NestedScrollView(
            controller: widget.scrollController,
            physics: const ClampingScrollPhysics(),
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // Profile Header (GlobalKey for measuring height)
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    ProfileBannerLayer(
                      userIdHex: widget.userIdHex,
                      isOwnProfile: widget.isOwnProfile,
                      profile: widget.profile,
                    ),
                    ProfileHeaderWidget(
                      key: _headerKey,
                      userIdHex: widget.userIdHex,
                      isOwnProfile: widget.isOwnProfile,
                      videoCount: widget.videos.length,
                      profile: widget.profile,
                      profileStats: widget.profileStats,
                      onEditProfile: widget.onEditProfile,
                      onBack: widget.onBack,
                      onMore: widget.onMore,
                      displayNameHint: widget.displayNameHint,
                      avatarUrlHint: widget.avatarUrlHint,
                      displayName: widget.displayName,
                      onOpenClips: widget.onOpenClips,
                      onMessageUser: widget.onMessageUser,
                      onShareProfile: widget.onShareProfile,
                      onBlockedTap: widget.onBlockedTap,
                    ),
                  ],
                ),
              ),

              // Sticky Tab Bar
              _ProfileTabBar(
                controller: _tabController,
                scrollController: widget.scrollController,
                isOwnProfile: widget.isOwnProfile,
                headerKey: _headerKey,
              ),
            ],
            body: tabContent,
          ),
        ),
      ),
    );

    // Provide OthersFollowersBloc only for other profiles so the follow
    // button can optimistically update the followers count after a
    // follow/unfollow action.
    if (!widget.isOwnProfile) {
      return BlocProvider<OthersFollowersBloc>(
        create: (_) => OthersFollowersBloc(
          followRepository: followRepository,
          contentBlocklistRepository: contentBlocklistRepository,
          currentUserPubkey: currentUserPubkey,
        )..add(OthersFollowersListLoadRequested(widget.userIdHex)),
        child: content,
      );
    }

    return content;
  }
}

/// Tab bar with 5 profile tabs (Videos, Liked, Reposts, Saved/Collabs, Comments).
class _ProfileTabBar extends StatefulWidget {
  const _ProfileTabBar({
    required this.controller,
    required this.scrollController,
    required this.isOwnProfile,
    required this.headerKey,
  });

  final TabController controller;
  final ScrollController? scrollController;
  final bool isOwnProfile;
  final GlobalKey headerKey;

  @override
  State<_ProfileTabBar> createState() => _ProfileTabBarState();
}

class _ProfileTabBarState extends State<_ProfileTabBar> {
  double _tabBarTopInset = 0;

  /// Cached safe area top. Refreshed in [didChangeDependencies] when the
  /// surrounding [MediaQuery] changes (rotation, multi-window resize).
  double _safeAreaTop = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _safeAreaTop = MediaQuery.paddingOf(context).top;
  }

  @override
  void didUpdateWidget(_ProfileTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    // Re-measure every tick so that async header updates (profile data
    // arriving, _profileVisible flip) are always reflected in the trigger
    // threshold. findRenderObject().size is O(1) on a mounted widget.
    final headerHeight =
        (widget.headerKey.currentContext?.findRenderObject() as RenderBox?)
            ?.size
            .height;
    if (headerHeight == null || headerHeight == 0) return;

    final triggerScroll = headerHeight - _safeAreaTop;
    final offset = widget.scrollController?.offset ?? 0;

    // Outside the trigger zone the inset is either 0 (above) or the full
    // safe-area top (below). Skip the clamp/setState work when nothing
    // would change.
    if (offset <= triggerScroll) {
      if (_tabBarTopInset != 0) setState(() => _tabBarTopInset = 0);
      return;
    }
    if (offset >= triggerScroll + _safeAreaTop) {
      if (_tabBarTopInset != _safeAreaTop) {
        setState(() => _tabBarTopInset = _safeAreaTop);
      }
      return;
    }

    final newInset = offset - triggerScroll;
    if (newInset != _tabBarTopInset) {
      setState(() => _tabBarTopInset = newInset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        topInset: _tabBarTopInset,
        TabBar(
          controller: widget.controller,
          indicatorColor: VineTheme.tabIndicatorGreen,
          indicatorWeight: 4,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: VineTheme.transparent,
          tabs: [
            _ProfileTab(
              label: 'videos_tab',
              icon: DivineIconName.play,
              isSelected: widget.controller.index == 0,
            ),
            _ProfileTab(
              label: 'liked_tab',
              icon: DivineIconName.heart,
              isSelected: widget.controller.index == 1,
            ),
            _ProfileTab(
              label: 'reposted_tab',
              icon: DivineIconName.repeat,
              isSelected: widget.controller.index == 2,
            ),
            _ProfileTab(
              label: widget.isOwnProfile ? 'saved_tab' : 'collabs_tab',
              icon: widget.isOwnProfile
                  ? DivineIconName.bookmarkSimple
                  : DivineIconName.user,
              isSelected: widget.controller.index == 3,
            ),
            _ProfileTab(
              label: 'comments_tab',
              icon: DivineIconName.chatCircle,
              isSelected: widget.controller.index == 4,
            ),
          ],
        ),
      ),
    );
  }
}

/// Single icon tab for [_ProfileTabBar].
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.label,
    required this.icon,
    required this.isSelected,
  });

  final String label;
  final DivineIconName icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Tab(
      icon: Semantics(
        label: label,
        child: SvgPicture.asset(
          icon.assetPath,
          width: 28,
          height: 28,
          colorFilter: ColorFilter.mode(
            isSelected ? VineTheme.whiteText : VineTheme.onSurfaceMuted,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

/// Sticky tab bar delegate.
///
/// Adds a [topInset] (typically the safe area top) so that when pinned
/// behind the status bar, the tab bar icons sit below the status bar
/// rather than behind it.
///
/// Also renders the 2px [VineTheme.outlineMuted] divider at the bottom of
/// the header. The rounded top corners of the tab content viewport are
/// applied separately, on the body's [ColoredBox] wrapper.
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, {required this.topInset});

  final PreferredSizeWidget _tabBar;
  final double topInset;

  /// Height of the divider line painted between the tab bar and the tile
  /// grid.
  static const double _dividerHeight = 2;

  double get _totalExtent =>
      _tabBar.preferredSize.height + topInset + _dividerHeight;

  @override
  double get minExtent => _totalExtent;

  @override
  double get maxExtent => _totalExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => DecoratedBox(
    decoration: const BoxDecoration(color: VineTheme.surfaceBackground),
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: topInset),
          child: _tabBar,
        ),
        const ColoredBox(
          color: VineTheme.outlineMuted,
          child: SizedBox(height: _dividerHeight, width: double.infinity),
        ),
      ],
    ),
  );

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) =>
      topInset != oldDelegate.topInset || _tabBar != oldDelegate._tabBar;
}
