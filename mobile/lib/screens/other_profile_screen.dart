// ABOUTME: Fullscreen profile screen for viewing other users (no bottom nav)
// ABOUTME: Pushed on stack from video feeds, profiles, search results, etc.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/profile/blocked_user_screen.dart';
import 'package:url_launcher/url_launcher.dart';
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

    final followRepository = ref.read(followRepositoryProvider);
    final isFollowing = followRepository.isFollowing(userIdHex);

    // Get display name for actions
    final profile = ref.read(userProfileReactiveProvider(userIdHex)).value;
    final displayName = profile?.bestDisplayName ?? 'user';

    final result = await VineBottomSheet.show<String>(
      context: context,
      scrollable: false,
      body: StatefulBuilder(
        builder: (context, setState) {
          return _MoreSheetContent(
            userIdHex: userIdHex,
            displayName: displayName,
            isFollowing: isFollowing,
            isBlocked: isBlocked,
          );
        },
      ),
      children: const [], // Required but unused when body is provided
    );

    if (!mounted) return;

    if (result == 'copy') {
      final npub = NostrKeyUtils.encodePubKey(userIdHex);
      await Clipboard.setData(ClipboardData(text: npub));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Public key copied to clipboard')),
        );
      }
    } else if (result == 'unfollow') {
      await _unfollowUser(userIdHex, displayName);
    } else if (result == 'block_confirmed') {
      final blocklistService = ref.read(contentBlocklistServiceProvider);
      blocklistService.blockUser(userIdHex);
      if (mounted) {
        showDialog(
          context: context,
          useRootNavigator: true,
          builder: (context) => const ProfileBlockConfirmationDialog(),
        );
      }
    } else if (result == 'unblock') {
      final blocklistService = ref.read(contentBlocklistServiceProvider);
      blocklistService.unblockUser(userIdHex);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User unblocked')));
      }
    }
  }

  Future<void> _unfollowUser(String userIdHex, String displayName) async {
    final followRepository = ref.read(followRepositoryProvider);
    await followRepository.toggleFollow(userIdHex);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unfollowed $displayName')));
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
          displayName: displayName,
          videos: value.videos,
          profileStatsAsync: profileStatsAsync,
          scrollController: _scrollController,
        ),
      },
    );
  }
}

/// Content widget for the More sheet that manages menu and block confirmation states.
class _MoreSheetContent extends StatefulWidget {
  const _MoreSheetContent({
    required this.userIdHex,
    required this.displayName,
    required this.isFollowing,
    required this.isBlocked,
  });

  final String userIdHex;
  final String displayName;
  final bool isFollowing;
  final bool isBlocked;

  @override
  State<_MoreSheetContent> createState() => _MoreSheetContentState();
}

class _MoreSheetContentState extends State<_MoreSheetContent>
    with SingleTickerProviderStateMixin {
  bool _showingConfirmation = false;
  bool _displayConfirmation = false;
  late AnimationController _controller;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Fade out menu: 0-250ms (0.0-0.333 of total)
    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.333, curve: Curves.easeOut),
      ),
    );

    // Fade in confirmation: 500-750ms (0.667-1.0 of total)
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.667, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _transitionToConfirmation() {
    setState(() => _showingConfirmation = true);
    _controller.forward();

    // Switch displayed content at 200ms (after fade out, before resize completes)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _displayConfirmation = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final opacity = _showingConfirmation
              ? (_displayConfirmation ? _fadeInAnimation.value : 0.0)
              : _fadeOutAnimation.value;

          return Opacity(
            opacity: _showingConfirmation ? opacity : _fadeOutAnimation.value,
            child: _displayConfirmation
                ? _buildBlockConfirmation()
                : _buildMenu(),
          );
        },
      ),
    );
  }

  Widget _buildMenu() {
    return Column(
      key: const ValueKey('menu'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Copy public key action
        InkWell(
          onTap: () => Navigator.of(context).pop('copy'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icon/Copy.svg',
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
        // Unfollow action (only if following)
        if (widget.isFollowing)
          InkWell(
            onTap: () => Navigator.of(context).pop('unfollow'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icon/userMinus.svg',
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      VineTheme.whiteText,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Unfollow ${widget.displayName}',
                    style: VineTheme.titleMediumFont(),
                  ),
                ],
              ),
            ),
          ),
        // Block/Unblock action
        InkWell(
          onTap: () {
            if (widget.isBlocked) {
              Navigator.of(context).pop('unblock');
            } else {
              _transitionToConfirmation();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icon/prohibit.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    widget.isBlocked ? VineTheme.vineGreen : Colors.red,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  widget.isBlocked
                      ? 'Unblock ${widget.displayName}'
                      : 'Block ${widget.displayName}',
                  style: VineTheme.titleMediumFont(
                    color: widget.isBlocked ? VineTheme.vineGreen : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockConfirmation() {
    return Column(
      key: const ValueKey('confirmation'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Block ${widget.displayName}?',
              style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
            ),
          ),
        ),
        // Explanation content
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'When you block a user:',
                style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              _buildBulletPoint('Their posts will not appear in your feeds.'),
              _buildBulletPoint(
                'They will be unable to view your profile, follow you, or view your posts.',
              ),
              _buildBulletPoint('They will not be notified of this change.'),
              _buildBulletPoint(
                'You will still be able to view their profile.',
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () =>
                    launchUrl(Uri.parse('https://divine.video/safety')),
                child: Text.rich(
                  TextSpan(
                    text: 'Learn more at ',
                    style: VineTheme.bodyLargeFont(
                      color: VineTheme.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(
                        text: 'divine.video/safety',
                        style:
                            VineTheme.bodyLargeFont(
                              color: VineTheme.onSurface,
                            ).copyWith(
                              decoration: TextDecoration.underline,
                              decorationColor: VineTheme.vineGreen,
                              decorationThickness: 2,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Button row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              // Cancel button - dismisses the sheet
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: VineTheme.surfaceContainer,
                    foregroundColor: VineTheme.vineGreen,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    side: const BorderSide(
                      color: VineTheme.outlineMuted,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: VineTheme.titleMediumFont(
                      color: VineTheme.vineGreen,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Block button
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop('block_confirmed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Block',
                    style: VineTheme.titleMediumFont(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
          ),
          Expanded(
            child: Text(
              text,
              style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
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
