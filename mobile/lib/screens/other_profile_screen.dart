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
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/profile/blocked_user_screen.dart';
import 'package:openvine/widgets/profile/profile_block_confirmation_dialog.dart';
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

  const OtherProfileScreen({required this.npub, super.key});

  /// The npub of the user whose profile is being viewed.
  final String npub;

  @override
  ConsumerState<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends ConsumerState<OtherProfileScreen> {
  final ScrollController _scrollController = ScrollController();

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
    final userIdHex = npubToHexOrNull(widget.npub);
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

  Future<void> _more(String userIdHex) async {
    final blocklistService = ref.read(contentBlocklistServiceProvider);
    final isBlocked = blocklistService.isBlocked(userIdHex);

    final result = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: VineTheme.surfaceBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isBlocked ? Icons.check_circle_outline : Icons.block,
                  color: isBlocked ? VineTheme.vineGreen : Colors.red,
                ),
                title: Text(
                  isBlocked ? 'Unblock this user' : 'Block this user',
                  style: VineTheme.bodyLargeFont(
                    color: isBlocked ? VineTheme.vineGreen : Colors.red,
                  ),
                ),
                onTap: () => Navigator.of(modalContext).pop('block'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (result == 'block') {
      await _blockUser(userIdHex, isBlocked);
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.info(
      '🧭 OtherProfileScreen.build for ${widget.npub}',
      name: 'OtherProfileScreen',
    );

    // Convert npub to hex
    final userIdHex = npubToHexOrNull(widget.npub);

    if (userIdHex == null) {
      return _ProfileErrorScreen(
        message: 'Invalid profile ID',
        onBack: context.pop,
      );
    }

    // Check if this user is blocked
    final blocklistService = ref.watch(contentBlocklistServiceProvider);
    if (blocklistService.shouldFilterFromFeeds(userIdHex)) {
      return BlockedUserScreen(onBack: context.pop);
    }

    // Get video data from profile feed
    final videosAsync = ref.watch(profileFeedProvider(userIdHex));

    // Get profile stats
    final profileStatsAsync = ref.watch(fetchProfileStatsProvider(userIdHex));

    // Watch profile reactively to get display name for AppBar
    final profileAsync = ref.watch(userProfileReactiveProvider(userIdHex));
    final displayName = profileAsync.value?.bestDisplayName ?? 'Profile';

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
              onPressed: () => _more(userIdHex),
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
          videos: value.videos,
          profileStatsAsync: profileStatsAsync,
          scrollController: _scrollController,
        ),
      },
    );
  }

  Future<void> _blockUser(String pubkey, bool currentlyBlocked) async {
    if (currentlyBlocked) {
      // Unblock without confirmation
      final blocklistService = ref.read(contentBlocklistServiceProvider);
      blocklistService.unblockUser(pubkey);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User unblocked')));
      }
      return;
    }

    // Show confirmation dialog for blocking
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text('Block User', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You won\'t see their content in feeds. They won\'t be notified. '
          'You can still visit their profile.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final blocklistService = ref.read(contentBlocklistServiceProvider);
      blocklistService.blockUser(pubkey);

      if (mounted) {
        // Show success confirmation
        showDialog(
          context: context,
          useRootNavigator: true,
          builder: (context) => const ProfileBlockConfirmationDialog(),
        );
      }
    }
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
