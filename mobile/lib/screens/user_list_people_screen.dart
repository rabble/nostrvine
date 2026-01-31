// ABOUTME: Screen for displaying people from a NIP-51 kind 30000 user list with their videos
// ABOUTME: Shows horizontal carousel of people at top, video grid below

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/services/user_list_service.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/scroll_to_hide_mixin.dart';

class UserListPeopleScreen extends ConsumerStatefulWidget {
  const UserListPeopleScreen({required this.userList, super.key});

  final UserList userList;

  @override
  ConsumerState<UserListPeopleScreen> createState() =>
      _UserListPeopleScreenState();
}

class _UserListPeopleScreenState extends ConsumerState<UserListPeopleScreen>
    with ScrollToHideMixin {
  int? _activeVideoIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: _activeVideoIndex == null
          ? AppBar(
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
                tooltip: 'Back',
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.userList.name, style: VineTheme.titleFont()),
                  if (widget.userList.description != null)
                    Text(
                      widget.userList.description!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            )
          : null,
      body: widget.userList.pubkeys.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group, size: 64, color: VineTheme.secondaryText),
                  const SizedBox(height: 16),
                  Text(
                    'No people in this list',
                    style: TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add some people to get started',
                    style: TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _activeVideoIndex != null
          ? _buildVideoPlayer()
          : _buildListContent(),
    );
  }

  Widget _buildListContent() {
    final videosAsync = ref.watch(
      userListMemberVideosProvider(widget.userList.pubkeys),
    );

    measureHeaderHeight();

    return videosAsync.when(
      data: (videos) {
        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library,
                  size: 64,
                  color: VineTheme.secondaryText,
                ),
                const SizedBox(height: 16),
                Text(
                  'No videos yet',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Videos from list members will appear here',
                  style: TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: handleScrollNotification,
                child: ComposableVideoGrid(
                  videos: videos,
                  useMasonryLayout: true,
                  padding: EdgeInsets.only(
                    left: 4,
                    right: 4,
                    bottom: 4,
                    top: headerHeight > 0 ? headerHeight + 4 : 4,
                  ),
                  onVideoTap: (videos, index) {
                    Log.info(
                      'Tapped video in user list: ${videos[index].id}',
                      category: LogCategory.ui,
                    );
                    setState(() {
                      _activeVideoIndex = index;
                    });
                  },
                  onRefresh: () async {
                    ref.invalidate(
                      userListMemberVideosProvider(widget.userList.pubkeys),
                    );
                  },
                  emptyBuilder: () => Center(
                    child: Text(
                      'No videos available',
                      style: TextStyle(color: VineTheme.secondaryText),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: headerFullyHidden
                  ? const Duration(milliseconds: 250)
                  : Duration.zero,
              curve: Curves.easeOut,
              top: headerOffset,
              left: 0,
              right: 0,
              child: _PeopleCarousel(
                key: headerKey,
                pubkeys: widget.userList.pubkeys,
              ),
            ),
          ],
        );
      },
      loading: () =>
          Center(child: CircularProgressIndicator(color: VineTheme.vineGreen)),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: VineTheme.likeRed),
            const SizedBox(height: 16),
            Text(
              'Failed to load videos',
              style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final videosAsync = ref.watch(
      userListMemberVideosProvider(widget.userList.pubkeys),
    );

    return videosAsync.when(
      data: (videos) {
        if (videos.isEmpty || _activeVideoIndex! >= videos.length) {
          return Center(
            child: Text(
              'Video not available',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          );
        }

        return Stack(
          children: [
            ExploreVideoScreenPure(
              startingVideo: videos[_activeVideoIndex!],
              videoList: videos,
              contextTitle: widget.userList.name,
              startingIndex: _activeVideoIndex!,
              useLocalActiveState:
                  true, // Use local state since not using URL routing
            ),
            // Header bar showing list name and back button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back to grid button
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.grid_view,
                            color: VineTheme.whiteText,
                            size: 20,
                          ),
                        ),
                        onPressed: () {
                          // Stop all videos before switching to grid
                          disposeAllVideoControllers(ref);
                          setState(() {
                            _activeVideoIndex = null;
                          });
                        },
                        tooltip: 'Back to grid',
                      ),
                      const SizedBox(width: 8),
                      // List name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.userList.name,
                              style: const TextStyle(
                                color: VineTheme.whiteText,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.userList.description != null)
                              Text(
                                widget.userList.description!,
                                style: TextStyle(
                                  color: VineTheme.secondaryText,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      // Video count indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_activeVideoIndex! + 1}/${videos.length}',
                          style: const TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () =>
          Center(child: CircularProgressIndicator(color: VineTheme.vineGreen)),
      error: (error, stack) => Center(
        child: Text(
          'Error loading videos',
          style: TextStyle(color: VineTheme.likeRed),
        ),
      ),
    );
  }
}

/// Horizontal carousel of people avatars for a user list.
class _PeopleCarousel extends ConsumerWidget {
  const _PeopleCarousel({super.key, required this.pubkeys});

  final List<String> pubkeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileService = ref.watch(userProfileServiceProvider);

    return Container(
      color: VineTheme.backgroundColor,
      child: SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
          itemCount: pubkeys.length,
          itemBuilder: (context, index) {
            final pubkey = pubkeys[index];

            return FutureBuilder(
              future: userProfileService.fetchProfile(pubkey),
              builder: (context, snapshot) {
                final profile = userProfileService.getCachedProfile(pubkey);

                final displayName =
                    profile?.bestDisplayName ??
                    NostrKeyUtils.truncateNpub(pubkey);

                return Semantics(
                  label: 'View profile for $displayName',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      final npub = normalizeToNpub(pubkey);
                      if (npub != null) {
                        context.push(ProfileScreenRouter.pathForIndex(npub, 0));
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          UserAvatar(imageUrl: profile?.picture, size: 56),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 70,
                            child: Text(
                              displayName,
                              style: VineTheme.titleTinyFont(
                                color: VineTheme.primaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
