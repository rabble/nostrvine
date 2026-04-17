// ABOUTME: Profile grid view with header, stats, action buttons, and tabbed content
// ABOUTME: Reusable between own profile and others' profile screens

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_followers/my_followers_bloc.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/blocs/profile_collab_videos/profile_collab_videos_bloc.dart';
import 'package:openvine/blocs/profile_comments/profile_comments_bloc.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/blocs/profile_reposted_videos/profile_reposted_videos_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/widgets/profile/profile_action_buttons_widget.dart';
import 'package:openvine/widgets/profile/profile_banner_layer.dart';
import 'package:openvine/widgets/profile/profile_collabs_grid.dart';
import 'package:openvine/widgets/profile/profile_comments_grid.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';
import 'package:openvine/widgets/profile/profile_liked_grid.dart';
import 'package:openvine/widgets/profile/profile_reposts_grid.dart';
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
  ProfileCommentsBloc? _commentsBloc;

  /// Track the userIdHex the BLoCs were created for.
  String? _blocsUserIdHex;

  /// Track which tabs have been synced (lazy loading).
  bool _likedTabSynced = false;
  bool _repostsTabSynced = false;
  bool _collabsTabSynced = false;
  bool _commentsTabSynced = false;

  /// Key attached to the ProfileHeaderWidget so we can measure its height
  /// and position the action buttons layer accordingly.
  final GlobalKey _headerKey = GlobalKey();

  /// Measured height of the profile header (variable based on bio length,
  /// name, nip-05 presence, etc.). Updated after each build.
  double _headerHeight = 0;

  /// Screen-space Y position of the action buttons layer's top edge.
  /// Drives the ProfileActionButtonsLayer's Positioned widget.
  final ValueNotifier<double> _actionButtonsTop = ValueNotifier<double>(0);

  /// Fixed height of the action buttons row (matches the spacer inside the
  /// NestedScrollView).
  static const double _actionButtonsHeight = 80;

  /// Dynamic top inset for the pinned tab bar, grows from 0 to safeAreaTop
  /// as the action buttons row's bottom edge scrolls past the safe area.
  /// At rest: 0 (no gap between action buttons and tab icons).
  /// When pinned: safeAreaTop (tab icons stay below the status bar).
  double _tabBarTopInset = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    widget.refreshNotifier?.addListener(_onRefreshRequested);
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ProfileGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNotifier != widget.refreshNotifier) {
      oldWidget.refreshNotifier?.removeListener(_onRefreshRequested);
      widget.refreshNotifier?.addListener(_onRefreshRequested);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
  }

  /// Recompute the action buttons layer's screen Y on scroll or resize.
  ///
  /// The overlay sits at `_headerHeight - scrollOffset` (at rest, right at
  /// the header's bottom — no gap above). The overlay's container is
  /// [_actionButtonsHeight] + safeAreaTop tall: the top 80px hold the
  /// ProfileActionButtons widget, and the bottom safeAreaTop covers the
  /// tab bar's top safeAreaTop padding area (CSS z-index equivalent).
  void _onScroll() {
    final offset = widget.scrollController?.offset ?? 0;

    // Clamp the action buttons overlay so its bottom edge stops at the
    // screen top (Y=0). Flutter's NestedScrollView includes the pinned
    // tab bar's height in the outer scroll extent, so the outer can
    // continue past the natural "action buttons off screen" point — let
    // it, so the inner scroll (tab content) can take over properly. We
    // just freeze the overlay visually at its minimum position.
    final rawTop = _headerHeight - offset;
    final top = rawTop.clamp(-_actionButtonsHeight, double.infinity);
    _actionButtonsTop.value = top;

    // Dynamic tab bar top inset. Grows from 0 to safeAreaTop as the
    // action buttons row's bottom edge scrolls past the safe area.
    final safeAreaTop = MediaQuery.paddingOf(context).top;
    final triggerScroll =
        _headerHeight + _actionButtonsHeight - safeAreaTop;
    final newInset = (offset - triggerScroll).clamp(0.0, safeAreaTop);
    if (newInset != _tabBarTopInset) {
      setState(() {
        _tabBarTopInset = newInset;
      });
    }
  }

  void _onTabChanged() {
    // Trigger rebuild to update SVG icon colors
    if (mounted) setState(() {});

    // Lazy load: Trigger sync only when user first views the tab
    if (_tabController.index == 1 &&
        !_likedTabSynced &&
        _likedVideosBloc != null) {
      _likedTabSynced = true;
      _likedVideosBloc!.add(const ProfileLikedVideosSyncRequested());
    } else if (_tabController.index == 2 &&
        !_repostsTabSynced &&
        _repostedVideosBloc != null) {
      _repostsTabSynced = true;
      _repostedVideosBloc!.add(const ProfileRepostedVideosSyncRequested());
    } else if (_tabController.index == 3 &&
        !_collabsTabSynced &&
        _collabVideosBloc != null) {
      _collabsTabSynced = true;
      _collabVideosBloc!.add(const ProfileCollabVideosFetchRequested());
    } else if (_tabController.index == 4 &&
        !_commentsTabSynced &&
        _commentsBloc != null) {
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
    if (_commentsTabSynced) {
      _commentsBloc?.add(const ProfileCommentsSyncRequested());
    }
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshRequested);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    widget.scrollController?.removeListener(_onScroll);
    _actionButtonsTop.dispose();
    // Close the BLoCs we created
    _likedVideosBloc?.close();
    _repostedVideosBloc?.close();
    _collabVideosBloc?.close();
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
    final contentBlocklistService = ref.watch(contentBlocklistServiceProvider);
    final currentUserPubkey = nostrService.publicKey;

    // Create BLoCs if not already created, or recreate if userIdHex changed
    // Store references for refresh capability
    if (_blocsUserIdHex != widget.userIdHex) {
      _likedVideosBloc?.close();
      _repostedVideosBloc?.close();
      _collabVideosBloc?.close();
      _commentsBloc?.close();

      // Reset lazy load flags when switching profiles
      _likedTabSynced = false;
      _repostsTabSynced = false;
      _collabsTabSynced = false;
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

      _collabVideosBloc = ProfileCollabVideosBloc(
        videosRepository: videosRepository,
        targetUserPubkey: widget.userIdHex,
      );
      // Fetch deferred until user views Collabs tab

      _commentsBloc = ProfileCommentsBloc(
        commentsRepository: commentsRepository,
        targetUserPubkey: widget.userIdHex,
      );
      // Sync deferred until user views Comments tab

      _blocsUserIdHex = widget.userIdHex;
    }

    // Build the base widget with ProfileLikedVideosBloc and
    // ProfileRepostedVideosBloc using .value() to provide our managed instances
    final tabContent = MultiBlocProvider(
      providers: [
        BlocProvider<ProfileLikedVideosBloc>.value(value: _likedVideosBloc!),
        BlocProvider<ProfileRepostedVideosBloc>.value(
          value: _repostedVideosBloc!,
        ),
        BlocProvider<ProfileCollabVideosBloc>.value(value: _collabVideosBloc!),
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
            ProfileCollabsGrid(isOwnProfile: widget.isOwnProfile),
            ProfileCommentsGrid(isOwnProfile: widget.isOwnProfile),
          ],
        ),
      ),
    );

    Widget content = DefaultTabController(
      length: 5,
      child: NestedScrollView(
        controller: widget.scrollController,
        physics: const ClampingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Profile Header (GlobalKey for measuring height)
          SliverToBoxAdapter(
            child: ProfileHeaderWidget(
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
            ),
          ),

          // Action Buttons spacer: preserves scroll extent while the actual
          // action buttons are rendered in the outer Stack (so they can
          // paint on top of the tab bar's top safeAreaTop padding area).
          const SliverToBoxAdapter(
            child: SizedBox(height: _actionButtonsHeight),
          ),

          // Sticky Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              topInset: _tabBarTopInset,
              TabBar(
                controller: _tabController,
                indicatorColor: VineTheme.tabIndicatorGreen,
                indicatorWeight: 4,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: VineTheme.transparent,
                tabs: [
                  Tab(
                    icon: Semantics(
                      label: 'videos_tab',
                      child: SvgPicture.asset(
                        DivineIconName.play.assetPath,
                        width: 28,
                        height: 28,
                        colorFilter: ColorFilter.mode(
                          _tabController.index == 0
                              ? VineTheme.whiteText
                              : VineTheme.onSurfaceMuted,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  Tab(
                    icon: Semantics(
                      label: 'liked_tab',
                      child: SvgPicture.asset(
                        DivineIconName.heart.assetPath,
                        width: 28,
                        height: 28,
                        colorFilter: ColorFilter.mode(
                          _tabController.index == 1
                              ? VineTheme.whiteText
                              : VineTheme.onSurfaceMuted,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  Tab(
                    icon: Semantics(
                      label: 'reposted_tab',
                      child: SvgPicture.asset(
                        DivineIconName.repeat.assetPath,
                        width: 28,
                        height: 28,
                        colorFilter: ColorFilter.mode(
                          _tabController.index == 2
                              ? VineTheme.whiteText
                              : VineTheme.onSurfaceMuted,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  Tab(
                    icon: Semantics(
                      label: 'collabs_tab',
                      child: SvgPicture.asset(
                        DivineIconName.user.assetPath,
                        width: 28,
                        height: 28,
                        colorFilter: ColorFilter.mode(
                          _tabController.index == 3
                              ? VineTheme.whiteText
                              : VineTheme.onSurfaceMuted,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  Tab(
                    icon: Semantics(
                      label: 'comments_tab',
                      child: SvgPicture.asset(
                        DivineIconName.chatCircle.assetPath,
                        width: 28,
                        height: 28,
                        colorFilter: ColorFilter.mode(
                          _tabController.index == 4
                              ? VineTheme.whiteText
                              : VineTheme.onSurfaceMuted,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: tabContent,
      ),
    );

    // Measure the header height after each build so we can position the
    // action buttons layer correctly. The header height is variable
    // (depends on bio length, name wrapping, etc.).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = _headerKey.currentContext?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final newHeight = renderObject.size.height;
        if (newHeight != _headerHeight) {
          _headerHeight = newHeight;
          _onScroll();
        }
      }
    });

    // Wrap in a Stack with:
    // - surfaceBackground covering the entire screen (visible in the status
    //   bar area once the banner scrolls offscreen)
    // - ProfileBannerLayer edge-to-edge at the top, scroll-driven
    // - NestedScrollView edge-to-edge so content can scroll behind the
    //   status bar without being clipped by a SafeArea boundary
    // - ProfileActionButtons as a separate layer on top of the NestedScrollView
    //   so it can paint over the tab bar's top safeAreaTop padding area
    //   (CSS z-index equivalent — the action buttons row overlaps the tabs
    //   group by safeAreaTop).
    content = ColoredBox(
      color: VineTheme.surfaceBackground,
      child: Stack(
        children: [
          ProfileBannerLayer(
            userIdHex: widget.userIdHex,
            isOwnProfile: widget.isOwnProfile,
            profile: widget.profile,
            scrollController: widget.scrollController,
          ),
          content,
          // Action buttons overlay — painted above the NestedScrollView.
          ValueListenableBuilder<double>(
            valueListenable: _actionButtonsTop,
            builder: (_, top, child) => Positioned(
              top: top,
              left: 0,
              right: 0,
              height: _actionButtonsHeight,
              child: child!,
            ),
            child: ProfileActionButtons(
              userIdHex: widget.userIdHex,
              isOwnProfile: widget.isOwnProfile,
              displayName: widget.displayName,
              onEditProfile: widget.onEditProfile,
              onOpenClips: widget.onOpenClips,
              onMessageUser: widget.onMessageUser,
              onShareProfile: widget.onShareProfile,
              onBlockedTap: widget.onBlockedTap,
            ),
          ),
        ],
      ),
    );

    // Pre-fetch follower lists so the followers/following screens load
    // instantly when tapped. The BLoCs warm the relay connections and
    // cache the pubkey lists in memory.
    if (widget.isOwnProfile) {
      return BlocProvider<MyFollowersBloc>(
        create: (_) => MyFollowersBloc(
          followRepository: followRepository,
          contentBlocklistService: contentBlocklistService,
        )..add(const MyFollowersListLoadRequested()),
        child: content,
      );
    }

    return BlocProvider<OthersFollowersBloc>(
      create: (_) => OthersFollowersBloc(
        followRepository: followRepository,
        contentBlocklistService: contentBlocklistService,
        currentUserPubkey: currentUserPubkey,
      )..add(OthersFollowersListLoadRequested(widget.userIdHex)),
      child: content,
    );
  }
}

/// Sticky tab bar delegate.
///
/// Adds a [topInset] (typically the safe area top) so that when pinned
/// behind the status bar, the tab bar icons sit below the status bar
/// rather than behind it.
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, {required this.topInset});

  final TabBar _tabBar;
  final double topInset;

  @override
  double get minExtent => _tabBar.preferredSize.height + topInset;

  @override
  double get maxExtent => _tabBar.preferredSize.height + topInset;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => DecoratedBox(
    decoration: const BoxDecoration(
      color: VineTheme.surfaceBackground,
      border: Border(
        bottom: BorderSide(
          color: VineTheme.outlineMuted,
          width: 2,
        ),
      ),
    ),
    child: Padding(
      padding: EdgeInsets.only(top: topInset),
      child: _tabBar,
    ),
  );

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) =>
      topInset != oldDelegate.topInset || _tabBar != oldDelegate._tabBar;
}
