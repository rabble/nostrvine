// ABOUTME: Widget for displaying user search results
// ABOUTME: Consumes UserSearchBloc from parent BlocProvider

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/search_results/widgets/search_user_tile.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';

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
          // Show intermediate results as they arrive; only show spinner
          // when no results are available yet.
          UserSearchStatus.loading when state.results.isNotEmpty =>
            _UserSearchResultsList(
              results: state.results,
              hasMore: state.hasMore,
              isLoadingMore: true,
            ),
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
        return SearchUserTile(
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: VineTheme.error),
          SizedBox(height: 16),
          Text('Search failed', style: TextStyle(color: VineTheme.lightText)),
        ],
      ),
    );
  }
}
