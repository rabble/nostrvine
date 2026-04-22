// ABOUTME: Router-driven Instagram-style profile screen implementation
// ABOUTME: Uses CustomScrollView with slivers for smooth scrolling, URL is source of truth

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/user_profile_utils.dart';
import 'package:openvine/widgets/environment_indicator.dart';
import 'package:openvine/widgets/profile/blocked_user_screen.dart';
import 'package:openvine/widgets/profile/profile_grid.dart';
import 'package:openvine/widgets/profile/profile_loading_view.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unified_logger/unified_logger.dart';

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

    // Trigger a background fetch via ProfileRepository
    ref.read(profileRepositoryProvider)?.fetchFreshProfile(pubkey: userIdHex);
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

    // Refresh user profile info
    ref.read(profileRepositoryProvider)?.fetchFreshProfile(pubkey: userIdHex);

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
      AsyncError(:final error) => Center(
        child: Text(context.l10n.profileErrorPrefix(error)),
      ),
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

    if (isOwnProfileGrid) {
      final userIdHex = ref.read(authServiceProvider).currentPublicKeyHex;
      final profileRepository = ref.watch(profileRepositoryProvider);

      if (userIdHex == null || profileRepository == null) {
        return const _ProfileScaffold(body: ProfileLoadingView());
      }

      return BlocProvider<MyProfileBloc>(
        create: (context) =>
            MyProfileBloc(
                profileRepository: profileRepository,
                pubkey: userIdHex,
              )
              ..add(const MyProfileSubscriptionRequested())
              ..add(const MyProfileFetchRequested()),
        child: BlocBuilder<MyProfileBloc, MyProfileState>(
          buildWhen: (previous, current) {
            final previousColor = switch (previous) {
              MyProfileUpdated(:final profile) =>
                profile.profileBackgroundColor,
              _ => null,
            };
            final currentColor = switch (current) {
              MyProfileUpdated(:final profile) =>
                profile.profileBackgroundColor,
              _ => null,
            };
            return previousColor != currentColor;
          },
          builder: (context, state) {
            final profileColor = switch (state) {
              MyProfileUpdated(:final profile) =>
                profile.profileBackgroundColor,
              _ => null,
            };

            return _ProfileScaffold(
              onRefreshPressed: () => _refreshProfile(userIdHex),
              onMorePressed: () => _more(userIdHex),
              appBarColor: profileColor,
              isRefreshing: _isRefreshing,
              body: content,
            );
          },
        ),
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
    // Capture l10n callable functions before any awaits to avoid
    // use_build_context_synchronously warnings.
    final l10n = context.l10n;
    final shareTextFn = l10n.profileShareText;
    final shareSubjectFn = l10n.profileShareSubject;

    try {
      // Get profile info for better share text
      final profile = await ref
          .read(profileRepositoryProvider)
          ?.getCachedProfile(pubkey: userIdHex);
      final displayName = profile?.bestDisplayName ?? 'User';

      // Convert hex pubkey to npub format for sharing
      final npub = NostrKeyUtils.encodePubKey(userIdHex);

      // Create share text with divine.video URL format
      final shareText = shareTextFn(displayName, npub);

      // Use share_plus to show native share sheet
      final result = await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: shareSubjectFn(displayName),
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.profileShareFailed(e))),
        );
      }
    }
  }

  void _openClips() {
    // Navigate to clips route (defined outside ShellRoute)
    context.push(LibraryScreen.draftsPath);
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
                  DivineIconName.pencilSimpleLineDuo.assetPath,
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    VineTheme.whiteText,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  context.l10n.profileEditProfile,
                  style: VineTheme.titleMediumFont(),
                ),
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
                const Icon(
                  Icons.analytics_outlined,
                  size: 24,
                  color: VineTheme.whiteText,
                ),
                const SizedBox(width: 16),
                Text(
                  context.l10n.profileCreatorAnalytics,
                  style: VineTheme.titleMediumFont(),
                ),
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
                  DivineIconName.shareFatDuo.assetPath,
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    VineTheme.whiteText,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  context.l10n.profileShareProfile,
                  style: VineTheme.titleMediumFont(),
                ),
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
                  DivineIconName.copy.assetPath,
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    VineTheme.whiteText,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  context.l10n.profileCopyPublicKey,
                  style: VineTheme.titleMediumFont(),
                ),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () => Navigator.of(context).pop('embed_code'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.code, size: 24, color: VineTheme.whiteText),
                const SizedBox(width: 16),
                Text(
                  context.l10n.profileGetEmbedCode,
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
    } else if (result == 'embed_code') {
      await _copyEmbedCode(userIdHex);
    }
  }

  Future<void> _copyNpub(String userIdHex) async {
    final npub = NostrKeyUtils.encodePubKey(userIdHex);
    await Clipboard.setData(ClipboardData(text: npub));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profilePublicKeyCopied)),
      );
    }
  }

  Future<void> _copyEmbedCode(String userIdHex) async {
    final npub = NostrKeyUtils.encodePubKey(userIdHex);
    final embedSnippet =
        '<iframe\n'
        '  src="https://divine.video/embed?npub=$npub"\n'
        '  width="350"\n'
        '  height="380"\n'
        '  style="border-radius: 12px; border: none;"\n'
        '  title="Divine Video Widget"\n'
        '></iframe>';
    await Clipboard.setData(ClipboardData(text: embedSnippet));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profileEmbedCodeCopied)),
      );
    }
  }
}

class _ProfileScaffold extends ConsumerWidget {
  const _ProfileScaffold({
    required this.body,
    this.isRefreshing = false,
    this.appBarColor,
    this.onRefreshPressed,
    this.onMorePressed,
  });

  final bool isRefreshing;

  final Color? appBarColor;

  final Widget body;

  final VoidCallback? onRefreshPressed;
  final VoidCallback? onMorePressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(currentEnvironmentProvider);

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: DiVineAppBar(
        title: '',
        backgroundColor: appBarColor ?? getEnvironmentAppBarColor(environment),
        leadingIcon: SvgIconSource(DivineIconName.gear.assetPath),
        onLeadingPressed: () {
          Log.info(
            'User tapped settings gear',
            name: 'Navigation',
            category: LogCategory.ui,
          );
          context.pushWithVideoPause(SettingsScreen.path);
        },
        actions: [
          DiVineAppBarAction(
            icon: isRefreshing
                ? const MaterialIconSource(Icons.refresh)
                : SvgIconSource(
                    DivineIconName.arrowsCounterClockwise.assetPath,
                  ),
            onPressed: isRefreshing ? null : onRefreshPressed,
            tooltip: context.l10n.profileRefreshTooltip,
            semanticLabel: context.l10n.profileRefreshSemanticLabel,
          ),
          DiVineAppBarAction(
            icon: SvgIconSource(
              DivineIconName.dotsThree.assetPath,
            ),
            onPressed: onMorePressed,
            tooltip: context.l10n.profileMoreTooltip,
            semanticLabel: context.l10n.profileMoreSemanticLabel,
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: const VineBottomNav(currentIndex: 3),
    );
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
      return Center(child: Text(context.l10n.profileInvalidId));
    }

    // Get current user for comparison
    final authService = ref.watch(authServiceProvider);
    final currentUserHex = authService.currentPublicKeyHex;
    final isOwnProfile = userIdHex == currentUserHex;

    // Check if this user has muted us (mutual mute blocking)
    // Note: We only block profile viewing for users who muted US, not users WE blocked.
    // Users can still view profiles of people they blocked (to unblock them).
    ref.watch(blocklistVersionProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    if (blocklistRepository.hasMutedUs(userIdHex) ||
        blocklistRepository.hasBlockedUs(userIdHex)) {
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
        AsyncError(:final error) => Center(
          child: Text(context.l10n.profileErrorPrefix(error)),
        ),
        AsyncData(:final value) => ProfileViewSwitcher(
          npub: npub,
          userIdHex: userIdHex,
          isOwnProfile: isOwnProfile,
          displayName: displayName,
          videos: value.videos,
          totalVideoCount: value.totalVideoCount,
          isFetchingTotalCount: value.isFetchingTotalCount,
          videoIndex: videoIndex,
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
    required this.scrollController,
    required this.onSetupProfile,
    required this.onEditProfile,
    required this.onOpenClips,
    required this.onOpenAnalytics,
    this.totalVideoCount,
    this.isFetchingTotalCount = false,
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
  final ScrollController scrollController;
  final VoidCallback onSetupProfile;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenClips;
  final VoidCallback onOpenAnalytics;

  /// Total video count from the server's X-Total-Count header.
  final int? totalVideoCount;

  /// Whether the REST call that resolves [totalVideoCount] is in flight.
  /// When true and [totalVideoCount] is null, the header shows a loading
  /// dash instead of falling back to `videos.length`.
  final bool isFetchingTotalCount;

  /// Optional notifier to trigger BLoC refresh when its value changes.
  final ValueNotifier<int>? refreshNotifier;

  @override
  Widget build(BuildContext context) {
    // If videoIndex is set, show fullscreen video mode
    // Note: videoIndex maps directly to list index (0 = first video, etc.)
    // When videoIndex is null, show grid mode
    return (videoIndex != null && videos.isNotEmpty)
        ? _ProfilePooledFeedView(
            key: ValueKey('profile-feed-$userIdHex'),
            npub: npub,
            userIdHex: userIdHex,
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
            totalVideoCount: totalVideoCount,
            isLoadingVideos: isFetchingTotalCount,
            scrollController: scrollController,
            onSetupProfile: onSetupProfile,
            onEditProfile: onEditProfile,
            onOpenClips: onOpenClips,
            onOpenAnalytics: onOpenAnalytics,
            refreshNotifier: refreshNotifier,
          );
  }
}

/// Embedded pooled video feed for a user's profile.
///
/// Streams video list updates from [profileFeedProvider] into
/// [PooledFullscreenVideoFeedScreen] and keeps the URL in sync via
/// [onPageChanged].
class _ProfilePooledFeedView extends ConsumerStatefulWidget {
  const _ProfilePooledFeedView({
    required this.npub,
    required this.userIdHex,
    required this.videos,
    required this.videoIndex,
    required this.onPageChanged,
    super.key,
  });

  final String npub;
  final String userIdHex;
  final List<VideoEvent> videos;
  final int videoIndex;
  final void Function(int index) onPageChanged;

  @override
  ConsumerState<_ProfilePooledFeedView> createState() =>
      _ProfilePooledFeedViewState();
}

class _ProfilePooledFeedViewState
    extends ConsumerState<_ProfilePooledFeedView> {
  late final StreamController<List<VideoEvent>> _streamController;
  late final StreamController<bool> _hasMoreController;
  List<VideoEvent>? _lastVideos;
  bool? _lastHasMore;

  @override
  void initState() {
    super.initState();
    _streamController = StreamController<List<VideoEvent>>.broadcast();
    _hasMoreController = StreamController<bool>.broadcast();
    // Seed with initial videos so the BLoC receives them on first subscription.
    _pushVideos(widget.videos);
  }

  @override
  void didUpdateWidget(_ProfilePooledFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.videos, oldWidget.videos)) {
      _pushVideos(widget.videos);
    }
  }

  @override
  void dispose() {
    _streamController.close();
    _hasMoreController.close();
    super.dispose();
  }

  void _pushVideos(List<VideoEvent> videos) {
    if (videos.isEmpty) return;
    if (identical(videos, _lastVideos)) return;
    _lastVideos = videos;
    if (!_streamController.isClosed) _streamController.add(videos);
  }

  void _pushHasMore(bool hasMore) {
    if (_lastHasMore == hasMore) return;
    _lastHasMore = hasMore;
    if (!_hasMoreController.isClosed) _hasMoreController.add(hasMore);
  }

  @override
  Widget build(BuildContext context) {
    // Watch feed state only for the hasMoreContent flag; do not push to
    // stream here — that is handled in initState / didUpdateWidget.
    final feedState = ref
        .watch(profileFeedProvider(widget.userIdHex))
        .asData
        ?.value;
    final hasMoreContent = feedState?.hasMoreContent ?? false;
    _pushHasMore(hasMoreContent);
    final safeIndex = widget.videoIndex.clamp(0, widget.videos.length - 1);

    return PooledFullscreenVideoFeedScreen(
      // Pass the raw broadcast stream — startWith already happened in initState.
      videosStream: _streamController.stream,
      initialIndex: safeIndex,
      trafficSource: ViewTrafficSource.profile,
      onLoadMore: hasMoreContent
          ? () => ref
                .read(profileFeedProvider(widget.userIdHex).notifier)
                .loadMore()
          : null,
      hasMoreStream: _hasMoreController.stream.startWith(hasMoreContent),
      onPageChanged: widget.onPageChanged,
    );
  }
}
