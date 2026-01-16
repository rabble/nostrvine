// ABOUTME: Fullscreen profile screen for viewing other users (no bottom nav)
// ABOUTME: Pushed on stack from video feeds, profiles, search results, etc.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/profile/blocked_user_screen.dart';
import 'package:openvine/widgets/profile/profile_block_confirmation_dialog.dart';
import 'package:openvine/widgets/profile/profile_grid_view.dart';
import 'package:openvine/widgets/profile/profile_loading_view.dart';
import 'package:share_plus/share_plus.dart';

/// Fullscreen profile screen for viewing other users' profiles.
///
/// This screen is pushed outside the shell route so it doesn't show
/// the bottom navigation bar. It provides a fullscreen profile viewing
/// experience with back navigation.
class OtherProfileScreen extends ConsumerStatefulWidget {
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
        backgroundColor: VineTheme.navGreen,
        foregroundColor: VineTheme.whiteText,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: context.pop,
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
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
          onShareProfile: () => _shareProfile(userIdHex),
          onBlockUser: (isBlocked) => _blockUser(userIdHex, isBlocked),
        ),
      },
    );
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
          name: 'OtherProfileScreen',
          category: LogCategory.ui,
        );
      }
    } catch (e) {
      Log.error(
        'Error sharing profile: $e',
        name: 'OtherProfileScreen',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share profile: $e')));
      }
    }
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
        backgroundColor: VineTheme.navGreen,
        foregroundColor: VineTheme.whiteText,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBack,
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
