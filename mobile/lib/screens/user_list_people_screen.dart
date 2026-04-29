// ABOUTME: Screen for displaying people from a NIP-51 kind 30000 user list with their videos
// ABOUTME: Shows horizontal carousel of people at top, video grid below

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/scroll_to_hide_mixin.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:unified_logger/unified_logger.dart';

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
          ? DiVineAppBar(
              title: widget.userList.name,
              subtitle: widget.userList.description,
              showBackButton: true,
              onBackPressed: context.pop,
            )
          : null,
      body: widget.userList.pubkeys.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group, size: 64, color: VineTheme.secondaryText),
                  SizedBox(height: 16),
                  Text(
                    'No people in this list',
                    style: TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library,
                  size: 64,
                  color: VineTheme.secondaryText,
                ),
                SizedBox(height: 16),
                Text(
                  'No videos yet',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
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
                  emptyBuilder: () => const Center(
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
      loading: () => const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: VineTheme.likeRed),
            const SizedBox(height: 16),
            const Text(
              'Failed to load videos',
              style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 12,
              ),
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
          return const Center(
            child: Text(
              'Video not available',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          );
        }

        return Stack(
          children: [
            PooledFullscreenVideoFeedScreen(
              videosStream: Stream.value(videos),
              initialIndex: _activeVideoIndex!,
              removedIdsStream: ref
                  .read(videoEventServiceProvider)
                  .removedVideoIds,
              contextTitle: widget.userList.name,
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [VineTheme.scrim70, VineTheme.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back to grid button
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: VineTheme.scrim50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.grid_view,
                            color: VineTheme.whiteText,
                            size: 20,
                          ),
                        ),
                        onPressed: () {
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
                                style: const TextStyle(
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
                          color: VineTheme.scrim50,
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
      loading: () => const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
      error: (error, stack) => const Center(
        child: Text(
          'Error loading videos',
          style: TextStyle(color: VineTheme.likeRed),
        ),
      ),
    );
  }
}

/// Horizontal carousel of people avatars for a user list.
class _PeopleCarousel extends StatelessWidget {
  const _PeopleCarousel({required this.pubkeys, super.key});

  final List<String> pubkeys;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.only(
            start: 16,
            end: 16,
            top: 12,
          ),
          itemCount: pubkeys.length,
          itemBuilder: (context, index) =>
              _PeopleAvatarItem(pubkey: pubkeys[index]),
        ),
      ),
    );
  }
}

class _PeopleAvatarItem extends ConsumerWidget {
  const _PeopleAvatarItem({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
    final displayName =
        profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey);

    return Semantics(
      label: 'View profile for $displayName',
      button: true,
      child: GestureDetector(
        onTap: () {
          final npub = NostrKeyUtils.encodePubKey(pubkey);
          context.push(OtherProfileScreen.pathForNpub(npub));
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              UserAvatar(
                imageUrl: profile?.picture,
                placeholderSeed: pubkey,
                size: 56,
              ),
              SizedBox(
                width: 70,
                child: Text(
                  displayName,
                  style: VineTheme.titleTinyFont(),
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
  }
}
