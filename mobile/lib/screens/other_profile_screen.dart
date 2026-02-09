// ABOUTME: Profile screen for viewing other users with bottom navigation
// ABOUTME: Pushed on stack from video feeds, profiles, search results, etc.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/other_profile/other_profile_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_content.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_result.dart';
import 'package:openvine/widgets/profile/profile_grid_view.dart';
import 'package:openvine/widgets/profile/profile_loading_view.dart';

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

    if (profileRepository == null) return BrandedLoadingScaffold();

    final pubkey = npubToHexOrNull(npub);

    if (pubkey == null)
      return _ProfileErrorScreen(
        message: 'Invalid profile ID',
        onBack: context.pop,
      );

    return BlocProvider(
      create: (context) =>
          OtherProfileBloc(pubkey: pubkey, profileRepository: profileRepository)
            ..add(OtherProfileLoadRequested()),
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

  @override
  void initState() {
    super.initState();
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

    // Invalidate stats to recompute
    ref.invalidate(fetchProfileStatsProvider(widget.pubkey));

    // Refresh user profile info
    context.read<OtherProfileBloc>().add(OtherProfileRefreshRequested());

    // Trigger BLoC refresh for likes/reposts via notifier
    _refreshNotifier.value++;
  }

  Future<void> _more() async {
    final blocklistService = ref.read(contentBlocklistServiceProvider);
    final isBlocked = blocklistService.isBlocked(widget.pubkey);

    final followRepository = ref.read(followRepositoryProvider);
    // If NostrClient doesn't have keys yet, treat as not following
    final isFollowing = followRepository?.isFollowing(widget.pubkey) ?? false;

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
        final blocklistService = ref.read(contentBlocklistServiceProvider);
        final nostrClient = ref.read(nostrServiceProvider);
        blocklistService.blockUser(
          widget.pubkey,
          ourPubkey: nostrClient.publicKey,
        );
        ref.read(blocklistVersionProvider.notifier).increment();
        if (mounted) {
          context.pop();
        }
      case MoreSheetResult.unblockConfirmed:
        final blocklistService = ref.read(contentBlocklistServiceProvider);
        blocklistService.unblockUser(widget.pubkey);
        ref.read(blocklistVersionProvider.notifier).increment();
    }
  }

  Future<void> _unfollowUser() async {
    final profile = ref.read(userProfileReactiveProvider(widget.pubkey)).value;
    final displayName =
        profile?.bestDisplayName ?? widget.displayNameHint ?? 'user';

    final followRepository = ref.read(followRepositoryProvider);
    // Can't unfollow if NostrClient doesn't have keys yet
    if (followRepository == null) return;
    await followRepository.toggleFollow(widget.pubkey);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unfollowed $displayName')));
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
      final blocklistService = ref.read(contentBlocklistServiceProvider);
      blocklistService.unblockUser(widget.pubkey);
      ref.read(blocklistVersionProvider.notifier).increment();
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

    // Get profile stats
    final profileStatsAsync = ref.watch(
      fetchProfileStatsProvider(widget.pubkey),
    );

    // Watch profile reactively to get display name for AppBar
    // Use hint as fallback for users without Kind 0 profiles (e.g., classic Viners)
    final profileAsync = ref.watch(userProfileReactiveProvider(widget.pubkey));
    final profile = profileAsync.value;
    // Get profile color for Vine-style colored header
    final profileColor = profile?.profileBackgroundColor;

    // Track analytics when data is loaded
    if (videosAsync is AsyncData && profileAsync is AsyncData) {
      ScreenAnalyticsService().markDataLoaded(
        'other_profile',
        dataMetrics: {
          'video_count': videosAsync.asData?.value.videos.length ?? 0,
        },
      );
    }

    return BlocBuilder<OtherProfileBloc, OtherProfileState>(
      builder: (context, state) {
        final profile = switch (state) {
          OtherProfileInitial() => null,
          OtherProfileLoading(:final profile) => profile,
          OtherProfileLoaded(:final profile) => profile,
          OtherProfileError(:final profile) => profile,
        };

        final displayName =
            profile?.bestDisplayName ?? widget.displayNameHint ?? 'Profile';

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 72,
            leadingWidth: 80,
            centerTitle: false,
            titleSpacing: 0,
            backgroundColor: profileColor ?? VineTheme.navGreen,
            leading: IconButton(
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
                  'assets/icon/CaretLeft.svg',
                  width: 32,
                  height: 32,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              onPressed: context.pop,
            ),
            title: Text(
              displayName,
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
                onPressed: _isRefreshing ? null : _refreshProfile,
              ),
              const SizedBox(width: 8),
              // More button
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
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
                  onPressed: _more,
                ),
              ),
            ],
          ),
          body: switch (videosAsync) {
            AsyncLoading() => const ProfileLoadingView(),
            AsyncError(:final error) => Center(
              child: Text(
                'Error: $error',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            AsyncData(:final value) => ProfileGridView(
              userIdHex: widget.pubkey,
              isOwnProfile: false,
              displayName: displayName,
              videos: value.videos,
              profileStatsAsync: profileStatsAsync,
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leadingWidth: 80,
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: VineTheme.navGreen,
        leading: IconButton(
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
              'assets/icon/CaretLeft.svg',
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
          onPressed: onBack,
        ),
        title: Text(
          'Profile',
          style: VineTheme.titleFont(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
