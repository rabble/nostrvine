// ABOUTME: Fullscreen profile screen for viewing other users (no bottom nav)
// ABOUTME: Pushed on stack from video feeds, profiles, search results, etc.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/clipboard_utils.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_content.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_result.dart';
import 'package:openvine/widgets/profile/profile_grid_view.dart';
import 'package:openvine/widgets/profile/profile_loading_view.dart';

/// Fullscreen profile screen for viewing other users' profiles.
///
/// This screen is pushed outside the shell route so it doesn't show
/// the bottom navigation bar. It provides a fullscreen profile viewing
/// experience with back navigation.
class OtherProfileScreen extends ConsumerStatefulWidget {
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

  /// Optional display name hint for users without Kind 0 profiles (e.g., classic Viners).
  final String? displayNameHint;

  /// Optional avatar URL hint for users without Kind 0 profiles.
  final String? avatarUrlHint;

  @override
  ConsumerState<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends ConsumerState<OtherProfileScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Derived userIdHex from widget.npub - null if invalid npub.
  String? get _userIdHex => npubToHexOrNull(widget.npub);

  @override
  void initState() {
    super.initState();
    _fetchProfileIfNeeded();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _fetchProfileIfNeeded() {
    final userIdHex = _userIdHex;
    if (userIdHex == null) return;

    final userProfileService = ref.read(userProfileServiceProvider);

    // Fetch profile (shows cached immediately, refreshes in background)
    Log.debug(
      '📥 Fetching profile for OtherProfileScreen: $userIdHex',
      name: 'OtherProfileScreen',
      category: LogCategory.ui,
    );
    userProfileService.fetchProfile(userIdHex);
  }

  Future<void> _more() async {
    final userIdHex = _userIdHex!;

    final blocklistService = ref.read(contentBlocklistServiceProvider);
    final isBlocked = blocklistService.isBlocked(userIdHex);

    final followRepository = ref.read(followRepositoryProvider);
    // If NostrClient doesn't have keys yet, treat as not following
    final isFollowing = followRepository?.isFollowing(userIdHex) ?? false;

    // Get display name for actions
    final profile = ref.read(userProfileReactiveProvider(userIdHex)).value;
    final displayName = profile?.bestDisplayName ?? 'user';

    final result = await VineBottomSheet.show<MoreSheetResult>(
      context: context,
      scrollable: false,
      body: StatefulBuilder(
        builder: (context, setState) {
          return MoreSheetContent(
            userIdHex: userIdHex,
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
        final npub = NostrKeyUtils.encodePubKey(userIdHex);
        await ClipboardUtils.copyPubkey(context, npub);
      case MoreSheetResult.unfollow:
        await _unfollowUser();
      case MoreSheetResult.blockConfirmed:
        final blocklistService = ref.read(contentBlocklistServiceProvider);
        blocklistService.blockUser(userIdHex);
        ref.read(blocklistVersionProvider.notifier).increment();
        if (mounted) {
          context.pop();
        }
      case MoreSheetResult.unblockConfirmed:
        final blocklistService = ref.read(contentBlocklistServiceProvider);
        blocklistService.unblockUser(userIdHex);
        ref.read(blocklistVersionProvider.notifier).increment();
    }
  }

  Future<void> _unfollowUser() async {
    final userIdHex = _userIdHex!;
    final profile = ref.read(userProfileReactiveProvider(userIdHex)).value;
    final displayName = profile?.bestDisplayName ?? 'user';

    final followRepository = ref.read(followRepositoryProvider);
    // Can't unfollow if NostrClient doesn't have keys yet
    if (followRepository == null) return;
    await followRepository.toggleFollow(userIdHex);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unfollowed $displayName')));
    }
  }

  Future<void> _showUnblockConfirmation() async {
    final userIdHex = _userIdHex!;
    final profile = ref.read(userProfileReactiveProvider(userIdHex)).value;
    final displayName = profile?.bestDisplayName ?? 'user';

    final result = await VineBottomSheet.show<MoreSheetResult>(
      context: context,
      scrollable: false,
      body: MoreSheetContent(
        userIdHex: userIdHex,
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
      blocklistService.unblockUser(userIdHex);
      ref.read(blocklistVersionProvider.notifier).increment();
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.info(
      '🧭 OtherProfileScreen.build for ${widget.npub}',
      name: 'OtherProfileScreen',
    );

    // Convert npub to hex using getter
    final userIdHex = _userIdHex;

    if (userIdHex == null) {
      return _ProfileErrorScreen(
        message: 'Invalid profile ID',
        onBack: context.pop,
      );
    }

    // Watch blocklist version to trigger rebuilds when block/unblock occurs
    ref.watch(blocklistVersionProvider);

    // Get video data from profile feed
    final videosAsync = ref.watch(profileFeedProvider(userIdHex));

    // Get profile stats
    final profileStatsAsync = ref.watch(fetchProfileStatsProvider(userIdHex));

    // Watch profile reactively to get display name for AppBar
    // Use hint as fallback for users without Kind 0 profiles (e.g., classic Viners)
    final profileAsync = ref.watch(userProfileReactiveProvider(userIdHex));
    final displayName =
        profileAsync.value?.bestDisplayName ??
        widget.displayNameHint ??
        'Profile';

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
          onPressed: context.pop,
        ),
        title: Text(
          displayName,
          style: VineTheme.titleFont(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
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
          userIdHex: userIdHex,
          isOwnProfile: false,
          displayName: displayName,
          videos: value.videos,
          profileStatsAsync: profileStatsAsync,
          scrollController: _scrollController,
          onBlockedTap: _showUnblockConfirmation,
          displayNameHint: widget.displayNameHint,
          avatarUrlHint: widget.avatarUrlHint,
        ),
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
