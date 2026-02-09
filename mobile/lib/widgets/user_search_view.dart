// ABOUTME: Widget for displaying user search results
// ABOUTME: Consumes UserSearchBloc from parent BlocProvider

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Displays user search results from UserSearchBloc.
///
/// Must be used within a BlocProvider<UserSearchBloc>.
class UserSearchView extends StatelessWidget {
  const UserSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserSearchBloc, UserSearchState>(
      builder: (context, state) {
        return switch (state.status) {
          UserSearchStatus.initial => const _UserSearchEmptyState(),
          UserSearchStatus.loading => const _UserSearchLoadingState(),
          UserSearchStatus.success => _UserSearchResultsList(
            results: state.results,
            hasMore: state.hasMore,
            isLoadingMore: state.isLoadingMore,
          ),
          UserSearchStatus.failure => const _UserSearchErrorState(),
        };
      },
    );
  }
}

class _UserSearchEmptyState extends StatelessWidget {
  const _UserSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 64, color: VineTheme.secondaryText),
          SizedBox(height: 16),
          Text(
            'Search for users',
            style: TextStyle(color: VineTheme.lightText),
          ),
        ],
      ),
    );
  }
}

class _UserSearchLoadingState extends StatelessWidget {
  const _UserSearchLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: VineTheme.vineGreen),
    );
  }
}

class _UserSearchResultsList extends StatefulWidget {
  const _UserSearchResultsList({
    required this.results,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<UserProfile> results;
  final bool hasMore;
  final bool isLoadingMore;

  @override
  State<_UserSearchResultsList> createState() => _UserSearchResultsListState();
}

class _UserSearchResultsListState extends State<_UserSearchResultsList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // Trigger load more at 80% scroll
    if (currentScroll >= maxScroll * 0.8 &&
        widget.hasMore &&
        !widget.isLoadingMore) {
      context.read<UserSearchBloc>().add(const UserSearchLoadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return const _UserSearchNoResultsState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: widget.results.length + (widget.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.results.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
          );
        }

        final profile = widget.results[index];
        return _SearchUserTile(
          profile: profile,
          onTap: () {
            final npub = normalizeToNpub(profile.pubkey);
            if (npub != null) {
              context.push(OtherProfileScreen.pathForNpub(npub));
            }
          },
        );
      },
    );
  }
}

/// Tile widget for displaying a user from search results.
/// Uses UserProfile from package:models directly.
class _SearchUserTile extends StatelessWidget {
  const _SearchUserTile({required this.profile, this.onTap});

  final UserProfile profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final followerCount = profile.rawData['follower_count'] as int?;
    final videoCount = profile.rawData['video_count'] as int?;

    return Semantics(
      identifier: 'search_user_tile_${profile.pubkey}',
      label: profile.bestDisplayName,
      container: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              UserAvatar(imageUrl: profile.picture, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.bestDisplayName,
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (followerCount != null || videoCount != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _ProfileStats(
                          followerCount: followerCount,
                          videoCount: videoCount,
                        ),
                      ),
                    if (profile.about != null && profile.about!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          profile.about!,
                          style: const TextStyle(
                            color: VineTheme.secondaryText,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats({this.followerCount, this.videoCount});

  final int? followerCount;
  final int? videoCount;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (followerCount != null) {
      parts.add('${StringUtils.formatCompactNumber(followerCount!)} followers');
    }
    if (videoCount != null) {
      parts.add('${StringUtils.formatCompactNumber(videoCount!)} videos');
    }
    return Text(
      parts.join(' \u00B7 '),
      style: const TextStyle(color: VineTheme.lightText, fontSize: 13),
    );
  }
}

class _UserSearchNoResultsState extends StatelessWidget {
  const _UserSearchNoResultsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: VineTheme.secondaryText),
          SizedBox(height: 16),
          Text('No users found', style: TextStyle(color: VineTheme.lightText)),
        ],
      ),
    );
  }
}

class _UserSearchErrorState extends StatelessWidget {
  const _UserSearchErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          const Text(
            'Search failed',
            style: TextStyle(color: VineTheme.lightText),
          ),
        ],
      ),
    );
  }
}
