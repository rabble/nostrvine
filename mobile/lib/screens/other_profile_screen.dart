// ABOUTME: Profile screen for viewing other users with bottom navigation
// ABOUTME: Pushed on stack from video feeds, profiles, search results, etc.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/other_profile/other_profile_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/user_profile_utils.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_content.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_result.dart';
import 'package:openvine/widgets/profile/profile_grid.dart';
import 'package:openvine/widgets/profile/profile_loading_view.dart';
import 'package:unified_logger/unified_logger.dart';

/// Fullscreen profile screen for viewing other users' profiles.
///
/// This screen is pushed outside the shell route so it doesn't show
/// the bottom navigation bar. It provides a fullscreen profile viewing
/// experience with back navigation.
class OtherProfileScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'profile-view';

  /// Base path for profile view routes.
  static const path = '/profile-view';

  /// Path pattern for this route.
  static const pathWithNpub = '/profile-view/:npub';

  /// Build path for a specific npub.
  static String pathForNpub(String npub) => '$path/$npub';

  const OtherProfileScreen({
    required this.npub,
    this.displayNameHint,
    this.avatarUrlHint,
    super.key,
  });

  /// The npub of the user whose profile is being viewed.
  final String npub;

  /// Optional display name hint for users without Kind 0 profiles.
  final String? displayNameHint;

  /// Optional avatar URL hint for users without Kind 0 profiles.
  final String? avatarUrlHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepository = ref.watch(profileRepositoryProvider);

    if (profileRepository == null) return const BrandedLoadingScaffold();

    final pubkey = npubToHexOrNull(npub);

    if (pubkey == null) {
      return _ProfileErrorScreen(
        message: context.l10n.profileInvalidId,
        onBack: context.pop,
      );
    }

    final blocklistService = ref.watch(contentBlocklistServiceProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final followRepository = ref.watch(followRepositoryProvider);

    return BlocProvider(
      create: (context) => OtherProfileBloc(
        pubkey: pubkey,
        profileRepository: profileRepository,
        contentBlocklistService: blocklistService,
        currentUserPubkey: nostrClient.publicKey,
        followRepository: followRepository,
      )..add(const OtherProfileLoadRequested()),
      child: OtherProfileView(
        pubkey: pubkey,
        displayNameHint: displayNameHint,
        avatarUrlHint: avatarUrlHint,
      ),
    );
  }
}

/// Internal view widget for OtherProfileScreen.
///
/// Contains the actual UI implementation. The parent [OtherProfileScreen]
/// handles BLoC creation and npub validation.
class OtherProfileView extends ConsumerStatefulWidget {
  const OtherProfileView({
    required this.pubkey,
    this.displayNameHint,
    this.avatarUrlHint,
    super.key,
  });

  /// The hex pubkey of the profile being viewed.
  final String pubkey;

  /// Optional display name hint for users without Kind 0 profiles (e.g., classic Viners).
  final String? displayNameHint;

  /// Optional avatar URL hint for users without Kind 0 profiles.
  final String? avatarUrlHint;

  @override
  ConsumerState<OtherProfileView> createState() => _OtherProfileViewState();
}

class _OtherProfileViewState extends ConsumerState<OtherProfileView> {
  final ScrollController _scrollController = ScrollController();

  /// Notifier to trigger refresh of profile BLoCs (likes, reposts).
  final _refreshNotifier = ValueNotifier<int>(0);

  /// Whether a refresh is currently in progress.
  bool _isRefreshing = false;

  /// Whether the profile feed load has been tracked.
  bool _hasTrackedFeedLoad = false;

  @override
  void initState() {
    super.initState();
    FeedPerformanceTracker().startFeedLoad('profile');
    // Refresh stale profile data on navigation (fixes #2163)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(profileFeedProvider(widget.pubkey).notifier).refreshIfStale();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshNotifier.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      // Run refresh operations and minimum duration in parallel
      // This ensures the spinner shows for at least 500ms for visual feedback
      await Future.wait([
        _doRefresh(),
        Future<void>.delayed(const Duration(milliseconds: 500)),
      ]);

      Log.info(
        '🔄 Profile refreshed for ${widget.pubkey}',
        name: 'OtherProfileView',
        category: LogCategory.ui,
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _doRefresh() async {
    // Refresh videos from provider
    await ref.read(profileFeedProvider(widget.pubkey).notifier).refresh();

    if (!mounted) return;

    // Refresh user profile info
    context.read<OtherProfileBloc>().add(const OtherProfileRefreshRequested());

    // Trigger BLoC refresh for likes/reposts via notifier
    _refreshNotifier.value++;
  }

  Future<void> _more() async {
    final otherProfileBloc = context.read<OtherProfileBloc>();
    final isBlocked = otherProfileBloc.isBlocked;
    final isFollowing = otherProfileBloc.isFollowing;

    // Get display name for actions (match pattern from build())
    final profile = ref.read(userProfileReactiveProvider(widget.pubkey)).value;
    final displayName =
        profile?.bestDisplayName ?? widget.displayNameHint ?? 'user';

    final result = await VineBottomSheet.show<MoreSheetResult>(
      context: context,
      scrollable: false,
      body: StatefulBuilder(
        builder: (context, setState) {
          return MoreSheetContent(
            userIdHex: widget.pubkey,
            displayName: displayName,
            isFollowing: isFollowing,
            isBlocked: isBlocked,
          );
        },
      ),
      children: const [], // Required but unused when body is provided
    );

    if (!mounted || result == null) return;

    switch (result) {
      case MoreSheetResult.copy:
        final npub = NostrKeyUtils.encodePubKey(widget.pubkey);
        await ClipboardUtils.copyPubkey(context, npub);
      case MoreSheetResult.unfollow:
        await _unfollowUser();
      case MoreSheetResult.blockConfirmed:
        context.read<OtherProfileBloc>().add(
          const OtherProfileBlockRequested(),
        );
        if (mounted) {
          final profile = ref
              .read(userProfileReactiveProvider(widget.pubkey))
              .value;
          final name =
              profile?.bestDisplayName ?? widget.displayNameHint ?? 'User';
          // TODO(SofiaRey): revisit when designs are ready
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            SnackBar(content: Text(context.l10n.profileBlockedUser(name))),
          );
          context.pop();
        }
      case MoreSheetResult.unblockConfirmed:
        context.read<OtherProfileBloc>().add(
          const OtherProfileUnblockRequested(),
        );
        if (mounted) {
          final profile = ref
              .read(userProfileReactiveProvider(widget.pubkey))
              .value;
          final name =
              profile?.bestDisplayName ?? widget.displayNameHint ?? 'User';
          // TODO(SofiaRey): revisit when designs are ready
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            SnackBar(
              content: Text(context.l10n.profileUnblockedUser(name)),
            ),
          );
        }
    }
  }

  Future<void> _unfollowUser() async {
    final profile = ref.read(userProfileReactiveProvider(widget.pubkey)).value;
    final displayName =
        profile?.bestDisplayName ?? widget.displayNameHint ?? 'user';

    final followRepository = ref.read(followRepositoryProvider);
    await followRepository.toggleFollow(widget.pubkey);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(context.l10n.profileUnfollowedUser(displayName)),
        ),
      );
    }
  }

  Future<void> _showUnblockConfirmation() async {
    final profile = ref.read(userProfileReactiveProvider(widget.pubkey)).value;
    final displayName =
        profile?.bestDisplayName ?? widget.displayNameHint ?? 'user';

    final result = await VineBottomSheet.show<MoreSheetResult>(
      context: context,
      scrollable: false,
      body: MoreSheetContent(
        userIdHex: widget.pubkey,
        displayName: displayName,
        isFollowing: false,
        isBlocked: true,
        initialMode: MoreSheetMode.unblockConfirmation,
      ),
      children: const [],
    );

    if (!mounted) return;

    if (result == MoreSheetResult.unblockConfirmed) {
      if (!mounted) return;
      context.read<OtherProfileBloc>().add(
        const OtherProfileUnblockRequested(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.info(
      '🧭 OtherProfileView.build for ${widget.pubkey}',
      name: 'OtherProfileView',
    );

    // Watch blocklist version to trigger rebuilds when block/unblock occurs
    ref.watch(blocklistVersionProvider);

    // Get video data from profile feed
    final videosAsync = ref.watch(profileFeedProvider(widget.pubkey));
    // Track analytics when data is loaded
    if (videosAsync is AsyncData) {
      ScreenAnalyticsService().markDataLoaded(
        'other_profile',
        dataMetrics: {
          'video_count': videosAsync.asData?.value.videos.length ?? 0,
        },
      );

      if (!_hasTrackedFeedLoad) {
        _hasTrackedFeedLoad = true;
        final count = videosAsync.asData?.value.videos.length ?? 0;
        final tracker = FeedPerformanceTracker();
        tracker.markFirstVideosReceived('profile', count);
        tracker.markFeedDisplayed('profile', count);
      }
    }

    return BlocBuilder<OtherProfileBloc, OtherProfileState>(
      builder: (context, state) {
        final headerProfile = switch (state) {
          OtherProfileInitial() => null,
          OtherProfileLoading(:final profile) => profile,
          OtherProfileLoaded(:final profile) => profile,
          OtherProfileError(:final profile) => profile,
        };
        final profileColor = headerProfile?.profileBackgroundColor;

        final displayName =
            headerProfile?.bestDisplayName ??
            widget.displayNameHint ??
            'Profile';

        return Scaffold(
          backgroundColor: VineTheme.backgroundColor,
          appBar: DiVineAppBar(
            title: displayName,
            showBackButton: true,
            onBackPressed: context.pop,
            backgroundColor: profileColor ?? VineTheme.navGreen,
            actions: [
              DiVineAppBarAction(
                icon: _isRefreshing
                    ? const MaterialIconSource(Icons.refresh)
                    : SvgIconSource(
                        DivineIconName.arrowsCounterClockwise.assetPath,
                      ),
                onPressed: _isRefreshing ? null : _refreshProfile,
                tooltip: context.l10n.profileRefresh,
                semanticLabel: context.l10n.profileRefreshLabel,
              ),
              DiVineAppBarAction(
                icon: SvgIconSource(DivineIconName.dotsThree.assetPath),
                onPressed: _more,
                semanticLabel: context.l10n.profileMoreOptions,
              ),
            ],
          ),
          body: switch (videosAsync) {
            AsyncLoading() => const ProfileLoadingView(),
            AsyncError(:final error) => Center(
              child: Text(
                context.l10n.profileError('$error'),
                style: const TextStyle(color: VineTheme.whiteText),
              ),
            ),
            AsyncData(:final value) => ProfileGridView(
              userIdHex: widget.pubkey,
              isOwnProfile: false,
              profile: headerProfile,
              displayName: displayName,
              videos: value.videos,
              totalVideoCount: value.totalVideoCount,
              scrollController: _scrollController,
              onBlockedTap: _showUnblockConfirmation,
              displayNameHint: widget.displayNameHint,
              avatarUrlHint: widget.avatarUrlHint,
              refreshNotifier: _refreshNotifier,
            ),
          },
        );
      },
    );
  }
}

class _ProfileErrorScreen extends StatelessWidget {
  const _ProfileErrorScreen({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: DiVineAppBar(
        title: context.l10n.profileTitle,
        showBackButton: true,
        onBackPressed: onBack,
      ),
      body: Center(
        child: Text(
          message,
          style: const TextStyle(color: VineTheme.whiteText),
        ),
      ),
    );
  }
}
