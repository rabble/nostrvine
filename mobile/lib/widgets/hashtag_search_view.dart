// ABOUTME: Widget for displaying hashtag search results as chips
// ABOUTME: Consumes HashtagSearchBloc from parent BlocProvider

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/search_results/widgets/search_tag_chip.dart';
import 'package:openvine/services/screen_analytics_service.dart';

/// Displays hashtag search results from HashtagSearchBloc.
///
/// Must be used within a BlocProvider<HashtagSearchBloc>.
class HashtagSearchView extends StatelessWidget {
  const HashtagSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HashtagSearchBloc, HashtagSearchState>(
      listener: (context, state) {
        if (state.status == HashtagSearchStatus.success) {
          ScreenAnalyticsService().markDataLoaded(
            'search',
            dataMetrics: {'hashtag_count': state.results.length},
          );
        }
      },
      builder: (context, state) {
        return switch (state.status) {
          HashtagSearchStatus.initial => const _HashtagSearchEmptyState(),
          HashtagSearchStatus.loading when state.results.isNotEmpty =>
            _HashtagSearchResultsList(
              results: state.results,
              query: state.query,
              hasMore: state.hasMore,
              isLoadingMore: true,
            ),
          HashtagSearchStatus.loading => const _HashtagSearchLoadingState(),
          HashtagSearchStatus.success => _HashtagSearchResultsList(
            results: state.results,
            query: state.query,
            hasMore: state.hasMore,
            isLoadingMore: state.isLoadingMore,
          ),
          HashtagSearchStatus.failure => const _HashtagSearchErrorState(),
        };
      },
    );
  }
}

class _HashtagSearchEmptyState extends StatelessWidget {
  const _HashtagSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DivineIcon(
            icon: DivineIconName.search,
            color: VineTheme.secondaryText,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text('Search for hashtags', style: VineTheme.titleSmallFont()),
          Text(
            'Discover trending topics and content',
            style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _HashtagSearchLoadingState extends StatelessWidget {
  const _HashtagSearchLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: VineTheme.vineGreen),
    );
  }
}

class _HashtagSearchResultsList extends StatefulWidget {
  const _HashtagSearchResultsList({
    required this.results,
    required this.query,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<String> results;
  final String query;
  final bool hasMore;
  final bool isLoadingMore;

  @override
  State<_HashtagSearchResultsList> createState() =>
      _HashtagSearchResultsListState();
}

class _HashtagSearchResultsListState extends State<_HashtagSearchResultsList>
    with ScrollPaginationMixin {
  final _scrollController = ScrollController();

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() => widget.hasMore && !widget.isLoadingMore;

  @override
  FutureOr<void> onLoadMore() {
    context.read<HashtagSearchBloc>().add(const HashtagSearchLoadMore());
  }

  @override
  void initState() {
    super.initState();
    initPagination();
  }

  @override
  void dispose() {
    disposePagination();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return _HashtagSearchNoResultsState(query: widget.query);
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in widget.results)
                SearchTagChip(
                  tag: tag,
                  onTap: () =>
                      context.push(HashtagScreenRouter.pathForTag(tag)),
                ),
            ],
          ),
          if (widget.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: VineTheme.vineGreen),
              ),
            ),
        ],
      ),
    );
  }
}

class _HashtagSearchNoResultsState extends StatelessWidget {
  const _HashtagSearchNoResultsState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DivineIcon(
            icon: DivineIconName.search,
            color: VineTheme.secondaryText,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No hashtags found for "$query"',
            style: VineTheme.titleSmallFont(),
          ),
        ],
      ),
    );
  }
}

class _HashtagSearchErrorState extends StatelessWidget {
  const _HashtagSearchErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            color: VineTheme.error,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Search failed',
            style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
          ),
        ],
      ),
    );
  }
}
