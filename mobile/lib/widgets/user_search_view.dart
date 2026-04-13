// ABOUTME: Widget for displaying user search results
// ABOUTME: Consumes UserSearchBloc from parent BlocProvider

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_search,
            size: 64,
            color: VineTheme.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.userSearchPrompt,
            style: const TextStyle(color: VineTheme.lightText),
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

class _UserSearchResultsListState extends State<_UserSearchResultsList>
    with ScrollPaginationMixin {
  final _scrollController = ScrollController();

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() => widget.hasMore && !widget.isLoadingMore;

  @override
  FutureOr<void> onLoadMore() {
    context.read<UserSearchBloc>().add(const UserSearchLoadMore());
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_off,
            size: 64,
            color: VineTheme.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.userSearchNoResults,
            style: const TextStyle(color: VineTheme.lightText),
          ),
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
          const Icon(
            Icons.error_outline,
            size: 64,
            color: VineTheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.userSearchFailed,
            style: const TextStyle(color: VineTheme.lightText),
          ),
        ],
      ),
    );
  }
}
