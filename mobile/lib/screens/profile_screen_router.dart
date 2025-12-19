// ABOUTME: Router-driven Instagram-style profile screen implementation
// ABOUTME: Uses CustomScrollView with slivers for smooth scrolling, URL is source of truth

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/helpers/follow_actions_helper.dart';
import 'package:openvine/mixins/async_value_ui_helpers_mixin.dart';
import 'package:openvine/mixins/page_controller_sync_mixin.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/followers_screen.dart';
import 'package:openvine/screens/following_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';
import 'package:openvine/widgets/profile/profile_action_buttons_widget.dart';
import 'package:openvine/widgets/profile/profile_block_confirmation_dialog.dart';
import 'package:openvine/widgets/profile/profile_liked_grid.dart';
import 'package:openvine/widgets/profile/profile_reposts_grid.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';
import 'package:openvine/widgets/profile/profile_videos_grid.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:share_plus/share_plus.dart';

/// Router-driven ProfileScreen - Instagram-style scrollable profile
class ProfileScreenRouter extends ConsumerStatefulWidget {
  const ProfileScreenRouter({super.key});

  @override
  ConsumerState<ProfileScreenRouter> createState() =>
      _ProfileScreenRouterState();
}

class _ProfileScreenRouterState extends ConsumerState<ProfileScreenRouter>
    with
        TickerProviderStateMixin,
        VideoPrefetchMixin,
        PageControllerSyncMixin,
        AsyncValueUIHelpersMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  PageController? _videoController; // For fullscreen video mode
  int? _lastVideoUrlIndex; // Track URL changes for video mode

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // NOTE: Router-driven architecture - active video automatically updates based on URL
    // No manual state management needed - tab changes trigger route changes which update activeVideoIdProvider
  }

  void _fetchProfileIfNeeded(String userIdHex, bool isOwnProfile) {
    if (isOwnProfile) return; // Own profile loads automatically

    final userProfileService = ref.read(userProfileServiceProvider);

    // Fetch profile (shows cached immediately, refreshes in background)
    if (!userProfileService.hasProfile(userIdHex)) {
      Log.debug(
        '📥 Fetching uncached profile: ${userIdHex}',
        name: 'ProfileScreenRouter',
        category: LogCategory.ui,
      );
      userProfileService.fetchProfile(userIdHex);
    } else {
      Log.debug(
        '📋 Using cached profile: ${userIdHex}',
        name: 'ProfileScreenRouter',
        category: LogCategory.ui,
      );
      // Still call fetchProfile to trigger background refresh if needed
      userProfileService.fetchProfile(userIdHex);
    }
  }

  void _navigateToFollowers(
    BuildContext context,
    String pubkey,
    String displayName,
  ) {
    // Navigate using root navigator to escape shell route
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) =>
            FollowersScreen(pubkey: pubkey, displayName: displayName),
      ),
    );
  }

  void _navigateToFollowing(
    BuildContext context,
    String pubkey,
    String displayName,
  ) {
    // Navigate using root navigator to escape shell route
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) =>
            FollowingScreen(pubkey: pubkey, displayName: displayName),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Log.info('🧭 ProfileScreenRouter.build', name: 'ProfileScreenRouter');

    // Read derived context from router
    final pageContext = ref.watch(pageContextProvider);

    return buildAsyncUI(
      pageContext,
      onData: (ctx) {
        // Only handle profile routes
        if (ctx.type != RouteType.profile) {
          return const Center(child: Text('Not a profile route'));
        }

        // Convert npub to hex for profile feed provider
        final npub = ctx.npub ?? '';

        // Handle "me" special case - redirect to actual user profile
        if (npub == 'me') {
          final authService = ref.watch(authServiceProvider);
          if (!authService.isAuthenticated ||
              authService.currentPublicKeyHex == null) {
            // Not authenticated - redirect to home
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                GoRouter.of(context).go('/home/0');
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          // Get current user's npub and redirect (preserve grid/feed mode from context)
          final currentUserNpub = NostrKeyUtils.encodePubKey(
            authService.currentPublicKeyHex!,
          );
          final videoIndex = ctx
              .videoIndex; // Don't default to 0 - preserve null for grid mode

          // Redirect to actual user profile using GoRouter explicitly
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Use context extension to properly handle null videoIndex (grid mode)
              if (videoIndex != null) {
                context.goProfile(currentUserNpub, videoIndex);
              } else {
                context.goProfileGrid(currentUserNpub);
              }
            }
          });

          // Show loading while redirecting
          return const Center(child: CircularProgressIndicator());
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
          return Scaffold(
            backgroundColor: VineTheme.backgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: const Center(
              child: Text(
                'This account is not available',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          );
        }

        // Get video data from profile feed
        final videosAsync = ref.watch(profileFeedProvider(userIdHex));

        // Get profile stats
        final profileStatsAsync = ref.watch(
          fetchProfileStatsProvider(userIdHex),
        );

        // Fetch profile data if needed (post-frame to avoid build mutations)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _fetchProfileIfNeeded(userIdHex, isOwnProfile);
          }
        });

        // Check if we should show fullscreen video mode (videoIndex > 0)
        final videoIndex = ctx.videoIndex;

        // Show main profile UI
        return buildAsyncUI(
          videosAsync,
          onData: (state) {
            final videos = state.videos;

            // If videoIndex is set, show fullscreen video mode
            // Note: videoIndex maps directly to list index (0 = first video, 1 = second video, etc.)
            // When videoIndex is null, show grid mode
            if (videoIndex != null && videos.isNotEmpty) {
              // videoIndex IS the list index - no conversion needed
              final listIndex = videoIndex;
              final safeIndex = listIndex.clamp(0, videos.length - 1);

              Log.debug(
                '🎬 ProfileScreenRouter video mode: videoIndex=$videoIndex, listIndex=$listIndex, safeIndex=$safeIndex, '
                'videos.length=${videos.length}, controllerExists=${_videoController != null}, '
                'lastUrlIndex=$_lastVideoUrlIndex',
                name: 'ProfileScreenRouter',
                category: LogCategory.video,
              );

              // Initialize controller once with URL index
              if (_videoController == null) {
                Log.info(
                  '🆕 Creating PageController with initialPage=$safeIndex for videoIndex=$videoIndex',
                  name: 'ProfileScreenRouter',
                  category: LogCategory.video,
                );
                _videoController = PageController(initialPage: safeIndex);
                _lastVideoUrlIndex =
                    listIndex; // Track URL index, not safe index
              } else {
                // Sync controller when URL changes externally (back/forward/deeplink)
                // OR when videos list changes (e.g., provider reloads)
                // Only sync if controller already exists - initialPage handles first navigation
                final targetIndex = listIndex.clamp(0, videos.length - 1);
                final currentPage = _videoController!.hasClients
                    ? _videoController!.page?.round()
                    : null;

                Log.debug(
                  '🔄 Checking sync: urlIndex=$listIndex, lastUrlIndex=$_lastVideoUrlIndex, '
                  'hasClients=${_videoController!.hasClients}, currentPage=$currentPage, targetIndex=$targetIndex',
                  name: 'ProfileScreenRouter',
                  category: LogCategory.video,
                );

                if (shouldSync(
                  urlIndex: listIndex,
                  lastUrlIndex: _lastVideoUrlIndex,
                  controller: _videoController,
                  targetIndex: targetIndex,
                )) {
                  Log.info(
                    '📍 Syncing PageController: $currentPage → $targetIndex',
                    name: 'ProfileScreenRouter',
                    category: LogCategory.video,
                  );
                  _lastVideoUrlIndex = listIndex;
                  syncPageController(
                    controller: _videoController!,
                    targetIndex: listIndex,
                    itemCount: videos.length,
                  );
                }
              }

              // Pre-initialize controllers for adjacent videos on initial build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                preInitializeControllers(
                  ref: ref,
                  currentIndex: safeIndex,
                  videos: videos,
                );
              });

              // Build fullscreen video PageView
              return PageView.builder(
                key: const Key('profile-video-page-view'),
                controller: _videoController,
                scrollDirection: Axis.vertical,
                itemCount: videos.length,
                onPageChanged: (newIndex) {
                  // Update URL when swiping to stay in profile context
                  // videoIndex maps directly to list index (no conversion needed)
                  if (newIndex != videoIndex) {
                    context.goProfile(npub, newIndex);
                  }

                  // Trigger pagination near end
                  if (newIndex >= videos.length - 2) {
                    ref
                        .read(profileFeedProvider(userIdHex).notifier)
                        .loadMore();
                  }

                  // Prefetch videos around current index
                  checkForPrefetch(currentIndex: newIndex, videos: videos);

                  // Pre-initialize controllers for adjacent videos
                  preInitializeControllers(
                    ref: ref,
                    currentIndex: newIndex,
                    videos: videos,
                  );

                  // Dispose controllers outside the keep range to free memory
                  disposeControllersOutsideRange(
                    ref: ref,
                    currentIndex: newIndex,
                    videos: videos,
                  );
                },
                itemBuilder: (context, index) {
                  if (index >= videos.length) return const SizedBox.shrink();

                  // VideoFeedItem uses list index for active video detection
                  // (URL manages 1-based indexing separately)
                  final video = videos[index];
                  return VideoFeedItem(
                    key: ValueKey('video-${video.stableId}'),
                    video: video,
                    index: index, // Use list index for active video detection
                    hasBottomNavigation:
                        false, // Fullscreen mode, no bottom nav
                    forceShowOverlay:
                        isOwnProfile, // Show overlay controls on own profile
                    contextTitle: ref
                        .read(fetchUserProfileProvider(userIdHex))
                        .value
                        ?.betterDisplayName('Profile'),
                  );
                },
              );
            }

            // Otherwise show Instagram-style grid view
            return Stack(
              children: [
                DefaultTabController(
                  length: 3,
                  child: NestedScrollView(
                    controller: _scrollController,
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      // Profile Header
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: _buildProfileHeader(
                              authService,
                              userIdHex,
                              isOwnProfile,
                              profileStatsAsync,
                            ),
                          ),
                        ),
                      ),

                      // Stats Row
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: ProfileStatsRowWidget(
                              profileStatsAsync: profileStatsAsync,
                            ),
                          ),
                        ),
                      ),

                      // Action Buttons
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: ProfileActionButtons(
                              userIdHex: userIdHex,
                              isOwnProfile: isOwnProfile,
                              onEditProfile: _editProfile,
                              onOpenDrafts: _openDrafts,
                              onShareProfile: () => _shareProfile(userIdHex),
                              onFollowUser: () => _followUser(userIdHex),
                              onUnfollowUser: () => _unfollowUser(userIdHex),
                              onBlockUser: (isBlocked) =>
                                  _blockUser(userIdHex, isBlocked),
                            ),
                          ),
                        ),
                      ),

                      // Sticky Tab Bar
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            controller: _tabController,
                            indicatorColor: Colors.white,
                            indicatorWeight: 2,
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.grey,
                            tabs: const [
                              Tab(icon: Icon(Icons.grid_on, size: 20)),
                              Tab(icon: Icon(Icons.favorite_border, size: 20)),
                              Tab(icon: Icon(Icons.repeat, size: 20)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        ProfileVideosGrid(videos: videos, userIdHex: userIdHex),
                        const ProfileLikedGrid(),
                        ProfileRepostsGrid(userIdHex: userIdHex),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          onLoading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircularProgressIndicator(color: VineTheme.vineGreen),
                SizedBox(height: 24),
                Text(
                  'Loading profile...',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This may take a few moments',
                  style: TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          onError: (error, stack) => Center(child: Text('Error: $error')),
        );
      },
      onLoading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(color: VineTheme.vineGreen),
            SizedBox(height: 24),
            Text(
              'Loading profile...',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
            ),
          ],
        ),
      ),
      onError: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildProfileHeader(
    AuthService authService,
    String userIdHex,
    bool isOwnProfile,
    AsyncValue<ProfileStats> profileStatsAsync,
  ) {
    // Watch profile from relay (reactive)
    final profileAsync = ref.watch(fetchUserProfileProvider(userIdHex));
    final profile = profileAsync.value;

    if (profile == null) {
      return SizedBox.shrink();
    }
    final profilePictureUrl = profile.picture;
    final displayName = profile.bestDisplayName;
    final hasCustomName =
        profile.name?.isNotEmpty == true ||
        profile.displayName?.isNotEmpty == true;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Setup profile banner for new users with default names (only on own profile)
          if (isOwnProfile && !hasCustomName)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete Your Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add your name, bio, and picture to get started',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _setupProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Set Up',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Profile picture and stats row
          Row(
            children: [
              // Profile picture
              UserAvatar(imageUrl: profilePictureUrl, name: null, size: 86),

              const SizedBox(width: 20),

              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ProfileStatColumn(
                      count: profileStatsAsync.hasValue
                          ? profileStatsAsync.value!.videoCount
                          : null,
                      label: 'Videos',
                      isLoading: profileStatsAsync.isLoading,
                      onTap: null, // Videos aren't tappable
                    ),
                    ProfileStatColumn(
                      count: profileStatsAsync.hasValue
                          ? profileStatsAsync.value!.followers
                          : null,
                      label: 'Followers',
                      isLoading: profileStatsAsync.isLoading,
                      onTap: () =>
                          _navigateToFollowers(context, userIdHex, displayName),
                    ),
                    ProfileStatColumn(
                      count: profileStatsAsync.hasValue
                          ? profileStatsAsync.value!.following
                          : null,
                      label: 'Following',
                      isLoading: profileStatsAsync.isLoading,
                      onTap: () =>
                          _navigateToFollowing(context, userIdHex, displayName),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Name and bio
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserName.fromPubKey(
                  userIdHex,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                // Show NIP-05 identifier if present
                if (profile.nip05 != null && profile.nip05!.isNotEmpty)
                  Text(
                    profile.nip05!,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                const SizedBox(height: 4),
                if (profile.about != null && profile.about!.isNotEmpty)
                  SelectableText(
                    profile.about!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                const SizedBox(height: 8),
                // Public key display with copy functionality
                GestureDetector(
                  onTap: () => _copyNpubToClipboard(userIdHex),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[600]!, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: SelectableText(
                            NostrKeyUtils.encodePubKey(userIdHex),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy, color: Colors.grey, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Action methods

  Future<void> _setupProfile() async {
    print(
      '🔍 NAV DEBUG: ProfileScreenRouter._setupProfile() - about to push /setup-profile',
    );
    print('🔍 NAV DEBUG: Current location: ${GoRouterState.of(context).uri}');
    await context.push('/setup-profile');
    print('🔍 NAV DEBUG: Returned from push /setup-profile');
  }

  Future<void> _editProfile() async {
    // Show menu with Edit Profile and Delete Account options
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: VineTheme.cardBackground,
      builder: (context) => SafeArea(
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
              onTap: () => Navigator.pop(context, 'edit'),
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
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (result == 'edit') {
      print(
        '🔍 NAV DEBUG: ProfileScreenRouter._editProfile() - about to push /edit-profile',
      );
      print('🔍 NAV DEBUG: Current location: ${GoRouterState.of(context).uri}');
      await context.push('/edit-profile');
      print('🔍 NAV DEBUG: Returned from push /edit-profile');
    } else if (result == 'delete') {
      _handleDeleteAccount();
    }
  }

  Future<void> _handleDeleteAccount() async {
    final deletionService = ref.read(accountDeletionServiceProvider);
    final authService = ref.read(authServiceProvider);

    // Show double-confirmation warning dialogs (imported from delete_account_dialog.dart)
    await showDeleteAllContentWarningDialog(
      context: context,
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
        Navigator.of(context).pop();

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

  void _openDrafts() {
    context.go('/drafts');
  }

  Future<void> _followUser(String pubkey) async {
    await FollowActionsHelper.followUser(
      ref: ref,
      context: context,
      pubkey: pubkey,
      contextName: 'ProfileScreenRouter',
    );
  }

  Future<void> _unfollowUser(String pubkey) async {
    await FollowActionsHelper.unfollowUser(
      ref: ref,
      context: context,
      pubkey: pubkey,
      contextName: 'ProfileScreenRouter',
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
        title: const Text('Block @', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You won\'t see their content in feeds. They won\'t be notified. You can still visit their profile.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
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

  Future<void> _copyNpubToClipboard(String userIdHex) async {
    try {
      final npub = NostrKeyUtils.encodePubKey(userIdHex);
      await Clipboard.setData(ClipboardData(text: npub));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check, color: Colors.white),
                SizedBox(width: 8),
                Text('Public key copied to clipboard'),
              ],
            ),
            backgroundColor: VineTheme.vineGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Custom delegate for sticky tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: VineTheme.backgroundColor, child: _tabBar);

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
