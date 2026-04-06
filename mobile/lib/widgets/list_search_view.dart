// ABOUTME: Full dedicated view for the "Lists" search filter tab.
// ABOUTME: Displays curated list search results from ListSearchBloc.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/widgets/list_card.dart';

/// Displays curated list search results from [ListSearchBloc].
///
/// Must be used within a `BlocProvider<ListSearchBloc>`.
class ListSearchView extends StatelessWidget {
  const ListSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ListSearchBloc, ListSearchState>(
      builder: (context, state) {
        return switch (state.status) {
          ListSearchStatus.initial => const _EmptyState(),
          ListSearchStatus.loading when state.results.isNotEmpty =>
            _ResultsList(state: state),
          ListSearchStatus.loading => const _LoadingState(),
          ListSearchStatus.success => _ResultsList(state: state),
          ListSearchStatus.failure => const _ErrorState(),
        };
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
          Text('Search for lists', style: VineTheme.titleSmallFont()),
          Text(
            'Find curated video lists',
            style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: VineTheme.vineGreen),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.state});

  final ListSearchState state;

  @override
  Widget build(BuildContext context) {
    if (state.results.isEmpty) {
      return _NoResultsState(query: state.query);
    }

    return ListView.builder(
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final list = state.results[index];
        return CuratedListCard(
          curatedList: list,
          onTap: () => _navigateToCuratedList(context, list),
        );
      },
    );
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
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.query});

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
            'No lists found for "$query"',
            style: VineTheme.titleSmallFont(),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

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
