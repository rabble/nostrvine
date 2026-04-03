import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/search_results/view/search_results_view.dart';
import 'package:openvine/screens/search_results/widgets/search_results_app_bar.dart';

/// Page that creates and wires the search BLoCs, then renders
/// [SearchResultsView].
class SearchResultsPage extends ConsumerWidget {
  const SearchResultsPage({this.initialQuery, super.key});

  /// Optional pre-filled search query from the route.
  final String? initialQuery;

  /// Base path prefix (used for route matching and normalization skips).
  static const pathPrefix = '/search-results';

  /// Route path pattern for GoRouter.
  static const path = '$pathPrefix/:query';

  /// Build a path with the given query.
  static String pathForQuery(String query) =>
      '$pathPrefix/${Uri.encodeComponent(query)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepository = ref.read(profileRepositoryProvider);
    if (profileRepository == null) return const SizedBox.shrink();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => VideoSearchBloc(
            videosRepository: ref.read(videosRepositoryProvider),
          ),
        ),
        BlocProvider(
          create: (_) => UserSearchBloc(profileRepository: profileRepository),
        ),
        BlocProvider(
          create: (_) => HashtagSearchBloc(
            hashtagRepository: ref.read(hashtagRepositoryProvider),
          ),
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _SearchResultsBody(initialQuery: initialQuery ?? ''),
      ),
    );
  }
}

/// Owns the [SearchResultsFilter] state shared between the app bar and body.
class _SearchResultsBody extends StatefulWidget {
  const _SearchResultsBody({required this.initialQuery});

  final String initialQuery;

  @override
  State<_SearchResultsBody> createState() => _SearchResultsBodyState();
}

class _SearchResultsBodyState extends State<_SearchResultsBody> {
  SearchResultsFilter _filter = SearchResultsFilter.all;

  void _onFilterChanged(SearchResultsFilter filter) {
    setState(() => _filter = filter);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchResultsAppBar(
          initialQuery: widget.initialQuery,
          filterLabel: _filter.label,
          onFilterTap: _filter == SearchResultsFilter.all
              ? null
              : () => _onFilterChanged(SearchResultsFilter.all),
        ),
        Expanded(
          child: SearchResultsView(
            filter: _filter,
            onFilterChanged: _onFilterChanged,
          ),
        ),
      ],
    );
  }
}
