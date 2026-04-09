// ABOUTME: Lists section for search results, used in both "All" preview
// ABOUTME: and the dedicated "Lists" tab (showAll: true).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/widgets/list_search_card.dart';

/// Always-visible Lists section with a "Lists" header.
///
/// When [showAll] is true, displays all results in a grid and hides the
/// section header — matching the pattern used by [VideosSection],
/// [PeopleSection], and [TagsSection].
class ListsSection extends StatelessWidget {
  const ListsSection({this.showAll = false, this.onSeeAll, super.key});

  /// When true, shows all results and hides the section header.
  final bool showAll;

  /// Called when the user taps the "See all" chevron.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (ListSearchBloc bloc) => bloc.state.status,
    );
    final results = context.select(
      (ListSearchBloc bloc) => bloc.state.results,
    );

    // In the All tab, hide entire section when results are empty and loaded.
    if (!showAll && status == .success && results.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        if (!showAll)
          SliverToBoxAdapter(
            child: SectionHeader(title: 'Lists', onTap: onSeeAll),
          ),
        _ListsContent(showAll: showAll),
      ],
    );
  }
}

class _ListsContent extends StatelessWidget {
  const _ListsContent({required this.showAll});

  final bool showAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select((ListSearchBloc bloc) => bloc.state.status);
    final results = context.select((ListSearchBloc bloc) => bloc.state.results);
    final query = context.select((ListSearchBloc bloc) => bloc.state.query);

    if (status == .initial && showAll) {
      return const _InitialState();
    }

    if ((status == .initial || status == .loading) && results.isEmpty) {
      return const _LoadingState();
    }

    if (status == .failure) {
      return SearchSectionErrorState(
        onRetry: () => context.read<ListSearchBloc>().add(
          ListSearchQueryChanged(query),
        ),
      );
    }

    if (results.isEmpty) {
      if (showAll && status == .success) {
        return SearchSectionEmptyState(query: query);
      }
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final displayCount = showAll ? results.length : results.take(2).length;

    return _ResultsGrid(
      results: results,
      displayCount: displayCount,
      showAll: showAll,
    );
  }
}

// TODO(#2853): Display both video and people list cards in the grid.
class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid({
    required this.results,
    required this.displayCount,
    required this.showAll,
  });

  final List<CuratedList> results;
  final int displayCount;
  final bool showAll;

  @override
  Widget build(BuildContext context) {
    if (showAll) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final list = results[index];
            return CuratedListSearchCard(
              curatedList: list,
              onTap: () => _navigateToCuratedList(context, list),
            );
          }, childCount: displayCount),
        ),
      );
    }

    final displayResults = results.take(displayCount).toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          spacing: 12,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final list in displayResults)
              Expanded(
                child: CuratedListSearchCard(
                  curatedList: list,
                  onTap: () => _navigateToCuratedList(context, list),
                ),
              ),
            if (displayResults.length == 1) const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }
}

class _InitialState extends StatelessWidget {
  const _InitialState();

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DivineIcon(
              icon: DivineIconName.search,
              color: VineTheme.secondaryText,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text('Search for lists', style: VineTheme.titleSmallFont()),
            Text(
              'Find curated video lists',
              style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

// TODO(#2855): Replace spinner with skeleton/shimmer loading state.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      ),
    );
  }
}

void _navigateToCuratedList(BuildContext context, CuratedList list) {
  context.push(
    CuratedListFeedScreen.pathForId(list.id),
    extra: CuratedListRouteExtra(
      listName: list.name,
      videoIds: list.videoEventIds,
      authorPubkey: list.pubkey,
    ),
  );
}
