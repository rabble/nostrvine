// ABOUTME: Router-driven Instagram-style profile screen implementation
// ABOUTME: Uses CustomScrollView with slivers for smooth scrolling, URL is source of truth

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/user_profile_utils.dart';
import 'package:openvine/widgets/environment_indicator.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/profile/blocked_user_screen.dart';
import 'package:openvine/widgets/profile/profile_grid.dart';
import 'package:openvine/widgets/profile/profile_loading_view.dart';
import 'package:openvine/widgets/profile/profile_video_feed_view.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';
import 'package:openvine/widgets/vine_drawer.dart';
import 'package:share_plus/share_plus.dart';

/// Router-driven ProfileScreen - Instagram-style scrollable profile
class ProfileScreenRouter extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'profile';

  /// Base path for profile routes.
  static const path = '/profile';

  /// Path for this route (grid mode).
  static const pathWithNpub = '/profile/:npub';

  /// Path for this route (feed mode).
  static const pathWithIndex = '/profile/:npub/:index';

  /// Build path for grid mode or specific npub.
  static String pathForNpub(String npub) => '$path/$npub';

  /// Build path for feed mode with specific npub and index.
  static String pathForIndex(String npub, int index) => '$path/$npub/$index';

  const ProfileScreenRouter({super.key});

  @override
  ConsumerState<ProfileScreenRouter> createState() =>
      _ProfileScreenRouterState();
}

class _ProfileScreenRouterState extends ConsumerState<ProfileScreenRouter>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  /// Notifier to trigger refresh of profile BLoCs (likes, reposts).
  final _refreshNotifier = ValueNotifier<int>(0);

  /// Whether a refresh is currently in progress.
  bool _isRefreshing = false;

  void _fetchProfileIfNeeded(String userIdHex, bool isOwnProfile) {
    if (isOwnProfile) return; // Own profile loads automatically

    final userProfileService = ref.read(userProfileServiceProvider);

    // Fetch profile (shows cached immediately, refreshes in background)
    if (!userProfileService.hasProfile(userIdHex)) {
      Log.debug(
        '📥 Fetching uncached profile: $userIdHex',
        name: 'ProfileScreenRouter',
        category: LogCategory.ui,
      );
      userProfileService.fetchProfile(userIdHex);
    } else {
      Log.debug(
        '📋 Using cached profile: $userIdHex',
        name: 'ProfileScreenRouter',
        category: LogCategory.ui,
      );
      // Still call fetchProfile to trigger background refresh if needed
      userProfileService.fetchProfile(userIdHex);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshNotifier.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile(String userIdHex) async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      // Run refresh operations and minimum duration in parallel
      // This ensures the spinner shows for at least 500ms for visual feedback
      await Future.wait([
        _doRefresh(userIdHex),
        Future<void>.delayed(const Duration(milliseconds: 500)),
      ]);

      Log.info(
        '🔄 Profile refreshed for $userIdHex',
        name: 'ProfileScreenRouter',
        category: LogCategory.ui,
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _doRefresh(String userIdHex) async {
    // Refresh videos from provider
    await ref.read(profileFeedProvider(userIdHex).notifier).refresh();

    // Invalidate stats to recompute
    ref.invalidate(fetchProfileStatsProvider(userIdHex));

    // Refresh user profile info
    ref.read(userProfileServiceProvider).fetchProfile(userIdHex);

    // Trigger BLoC refresh for likes/reposts via notifier
    _refreshNotifier.value++;
  }

  @override
  Widget build(BuildContext context) {
    Log.info('🧭 ProfileScreenRouter.build', name: 'ProfileScreenRouter');

    // Read derived context from router
    final pageContext = ref.watch(pageContextProvider);

    // Check if this is own profile grid view (needs own scaffold)
    final isOwnProfileGrid = pageContext.maybeWhen(
      data: (ctx) {
        if (ctx.type != RouteType.profile) return false;
        if (ctx.videoIndex != null) return false; // Video mode uses shell
        final currentNpub = ref.read(authServiceProvider).currentNpub;
        return ctx.npub == 'me' || ctx.npub == currentNpub;
      },
      orElse: () => false,
    );

    final content = switch (pageContext) {
      AsyncLoading() => const ProfileLoadingView(),
      AsyncError(:final error) => Center(child: Text('Error: $error')),
      AsyncData(:final value) => _ProfileContentView(
        routeContext: value,
        scrollController: _scrollController,
        onFetchProfile: _fetchProfileIfNeeded,
        onSetupProfile: _setupProfile,
        onEditProfile: _editProfile,
        onOpenClips: _openClips,
        onOpenAnalytics: _openAnalytics,
        refreshNotifier: _refreshNotifier,
      ),
    };

    // Own profile grid gets its own scaffold with custom app bar
    if (isOwnProfileGrid) {
      final environment = ref.watch(currentEnvironmentProvider);
      final userIdHex = ref.read(authServiceProvider).currentPublicKeyHex;

      // Watch profile for profile color
      final profileAsync = userIdHex != null
          ? ref.watch(fetchUserProfileProvider(userIdHex))
          : null;
      final profileColor = profileAsync?.value?.profileBackgroundColor;

      return Scaffold(
        backgroundColor: Colors.black,
        onDrawerChanged: (isOpen) {
          ref.read(overlayVisibilityProvider.notifier).setDrawerOpen(isOpen);
        },
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 72,
          leadingWidth: 80,
          centerTitle: false,
          titleSpacing: 0,
          backgroundColor:
              profileColor ?? getEnvironmentAppBarColor(environment),
          leading: Builder(
            builder: (context) => IconButton(
              key: const Key('menu-icon-button'),
              tooltip: 'Menu',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: VineTheme.iconButtonBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SvgPicture.asset(
                  'assets/icon/menu.svg',
                  width: 32,
                  height: 32,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              onPressed: () {
                Log.info(
                  '👆 User tapped menu button',
                  name: 'Navigation',
                  category: LogCategory.ui,
                );
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          title: Text(
            'My Profile',
            style: VineTheme.titleFont(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            // Refresh button
            IconButton(
              key: const Key('refresh-icon-button'),
              tooltip: 'Refresh',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VineTheme.iconButtonBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isRefreshing
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : SvgPicture.asset(
                        'assets/icon/refresh.svg',
                        width: 28,
                        height: 28,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
              ),
              onPressed: userIdHex != null && !_isRefreshing
                  ? () => _refreshProfile(userIdHex)
                  : null,
            ),
            const SizedBox(width: 8),
            // More button
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                tooltip: 'More',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: VineTheme.iconButtonBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SvgPicture.asset(
                    'assets/icon/DotsThree.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                onPressed: userIdHex != null ? () => _more(userIdHex) : null,
              ),
            ),
          ],
        ),
        drawer: const VineDrawer(),
        body: content,
        bottomNavigationBar: const VineBottomNav(currentIndex: 3),
      );
    }

    return content;
  }

  // Action methods

  Future<void> _setupProfile() async {
    // Navigate to setup-profile route (defined outside ShellRoute)
    await context.push(ProfileSetupScreen.setupPath);
  }

  Future<void> _editProfile() async {
    // Navigate directly to edit-profile route (defined outside ShellRoute)
    await context.push(ProfileSetupScreen.editPath);
  }

  Future<void> _shareProfile(String userIdHex) async {
    try {
      // Get profile info for better share text
      final profile = await ref
          .read(userProfileServiceProvider)
          .fetchProfile(userIdHex);
      final displayName = profile?.bestDisplayName ?? 'User';

      // Convert hex pubkey to npub format for sharing
      final npub = NostrKeyUtils.encodePubKey(userIdHex);

      // Create share text with divine.video URL format
      final shareText =
          'Check out $displayName on divine!\n\n'
          'https://divine.video/profile/$npub';

      // Use share_plus to show native share sheet
      final result = await SharePlus.instance.share(
        ShareParams(text: shareText, subject: '$displayName on divine'),
      );

      if (result.status == ShareResultStatus.success) {
        Log.info(
          'Profile shared successfully',
          name: 'ProfileScreenRouter',
          category: LogCategory.ui,
        );
      }
    } catch (e) {
      Log.error(
        'Error sharing profile: $e',
        name: 'ProfileScreenRouter',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share profile: $e')));
      }
    }
  }

  void _openClips() {
    // Navigate to clips route (defined outside ShellRoute)
    context.push(ClipLibraryScreen.clipsPath);
  }

  void _openAnalytics() {
    final rootContext = NavigatorKeys.root.currentContext;
    if (rootContext != null) {
      GoRouter.of(rootContext).pushNamed(CreatorAnalyticsScreen.routeName);
      return;
    }
    context.pushNamed(CreatorAnalyticsScreen.routeName);
  }

  Future<void> _more(String userIdHex) async {
    final result = await VineBottomSheet.show<String>(
      context: context,
      scrollable: false,
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop('edit'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icon/content-controls/pencil.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    VineTheme.whiteText,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 16),
                Text('Edit profile', style: VineTheme.titleMediumFont()),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () => Navigator.of(context).pop('analytics'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 24),
                const SizedBox(width: 16),
                Text('Creator analytics', style: VineTheme.titleMediumFont()),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () => Navigator.of(context).pop('share'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icon/content-controls/share.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    VineTheme.whiteText,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 16),
                Text('Share profile', style: VineTheme.titleMediumFont()),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () => Navigator.of(context).pop('copy_npub'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icon/copy.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    VineTheme.whiteText,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Copy public key (npub)',
                  style: VineTheme.titleMediumFont(),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (!mounted) return;

    if (result == 'edit') {
      _editProfile();
    } else if (result == 'analytics') {
      _openAnalytics();
    } else if (result == 'share') {
      await _shareProfile(userIdHex);
    } else if (result == 'copy_npub') {
      await _copyNpub(userIdHex);
    }
  }

  Future<void> _copyNpub(String userIdHex) async {
    final npub = NostrKeyUtils.encodePubKey(userIdHex);
    await Clipboard.setData(ClipboardData(text: npub));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Public key copied to clipboard')),
      );
    }
  }
}

/// Private widget that handles profile content based on route context.
class _ProfileContentView extends ConsumerWidget {
  const _ProfileContentView({
    required this.routeContext,
    required this.scrollController,
    required this.onFetchProfile,
    required this.onSetupProfile,
    required this.onEditProfile,
    required this.onOpenClips,
    required this.onOpenAnalytics,
    required this.refreshNotifier,
  });

  final RouteContext routeContext;
  final ScrollController scrollController;
  final void Function(String userIdHex, bool isOwnProfile) onFetchProfile;
  final VoidCallback onSetupProfile;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenClips;
  final VoidCallback onOpenAnalytics;
  final ValueNotifier<int> refreshNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routeContext.type != RouteType.profile) {
      // During navigation transitions, we may briefly see non-profile routes.
      // Just show nothing rather than an error message.
      return const SizedBox.shrink();
    }

    // Convert npub to hex for profile feed provider
    final npub = routeContext.npub ?? '';

    // Handle "me" special case - redirect to actual user profile
    if (npub == 'me') {
      return _MeProfileRedirect(videoIndex: routeContext.videoIndex);
    }

    final userIdHex = npubToHexOrNull(npub);

    if (userIdHex == null) {
      return const Center(child: Text('Invalid profile ID'));
    }

    // Get current user for comparison
    final authService = ref.watch(authServiceProvider);
    final currentUserHex = authService.currentPublicKeyHex;
    final isOwnProfile = userIdHex == currentUserHex;

    // Check if this user has muted us (mutual mute blocking)
    // Note: We only block profile viewing for users who muted US, not users WE blocked.
    // Users can still view profiles of people they blocked (to unblock them).
    final blocklistService = ref.watch(contentBlocklistServiceProvider);
    if (blocklistService.hasMutedUs(userIdHex)) {
      return BlockedUserScreen(onBack: context.pop);
    }

    // Fetch profile data if needed (post-frame to avoid build mutations)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onFetchProfile(userIdHex, isOwnProfile);
    });

    // Get display name for unfollow confirmation (only needed for other profiles)
    final displayName = isOwnProfile
        ? null
        : ref
              .watch(userProfileReactiveProvider(userIdHex))
              .value
              ?.bestDisplayName;

    return _ProfileDataView(
      npub: npub,
      userIdHex: userIdHex,
      isOwnProfile: isOwnProfile,
      displayName: displayName,
      videoIndex: routeContext.videoIndex,
      scrollController: scrollController,
      onSetupProfile: onSetupProfile,
      onEditProfile: onEditProfile,
      onOpenClips: onOpenClips,
      onOpenAnalytics: onOpenAnalytics,
      refreshNotifier: refreshNotifier,
    );
  }
}

/// Handles redirect when npub is "me".
class _MeProfileRedirect extends ConsumerWidget {
  const _MeProfileRedirect({required this.videoIndex});

  final int? videoIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);

    if (!authService.isAuthenticated ||
        authService.currentPublicKeyHex == null) {
      // Not authenticated - redirect to home
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(VideoFeedPage.pathForIndex(0));
      });
      return const Center(child: CircularProgressIndicator());
    }

    // Get current user's npub and redirect (preserve grid/feed mode from context)
    final currentUserNpub = NostrKeyUtils.encodePubKey(
      authService.currentPublicKeyHex!,
    );

    // Redirect to actual user profile using GoRouter explicitly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use direct GoRouter calls to properly handle null videoIndex (grid mode)
      if (videoIndex != null) {
        context.go(
          ProfileScreenRouter.pathForIndex(currentUserNpub, videoIndex!),
        );
      } else {
        context.go(ProfileScreenRouter.pathForNpub(currentUserNpub));
      }
    });

    // Show loading while redirecting
    return const Center(child: CircularProgressIndicator());
  }
}

/// Displays profile data after loading videos and stats.
class _ProfileDataView extends ConsumerWidget {
  const _ProfileDataView({
    required this.npub,
    required this.userIdHex,
    required this.isOwnProfile,
    required this.videoIndex,
    required this.scrollController,
    required this.onSetupProfile,
    required this.onEditProfile,
    required this.onOpenClips,
    required this.onOpenAnalytics,
    required this.refreshNotifier,
    this.displayName,
  });

  final String npub;
  final String userIdHex;
  final bool isOwnProfile;
  final String? displayName;
  final int? videoIndex;
  final ScrollController scrollController;
  final VoidCallback onSetupProfile;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenClips;
  final VoidCallback onOpenAnalytics;
  final ValueNotifier<int> refreshNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get video data from profile feed
    final videosAsync = ref.watch(profileFeedProvider(userIdHex));

    // Get profile stats
    final profileStatsAsync = ref.watch(fetchProfileStatsProvider(userIdHex));

    if (videosAsync is AsyncData) {
      ScreenAnalyticsService().markDataLoaded(
        'own_profile',
        dataMetrics: {
          'video_count': videosAsync.asData?.value.videos.length ?? 0,
        },
      );
    }

    return BlocListener<BackgroundPublishBloc, BackgroundPublishState>(
      listenWhen: (previous, current) {
        // Listen only for upload completions
        final prevCompleted = previous.uploads
            .where((upload) => upload.result != null)
            .length;
        final currCompleted = current.uploads
            .where((upload) => upload.result != null)
            .length;
        return currCompleted > prevCompleted;
      },
      listener: (context, state) {
        // We don't need the value here, we just want to refresh the feed
        // when background uploads complete
        final _ = ref.refresh(profileFeedProvider(userIdHex));
      },
      child: switch (videosAsync) {
        AsyncLoading() => const ProfileLoadingView(),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        AsyncData(:final value) => ProfileViewSwitcher(
          npub: npub,
          userIdHex: userIdHex,
          isOwnProfile: isOwnProfile,
          displayName: displayName,
          videos: value.videos,
          videoIndex: videoIndex,
          profileStatsAsync: profileStatsAsync,
          scrollController: scrollController,
          onSetupProfile: onSetupProfile,
          onEditProfile: onEditProfile,
          onOpenClips: onOpenClips,
          onOpenAnalytics: onOpenAnalytics,
          refreshNotifier: refreshNotifier,
        ),
      },
    );
  }
}

/// Switches between grid view and video feed view based on videoIndex.
class ProfileViewSwitcher extends StatelessWidget {
  /// Creates a ProfileViewSwitcher widget.
  @visibleForTesting
  const ProfileViewSwitcher({
    required this.npub,
    required this.userIdHex,
    required this.isOwnProfile,
    required this.videos,
    required this.videoIndex,
    required this.profileStatsAsync,
    required this.scrollController,
    required this.onSetupProfile,
    required this.onEditProfile,
    required this.onOpenClips,
    required this.onOpenAnalytics,
    this.refreshNotifier,
    this.displayName,
    super.key,
  });

  final String npub;
  final String userIdHex;
  final bool isOwnProfile;
  final String? displayName;
  final List<VideoEvent> videos;
  final int? videoIndex;
  final AsyncValue<ProfileStats> profileStatsAsync;
  final ScrollController scrollController;
  final VoidCallback onSetupProfile;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenClips;
  final VoidCallback onOpenAnalytics;

  /// Optional notifier to trigger BLoC refresh when its value changes.
  final ValueNotifier<int>? refreshNotifier;

  @override
  Widget build(BuildContext context) {
    final backgroundPublishBloc = context.watch<BackgroundPublishBloc>();

    // If videoIndex is set, show fullscreen video mode
    // Note: videoIndex maps directly to list index (0 = first video, etc.)
    // When videoIndex is null, show grid mode
    final child = (videoIndex != null && videos.isNotEmpty)
        ? ProfileVideoFeedView(
            npub: npub,
            userIdHex: userIdHex,
            isOwnProfile: isOwnProfile,
            videos: videos,
            videoIndex: videoIndex!,
            onPageChanged: (newIndex) {
              context.go(ProfileScreenRouter.pathForIndex(npub, newIndex));
            },
          )
        :
          // Otherwise show Instagram-style grid view
          ProfileGridView(
            userIdHex: userIdHex,
            isOwnProfile: isOwnProfile,
            displayName: displayName,
            videos: videos,
            profileStatsAsync: profileStatsAsync,
            scrollController: scrollController,
            onSetupProfile: onSetupProfile,
            onEditProfile: onEditProfile,
            onOpenClips: onOpenClips,
            onOpenAnalytics: onOpenAnalytics,
            refreshNotifier: refreshNotifier,
          );

    final completedWithErrorUploads = backgroundPublishBloc.state.uploads
        .where((upload) => upload.result != null)
        .toList();

    if (completedWithErrorUploads.isNotEmpty) {
      final faultUpload = completedWithErrorUploads.first;

      return Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Dismissible(
              key: ValueKey(faultUpload.draft.id),
              direction: DismissDirection.horizontal,
              onDismissed: (_) {
                backgroundPublishBloc.add(
                  BackgroundPublishVanished(draftId: faultUpload.draft.id),
                );
              },
              child: DivineSnackbarContainer(
                label: 'Video upload failed.',
                error: true,
                actionLabel: 'Retry',
                onActionPressed: () {
                  backgroundPublishBloc.add(
                    BackgroundPublishRetryRequested(
                      draftId: faultUpload.draft.id,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    } else {
      return child;
    }
  }
}
