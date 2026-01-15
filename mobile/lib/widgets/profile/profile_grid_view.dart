// ABOUTME: Profile grid view with header, stats, action buttons, and tabbed content
// ABOUTME: Reusable between own profile and others' profile screens

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/profile/profile_action_buttons_widget.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';
import 'package:openvine/widgets/profile/profile_liked_grid.dart';
import 'package:openvine/widgets/profile/profile_reposts_grid.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';
import 'package:openvine/widgets/profile/profile_videos_grid.dart';

/// Profile grid view showing header, stats, action buttons, and tabbed content.
class ProfileGridView extends ConsumerStatefulWidget {
  const ProfileGridView({
    required this.userIdHex,
    required this.isOwnProfile,
    required this.videos,
    required this.profileStatsAsync,
    this.onSetupProfile,
    this.onEditProfile,
    this.onOpenClips,
    this.onShareProfile,
    this.onBlockUser,
    this.scrollController,
    super.key,
  });

  /// The hex public key of the profile being displayed.
  final String userIdHex;

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

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

  /// Callback when "Share" button is tapped.
  final VoidCallback? onShareProfile;

  /// Callback when block/unblock button is tapped (others' profile only).
  /// Parameter indicates whether user is currently blocked.
  final void Function(bool isBlocked)? onBlockUser;

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get services for ProfileLikedVideosBloc
    final videoEventService = ref.watch(videoEventServiceProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final likesRepository = ref.watch(likesRepositoryProvider);

    // Build the base widget with ProfileLikedVideosBloc
    // Pass userIdHex as targetUserPubkey so the BLoC knows whose likes to fetch
    final tabContent = BlocProvider<ProfileLikedVideosBloc>(
      create: (_) =>
          ProfileLikedVideosBloc(
              likesRepository: likesRepository,
              videoEventService: videoEventService,
              nostrClient: nostrClient,
              targetUserPubkey: widget.userIdHex,
            )
            ..add(const ProfileLikedVideosSubscriptionRequested())
            ..add(const ProfileLikedVideosSyncRequested()),
      child: TabBarView(
        controller: _tabController,
        children: [
          ProfileVideosGrid(videos: widget.videos, userIdHex: widget.userIdHex),
          const ProfileLikedGrid(),
          ProfileRepostsGrid(userIdHex: widget.userIdHex),
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
                  profileStatsAsync: widget.profileStatsAsync,
                  onSetupProfile: widget.onSetupProfile,
                ),
              ),
            ),
          ),

          // Stats Row
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ProfileStatsRowWidget(
                  profileStatsAsync: widget.profileStatsAsync,
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
                  onEditProfile: widget.onEditProfile,
                  onOpenClips: widget.onOpenClips,
                  onShareProfile: widget.onShareProfile,
                  onBlockUser: widget.onBlockUser,
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
                indicatorColor: Colors.white,
                indicatorWeight: 2,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on, size: 20)),
                  Tab(icon: Icon(Icons.favorite_border, size: 20)),
                  Tab(icon: Icon(Icons.repeat, size: 20)),
                ],
              ),
            ),
          ),
        ],
        body: tabContent,
      ),
    );

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
  ) => ColoredBox(color: VineTheme.backgroundColor, child: _tabBar);

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
