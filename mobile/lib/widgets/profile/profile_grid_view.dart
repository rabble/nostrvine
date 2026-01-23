// ABOUTME: Profile grid view with header, stats, action buttons, and tabbed content
// ABOUTME: Reusable between own profile and others' profile screens

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/blocs/profile_reposted_videos/profile_reposted_videos_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/widgets/profile/profile_action_buttons_widget.dart';
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

  @override
  ConsumerState<ProfileGridView> createState() => _ProfileGridViewState();
}

class _ProfileGridViewState extends ConsumerState<ProfileGridView>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Trigger rebuild to update SVG icon colors
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
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

    // Build the base widget with ProfileLikedVideosBloc and
    // ProfileRepostedVideosBloc
    // Pass userIdHex as targetUserPubkey so the BLoCs know whose
    // likes/reposts to fetch
    final tabContent = MultiBlocProvider(
      providers: [
        BlocProvider<ProfileLikedVideosBloc>(
          create: (_) =>
              ProfileLikedVideosBloc(
                  likesRepository: likesRepository,
                  videosRepository: videosRepository,
                  currentUserPubkey: currentUserPubkey,
                  targetUserPubkey: widget.userIdHex,
                )
                ..add(const ProfileLikedVideosSubscriptionRequested())
                ..add(const ProfileLikedVideosSyncRequested()),
        ),
        BlocProvider<ProfileRepostedVideosBloc>(
          create: (_) =>
              ProfileRepostedVideosBloc(
                  repostsRepository: repostsRepository,
                  videosRepository: videosRepository,
                  currentUserPubkey: currentUserPubkey,
                  targetUserPubkey: widget.userIdHex,
                )
                ..add(const ProfileRepostedVideosSubscriptionRequested())
                ..add(const ProfileRepostedVideosSyncRequested()),
        ),
      ],
      child: TabBarView(
        controller: _tabController,
        children: [
          ProfileVideosGrid(videos: widget.videos, userIdHex: widget.userIdHex),
          ProfileLikedGrid(isOwnProfile: widget.isOwnProfile),
          ProfileRepostsGrid(isOwnProfile: widget.isOwnProfile),
        ],
      ),
    );

    // Build the main content
    Widget content = DefaultTabController(
      length: 3,
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
                    icon: SvgPicture.asset(
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
                  Tab(
                    icon: SvgPicture.asset(
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
                  Tab(
                    icon: SvgPicture.asset(
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
