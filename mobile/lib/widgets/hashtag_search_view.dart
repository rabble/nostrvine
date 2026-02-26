// ABOUTME: Widget for displaying hashtag search results
// ABOUTME: Consumes HashtagSearchBloc from parent BlocProvider

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/unified_logger.dart';

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
          HashtagSearchStatus.loading => const _HashtagSearchLoadingState(),
          HashtagSearchStatus.success => _HashtagSearchResultsList(
            results: state.results,
            query: state.query,
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.tag, size: 64, color: VineTheme.secondaryText),
          SizedBox(height: 16),
          Text(
            'Search for hashtags',
            style: TextStyle(color: VineTheme.primaryText, fontSize: 18),
          ),
          Text(
            'Discover trending topics and content',
            style: TextStyle(color: VineTheme.secondaryText),
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

class _HashtagSearchResultsList extends StatelessWidget {
  const _HashtagSearchResultsList({required this.results, required this.query});

  final List<String> results;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return _HashtagSearchNoResultsState(query: query);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final hashtag = results[index];
        return _HashtagResultTile(hashtag: hashtag);
      },
    );
  }
}

class _HashtagResultTile extends StatelessWidget {
  const _HashtagResultTile({required this.hashtag});

  final String hashtag;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VineTheme.cardBackground,
      child: ListTile(
        leading: const Icon(Icons.tag, color: VineTheme.vineGreen),
        title: Text(
          '#$hashtag',
          style: const TextStyle(
            color: VineTheme.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text(
          'Tap to view videos with this hashtag',
          style: TextStyle(color: VineTheme.secondaryText),
        ),
        onTap: () {
          Log.info(
            'HashtagSearchView: Tapped hashtag: $hashtag',
            category: LogCategory.video,
          );
          context.go(HashtagScreenRouter.pathForTag(hashtag));
        },
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
          const Icon(
            Icons.tag_outlined,
            size: 64,
            color: VineTheme.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            'No hashtags found for "$query"',
            style: const TextStyle(color: VineTheme.primaryText, fontSize: 18),
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
