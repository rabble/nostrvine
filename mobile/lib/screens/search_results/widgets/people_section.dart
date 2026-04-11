import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/search_user_tile.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Maximum number of user profiles shown in the People preview.
const _maxPeoplePreview = 3;

/// Always-visible People section with a "People" header.
///
/// Returns a [SliverMainAxisGroup] so the header and content participate
/// natively in the parent [CustomScrollView]'s sliver protocol.
class PeopleSection extends StatelessWidget {
  const PeopleSection({this.showAll = false, this.onSeeAll, super.key});

  /// When true, shows all results instead of a limited preview.
  final bool showAll;

  /// Called when the user taps the "See all" chevron.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (UserSearchBloc bloc) => bloc.state.status,
    );
    final results = context.select(
      (UserSearchBloc bloc) => bloc.state.results,
    );

    // In the All tab, hide entire section when results are empty and loaded.
    if (!showAll && status == .success && results.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        if (!showAll)
          SliverToBoxAdapter(
            child: SectionHeader(title: 'People', onTap: onSeeAll),
          ),
        _PeopleContent(showAll: showAll),
        if (showAll) const _PeoplePaginationTrigger(),
      ],
    );
  }
}

class _PeoplePaginationTrigger extends StatelessWidget {
  const _PeoplePaginationTrigger();

  @override
  Widget build(BuildContext context) {
    final hasMore = context.select(
      (UserSearchBloc b) => b.state.hasMore,
    );
    final isLoadingMore = context.select(
      (UserSearchBloc b) => b.state.isLoadingMore,
    );
    return SliverPaginationTrigger(
      onLoadMore: () => context.read<UserSearchBloc>().add(
        const UserSearchLoadMore(),
      ),
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
    );
  }
}

class _PeopleContent extends StatelessWidget {
  const _PeopleContent({this.showAll = false});

  final bool showAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (UserSearchBloc bloc) => bloc.state.status,
    );
    final results = context.select(
      (UserSearchBloc bloc) => bloc.state.results,
    );
    final query = context.select(
      (UserSearchBloc bloc) => bloc.state.query,
    );

    if ((status == .initial || status == .loading) && results.isEmpty) {
      return const _PeopleSkeletonLoader();
    }

    if (status == .failure) {
      return SearchSectionErrorState(
        onRetry: () => context.read<UserSearchBloc>().add(
          UserSearchQueryChanged(query),
        ),
      );
    }

    if (results.isEmpty) {
      if (showAll) return SearchSectionEmptyState(query: query);
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final profiles = showAll
        ? results
        : results.take(_maxPeoplePreview).toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final profile in profiles)
              SearchUserTile(
                profile: profile,
                onTap: () => _navigateToProfile(context, profile),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context, UserProfile profile) {
    final npub = normalizeToNpub(profile.pubkey);
    if (npub != null) {
      context.push(OtherProfileScreen.pathForNpub(npub));
    }
  }
}

class _PeopleSkeletonLoader extends StatelessWidget {
  const _PeopleSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Semantics(
        identifier: 'people_loading_indicator',
        label: 'Loading people results',
        child: Skeletonizer(
          effect: vineSkeletonEffect,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                _maxPeoplePreview,
                (_) => const _UserTileSkeletonItem(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTileSkeletonItem extends StatelessWidget {
  const _UserTileSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        spacing: 16,
        children: [
          Skeleton.leaf(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: VineTheme.skeletonSurface,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Skeleton.leaf(
                  child: Container(
                    width: 140,
                    height: 18,
                    decoration: BoxDecoration(
                      color: VineTheme.skeletonSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Skeleton.leaf(
                  child: Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: VineTheme.skeletonSurface,
                      borderRadius: BorderRadius.circular(8),
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
}
