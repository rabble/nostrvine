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
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/blocs/profile_reposted_videos/profile_reposted_videos_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/widgets/profile/profile_action_buttons_widget.dart';
import 'package:openvine/widgets/profile/profile_collabs_grid.dart';
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
    required this.profileStatsAsync,
    this.displayName,
    this.onSetupProfile,
    this.onEditProfile,
    this.onOpenClips,
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

  /// Async value containing profile stats.
  final AsyncValue<ProfileStats> profileStatsAsync;

  /// Callback when "Set Up" button is tapped (own profile only).
  final VoidCallback? onSetupProfile;

  /// Callback when "Edit Profile" is tapped (own profile only).
  final VoidCallback? onEditProfile;

  /// Callback when "Clips" button is tapped (own profile only).
  final VoidCallback? onOpenClips;

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

  /// Track the userIdHex the BLoCs were created for.
  String? _blocsUserIdHex;

  /// Track which tabs have been synced (lazy loading).
  bool _likedTabSynced = false;
  bool _repostsTabSynced = false;
  bool _collabsTabSynced = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final followRepository = ref.watch(followRepositoryProvider);
    final likesRepository = ref.watch(likesRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);
    final videosRepository = ref.watch(videosRepositoryProvider);
    final nostrService = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrService.publicKey;

    // Show loading state until NostrClient has keys
    if (followRepository == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Create BLoCs if not already created, or recreate if userIdHex changed
    // Store references for refresh capability
    if (_blocsUserIdHex != widget.userIdHex) {
      _likedVideosBloc?.close();
      _repostedVideosBloc?.close();
      _collabVideosBloc?.close();

      // Reset lazy load flags when switching profiles
      _likedTabSynced = false;
      _repostsTabSynced = false;
      _collabsTabSynced = false;

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
      ],
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
        ],
      ),
    );

    // Build the main content
    Widget content = DefaultTabController(
      length: 4,
      child: NestedScrollView(
        controller: widget.scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Profile Header
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ProfileHeaderWidget(
                  userIdHex: widget.userIdHex,
                  isOwnProfile: widget.isOwnProfile,
                  videoCount: widget.videos.length,
                  profileStatsAsync: widget.profileStatsAsync,
                  onSetupProfile: widget.onSetupProfile,
                  displayNameHint: widget.displayNameHint,
                  avatarUrlHint: widget.avatarUrlHint,
                ),
              ),
            ),
          ),

          // Action Buttons
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ProfileActionButtons(
                  userIdHex: widget.userIdHex,
                  isOwnProfile: widget.isOwnProfile,
                  displayName: widget.displayName,
                  onEditProfile: widget.onEditProfile,
                  onOpenClips: widget.onOpenClips,
                  onBlockedTap: widget.onBlockedTap,
                ),
              ),
            ),
          ),

          // Sticky Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: VineTheme.tabIndicatorGreen,
                indicatorWeight: 4,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    icon: Semantics(
                      label: 'videos_tab',
                      child: SvgPicture.asset(
                        'assets/icon/play.svg',
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
                        'assets/icon/heart.svg',
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
                        'assets/icon/repost.svg',
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
                        'assets/icon/user.svg',
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
                ],
              ),
            ),
          ),
        ],
        body: tabContent,
      ),
    );

    // Wrap content with surfaceBackground to match app bar
    content = ColoredBox(color: VineTheme.surfaceBackground, child: content);

    // Wrap with OthersFollowersBloc for other users' profiles
    // This allows the follow button to update the followers count optimistically
    if (!widget.isOwnProfile) {
      return BlocProvider<OthersFollowersBloc>(
        create: (_) =>
            OthersFollowersBloc(followRepository: followRepository)
              ..add(OthersFollowersListLoadRequested(widget.userIdHex)),
        child: content,
      );
    }

    return content;
  }
}

/// Custom delegate for sticky tab bar.
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: VineTheme.surfaceBackground, child: _tabBar);

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
