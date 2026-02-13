// ABOUTME: Profile grid with BLoC injection and view with header, stats,
// ABOUTME: action buttons, and tabbed content.
// ABOUTME: Reusable between own profile and others' profile screens.

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

/// Identifies each tab in the profile grid.
enum ProfileTab {
  /// The videos tab.
  videos,

  /// The liked videos tab.
  liked,

  /// The reposted videos tab.
  reposts,
}

/// Profile grid that provides all required BLoCs via [BlocProvider].
///
/// This is the entry point for the profile grid. It creates and provides
/// [ProfileLikedVideosBloc], [ProfileRepostedVideosBloc], and conditionally
/// [OthersFollowersBloc] (for non-own profiles).
class ProfileGrid extends ConsumerWidget {
  const ProfileGrid({
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

  /// Optional display name hint for users without Kind 0 profiles
  /// (e.g., classic Viners).
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
  Widget build(BuildContext context, WidgetRef ref) {
    final nostrService = ref.watch(nostrServiceProvider);
    final likesRepository = ref.watch(likesRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final videosRepository = ref.watch(videosRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);
    final currentUserPubkey = nostrService.publicKey;

    // Show loading state until NostrClient has keys
    if (followRepository == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return MultiBlocProvider(
      key: ValueKey(userIdHex),
      providers: [
        BlocProvider(
          create: (_) => ProfileLikedVideosBloc(
            likesRepository: likesRepository,
            videosRepository: videosRepository,
            currentUserPubkey: currentUserPubkey,
            targetUserPubkey: userIdHex,
          )..add(const ProfileLikedVideosSubscriptionRequested()),
        ),
        BlocProvider(
          create: (_) => ProfileRepostedVideosBloc(
            repostsRepository: repostsRepository,
            videosRepository: videosRepository,
            currentUserPubkey: currentUserPubkey,
            targetUserPubkey: userIdHex,
          )..add(const ProfileRepostedVideosSubscriptionRequested()),
        ),
        if (!isOwnProfile)
          BlocProvider(
            create: (_) =>
                OthersFollowersBloc(followRepository: followRepository)
                  ..add(OthersFollowersListLoadRequested(userIdHex)),
          ),
      ],
      child: ProfileGridView(
        userIdHex: userIdHex,
        isOwnProfile: isOwnProfile,
        videos: videos,
        profileStatsAsync: profileStatsAsync,
        displayName: displayName,
        onSetupProfile: onSetupProfile,
        onEditProfile: onEditProfile,
        onOpenClips: onOpenClips,
        onBlockedTap: onBlockedTap,
        scrollController: scrollController,
        displayNameHint: displayNameHint,
        avatarUrlHint: avatarUrlHint,
        refreshNotifier: refreshNotifier,
        isLoadingVideos: isLoadingVideos,
        videoLoadError: videoLoadError,
      ),
    );
  }
}

/// Profile grid view showing header, stats, action buttons, and tabbed content.
///
/// Must be wrapped by [ProfileGrid] which provides the required BLoCs.
class ProfileGridView extends StatefulWidget {
  @visibleForTesting
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

  /// Optional display name hint for users without Kind 0 profiles
  /// (e.g., classic Viners).
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
  State<ProfileGridView> createState() => _ProfileGridViewState();
}

class _ProfileGridViewState extends State<ProfileGridView>
    with TickerProviderStateMixin {
  /// Cache for preserving tab selection across widget rebuilds.
  /// Keyed by userIdHex so each profile remembers its own tab.
  static final Map<String, ProfileTab> tabIndexCache = {};

  late TabController tabController;

  /// Track which tabs have been synced (lazy loading).
  bool likedTabSynced = false;
  bool repostsTabSynced = false;

  @override
  void initState() {
    super.initState();
    final cachedTab =
        tabIndexCache[widget.userIdHex] ?? ProfileTab.values.first;
    tabController = TabController(
      vsync: this,
      length: ProfileTab.values.length,
      initialIndex: cachedTab.index,
    );
    tabController.addListener(_onTabChanged);
    widget.refreshNotifier?.addListener(_onRefreshRequested);

    // If restored to a non-default tab, trigger sync immediately
    // since _onTabChanged won't fire for the initial index.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (tabController.index == ProfileTab.liked.index && !likedTabSynced) {
        likedTabSynced = true;
        return context.read<ProfileLikedVideosBloc>().add(
          const ProfileLikedVideosSyncRequested(),
        );
      }

      if (tabController.index == ProfileTab.reposts.index &&
          !repostsTabSynced) {
        repostsTabSynced = true;
        return context.read<ProfileRepostedVideosBloc>().add(
          const ProfileRepostedVideosSyncRequested(),
        );
      }
    });
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
    // Persist tab selection for navigation restoration
    tabIndexCache[widget.userIdHex] = ProfileTab.values[tabController.index];

    // Trigger rebuild to update SVG icon colors
    if (mounted) setState(() {});

    // Lazy load: Trigger sync only when user first views the tab
    if (tabController.index == ProfileTab.liked.index && !likedTabSynced) {
      likedTabSynced = true;
      return context.read<ProfileLikedVideosBloc>().add(
        const ProfileLikedVideosSyncRequested(),
      );
    }

    if (tabController.index == ProfileTab.reposts.index && !repostsTabSynced) {
      repostsTabSynced = true;
      return context.read<ProfileRepostedVideosBloc>().add(
        const ProfileRepostedVideosSyncRequested(),
      );
    }
  }

  void _onRefreshRequested() {
    // Dispatch sync events to BLoCs to refresh likes/reposts
    // Only sync tabs that have been viewed (lazy load still applies)
    if (likedTabSynced) {
      return context.read<ProfileLikedVideosBloc>().add(
        const ProfileLikedVideosSyncRequested(),
      );
    }

    if (repostsTabSynced) {
      return context.read<ProfileRepostedVideosBloc>().add(
        const ProfileRepostedVideosSyncRequested(),
      );
    }
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshRequested);
    tabController.removeListener(_onTabChanged);
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabContent = TabBarView(
      controller: tabController,
      children: [
        ProfileVideosGrid(
          videos: widget.videos,
          userIdHex: widget.userIdHex,
          isLoading: widget.isLoadingVideos,
          errorMessage: widget.videoLoadError,
        ),
        ProfileLikedGrid(isOwnProfile: widget.isOwnProfile),
        ProfileRepostsGrid(isOwnProfile: widget.isOwnProfile),
      ],
    );

    final content = DefaultTabController(
      length: ProfileTab.values.length,
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
                controller: tabController,
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
                          tabController.index == ProfileTab.videos.index
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
                          tabController.index == ProfileTab.liked.index
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
                          tabController.index == ProfileTab.reposts.index
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
    return ColoredBox(color: VineTheme.surfaceBackground, child: content);
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
