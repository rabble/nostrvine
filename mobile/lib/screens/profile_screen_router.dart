// ABOUTME: Router-driven Instagram-style profile screen implementation
// ABOUTME: Uses CustomScrollView with slivers for smooth scrolling, URL is source of truth

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
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/profile_setup_screen.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/widgets/profile/blocked_user_screen.dart';
import 'package:openvine/widgets/profile/profile_grid.dart';
import 'package:openvine/widgets/profile/profile_loading_view.dart';
import 'package:openvine/widgets/profile/profile_video_feed_view.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';
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
        onEditProfile: _editProfile,
        onOpenClips: _openClips,
        onMore: _more,
        onShareProfile: _shareProfile,
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
        child: _ProfileScaffold(body: content),
      );
    }

    return content;
  }

  // Action methods

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

  Future<void> _more(String userIdHex) async {
    final result = await VineBottomSheet.show<String>(
      context: context,
      scrollable: false,
      children: [
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

    if (result == 'copy_npub') {
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

class _ProfileScaffold extends StatelessWidget {
  const _ProfileScaffold({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
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
    required this.onEditProfile,
    required this.onOpenClips,
    required this.onMore,
    required this.onShareProfile,
    required this.refreshNotifier,
  });

  final RouteContext routeContext;
  final ScrollController scrollController;
  final void Function(String userIdHex, bool isOwnProfile) onFetchProfile;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenClips;
  final void Function(String userIdHex) onMore;
  final void Function(String userIdHex) onShareProfile;
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
      onEditProfile: onEditProfile,
      onOpenClips: onOpenClips,
      onMore: onMore,
      onShareProfile: onShareProfile,
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
    required this.onEditProfile,
    required this.onOpenClips,
    required this.onMore,
    required this.onShareProfile,
    required this.refreshNotifier,
    this.displayName,
  });

  final String npub;
  final String userIdHex;
  final bool isOwnProfile;
  final String? displayName;
  final int? videoIndex;
  final ScrollController scrollController;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenClips;
  final void Function(String userIdHex) onMore;
  final void Function(String userIdHex) onShareProfile;
  final ValueNotifier<int> refreshNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get video data and stats from providers
    final videosAsync = ref.watch(profileFeedProvider(userIdHex));
    final profileStats = ref
        .watch(
          userProfileStatsReactiveProvider(userIdHex),
        )
        .value;

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
          profileStats: profileStats,
          videos: value.videos,
          videoIndex: videoIndex,
          scrollController: scrollController,
          onEditProfile: onEditProfile,
          onOpenClips: onOpenClips,
          onMore: onMore,
          onShareProfile: onShareProfile,
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
    required this.onOpenClips,
    required this.onMore,
    required this.onShareProfile,
    this.onEditProfile,
    this.profileStats,
    this.refreshNotifier,
    this.displayName,
    super.key,
  });

  final String npub;
  final String userIdHex;
  final bool isOwnProfile;
  final String? displayName;
  final ProfileStats? profileStats;
  final List<VideoEvent> videos;
  final int? videoIndex;
  final ScrollController scrollController;
  final VoidCallback? onEditProfile;
  final VoidCallback onOpenClips;
  final void Function(String userIdHex) onMore;
  final void Function(String userIdHex) onShareProfile;

  /// Optional notifier to trigger BLoC refresh when its value changes.
  final ValueNotifier<int>? refreshNotifier;

  @override
  Widget build(BuildContext context) {
    // If videoIndex is set, show fullscreen video mode
    // Note: videoIndex maps directly to list index (0 = first video, etc.)
    // When videoIndex is null, show grid mode
    return (videoIndex != null && videos.isNotEmpty)
        ? ProfileVideoFeedView(
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
            profileStats: profileStats,
            videos: videos,
            scrollController: scrollController,
            onEditProfile: onEditProfile,
            onOpenClips: onOpenClips,
            onMore: () => onMore(userIdHex),
            onShareProfile: () => onShareProfile(userIdHex),
            refreshNotifier: refreshNotifier,
          );
  }
}
