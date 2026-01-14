// ABOUTME: Router-driven Instagram-style profile screen implementation
// ABOUTME: Uses CustomScrollView with slivers for smooth scrolling, URL is source of truth

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';
import 'package:openvine/widgets/profile/blocked_user_screen.dart';
import 'package:openvine/widgets/profile/profile_block_confirmation_dialog.dart';
import 'package:openvine/widgets/profile/profile_grid_view.dart';
import 'package:openvine/widgets/profile/profile_loading_view.dart';
import 'package:openvine/widgets/profile/profile_video_feed_view.dart';
import 'package:share_plus/share_plus.dart';

/// Router-driven ProfileScreen - Instagram-style scrollable profile
class ProfileScreenRouter extends ConsumerStatefulWidget {
  const ProfileScreenRouter({super.key});

  @override
  ConsumerState<ProfileScreenRouter> createState() =>
      _ProfileScreenRouterState();
}

class _ProfileScreenRouterState extends ConsumerState<ProfileScreenRouter>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Log.info('🧭 ProfileScreenRouter.build', name: 'ProfileScreenRouter');

    // Read derived context from router
    final pageContext = ref.watch(pageContextProvider);

    return switch (pageContext) {
      AsyncLoading() => const ProfileLoadingView(),
      AsyncError(:final error) => Center(child: Text('Error: $error')),
      AsyncData(:final value) => _ProfileContentView(
        routeContext: value,
        scrollController: _scrollController,
        onFetchProfile: _fetchProfileIfNeeded,
        onSetupProfile: _setupProfile,
        onEditProfile: _editProfile,
        onOpenClips: _openClips,
        onShareProfile: _shareProfile,
        onBlockUser: _blockUser,
      ),
    };
  }

  // Action methods

  Future<void> _setupProfile() async {
    // Navigate to setup-profile route (defined outside ShellRoute)
    await context.push('/setup-profile');
  }

  Future<void> _editProfile() async {
    // Show menu with Edit Profile and Delete Account options
    // Note: Using showModalBottomSheet with Navigator.pop because GoRouter
    // has known issues with ModalBottomSheetRoute (see flutter/flutter#100933)
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: VineTheme.cardBackground,
      builder: (modalContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: VineTheme.vineGreen),
              title: const Text(
                'Edit Profile',
                style: TextStyle(color: VineTheme.whiteText),
              ),
              subtitle: const Text(
                'Update your display name, bio, and avatar',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
              ),
              onTap: () => Navigator.of(modalContext).pop('edit'),
            ),
            const Divider(color: VineTheme.secondaryText, height: 1),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Delete Account and Data',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text(
                'PERMANENTLY delete your account and all content',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
              ),
              onTap: () => Navigator.of(modalContext).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (result == 'edit') {
      // Navigate to edit-profile route (defined outside ShellRoute)
      await context.push('/edit-profile');
    } else if (result == 'delete') {
      _handleDeleteAccount();
    }
  }

  Future<void> _handleDeleteAccount() async {
    final deletionService = ref.read(accountDeletionServiceProvider);
    final authService = ref.read(authServiceProvider);

    // Get current user's public key for nsec verification
    final currentPublicKeyHex = authService.currentPublicKeyHex;
    if (currentPublicKeyHex == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to verify identity. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show nsec verification dialog first, then standard delete dialog
    await showDeleteAllContentWarningDialog(
      context: context,
      currentPublicKeyHex: currentPublicKeyHex,
      onConfirm: () async {
        // Show loading indicator
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
        );

        // Execute NIP-62 deletion request
        final result = await deletionService.deleteAccount();

        // Close loading indicator
        if (!context.mounted) return;
        context.pop();

        if (result.success) {
          // Sign out and delete keys
          await authService.signOut(deleteKeys: true);

          // Show completion dialog
          if (!context.mounted) return;
          await showDeleteAccountCompletionDialog(
            context: context,
            onCreateNewAccount: () {
              context.go('/setup-profile');
            },
          );
        } else {
          // Show error
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.error ?? 'Failed to delete content from relays',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
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
    context.push('/clips');
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
        title: const Text('Block @', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You won\'t see their content in feeds. They won\'t be notified. You can still visit their profile.',
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
        // Show success confirmation using root navigator
        showDialog(
          context: context,
          useRootNavigator: true,
          builder: (context) => const ProfileBlockConfirmationDialog(),
        );
      }
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
    required this.onShareProfile,
    required this.onBlockUser,
  });

  final RouteContext routeContext;
  final ScrollController scrollController;
  final void Function(String userIdHex, bool isOwnProfile) onFetchProfile;
  final VoidCallback onSetupProfile;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenClips;
  final void Function(String userIdHex) onShareProfile;
  final void Function(String pubkey, bool isBlocked) onBlockUser;

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
    final blocklistService = ref.watch(contentBlocklistServiceProvider);
    if (blocklistService.shouldFilterFromFeeds(userIdHex)) {
      return BlockedUserScreen(onBack: context.pop);
    }

    // Fetch profile data if needed (post-frame to avoid build mutations)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onFetchProfile(userIdHex, isOwnProfile);
    });

    return _ProfileDataView(
      npub: npub,
      userIdHex: userIdHex,
      isOwnProfile: isOwnProfile,
      videoIndex: routeContext.videoIndex,
      scrollController: scrollController,
      onSetupProfile: onSetupProfile,
      onEditProfile: onEditProfile,
      onOpenClips: onOpenClips,
      onShareProfile: () => onShareProfile(userIdHex),
      onBlockUser: (isBlocked) => onBlockUser(userIdHex, isBlocked),
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
        GoRouter.of(context).go('/home/0');
      });
      return const Center(child: CircularProgressIndicator());
    }

    // Get current user's npub and redirect (preserve grid/feed mode from context)
    final currentUserNpub = NostrKeyUtils.encodePubKey(
      authService.currentPublicKeyHex!,
    );

    // Redirect to actual user profile using GoRouter explicitly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use context extension to properly handle null videoIndex (grid mode)
      if (videoIndex != null) {
        context.goProfile(currentUserNpub, videoIndex!);
      } else {
        context.goProfileGrid(currentUserNpub);
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
    required this.onShareProfile,
    required this.onBlockUser,
  });

  final String npub;
  final String userIdHex;
  final bool isOwnProfile;
  final int? videoIndex;
  final ScrollController scrollController;
  final VoidCallback onSetupProfile;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenClips;
  final VoidCallback onShareProfile;
  final void Function(bool isBlocked) onBlockUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get video data from profile feed
    final videosAsync = ref.watch(profileFeedProvider(userIdHex));

    // Get profile stats
    final profileStatsAsync = ref.watch(fetchProfileStatsProvider(userIdHex));

    return switch (videosAsync) {
      AsyncLoading() => const ProfileLoadingView(),
      AsyncError(:final error) => Center(child: Text('Error: $error')),
      AsyncData(:final value) => _ProfileViewSwitcher(
        npub: npub,
        userIdHex: userIdHex,
        isOwnProfile: isOwnProfile,
        videos: value.videos,
        videoIndex: videoIndex,
        profileStatsAsync: profileStatsAsync,
        scrollController: scrollController,
        onSetupProfile: onSetupProfile,
        onEditProfile: onEditProfile,
        onOpenClips: onOpenClips,
        onShareProfile: onShareProfile,
        onBlockUser: onBlockUser,
      ),
    };
  }
}

/// Switches between grid view and video feed view based on videoIndex.
class _ProfileViewSwitcher extends StatelessWidget {
  const _ProfileViewSwitcher({
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
    required this.onShareProfile,
    required this.onBlockUser,
  });

  final String npub;
  final String userIdHex;
  final bool isOwnProfile;
  final List<VideoEvent> videos;
  final int? videoIndex;
  final AsyncValue<ProfileStats> profileStatsAsync;
  final ScrollController scrollController;
  final VoidCallback onSetupProfile;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenClips;
  final VoidCallback onShareProfile;
  final void Function(bool isBlocked) onBlockUser;

  @override
  Widget build(BuildContext context) {
    // If videoIndex is set, show fullscreen video mode
    // Note: videoIndex maps directly to list index (0 = first video, 1 = second video, etc.)
    // When videoIndex is null, show grid mode
    if (videoIndex != null && videos.isNotEmpty) {
      return ProfileVideoFeedView(
        npub: npub,
        userIdHex: userIdHex,
        isOwnProfile: isOwnProfile,
        videos: videos,
        videoIndex: videoIndex!,
        onPageChanged: (newIndex) => context.goProfile(npub, newIndex),
      );
    }

    // Otherwise show Instagram-style grid view
    return ProfileGridView(
      userIdHex: userIdHex,
      isOwnProfile: isOwnProfile,
      videos: videos,
      profileStatsAsync: profileStatsAsync,
      scrollController: scrollController,
      onSetupProfile: onSetupProfile,
      onEditProfile: onEditProfile,
      onOpenClips: onOpenClips,
      onShareProfile: onShareProfile,
      onBlockUser: onBlockUser,
    );
  }
}
