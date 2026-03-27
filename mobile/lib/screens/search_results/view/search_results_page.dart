import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/search_results/view/search_results_view.dart';
import 'package:openvine/screens/search_results/widgets/search_results_app_bar.dart';
import 'package:openvine/services/top_hashtags_service.dart';

// TODO(oscar): Move fallback logic into HashtagRepository
// https://github.com/divinevideo/divine-mobile/issues/2535
Future<List<String>> _searchLocalHashtags(
  WidgetRef ref,
  String query, {
  int limit = 20,
}) async {
  final normalizedQuery = query.trim().replaceFirst('#', '').toLowerCase();
  if (normalizedQuery.isEmpty) return const [];

  final results = <String>[];
  final seen = <String>{};

  void addResults(Iterable<String> hashtags) {
    for (final hashtag in hashtags) {
      final normalizedTag = hashtag.replaceFirst('#', '').trim();
      final key = normalizedTag.toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      results.add(normalizedTag);
      if (results.length >= limit) return;
    }
  }

  try {
    addResults(
      ref.read(hashtagServiceProvider).searchHashtags(normalizedQuery),
    );
  } catch (_) {
    // Ignore local feed lookup failures and continue with static hashtags.
  }

  if (results.length >= limit) return results;

  try {
    await TopHashtagsService.instance.loadTopHashtags();
    addResults(
      TopHashtagsService.instance.searchHashtags(
        normalizedQuery,
        limit: limit,
      ),
    );
  } catch (_) {
    // Ignore asset lookup failures — remote results have already failed.
  }

  return results;
}

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
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => VideoSearchBloc(
            videosRepository: ref.read(videosRepositoryProvider),
          ),
        ),
        BlocProvider(
          create: (_) => UserSearchBloc(
            profileRepository: ref.read(profileRepositoryProvider)!,
          ),
        ),
        BlocProvider(
          create: (_) => HashtagSearchBloc(
            hashtagRepository: ref.read(hashtagRepositoryProvider),
            // TODO(oscar): Move fallback logic into HashtagRepository
            // https://github.com/divinevideo/divine-mobile/issues/2535
            localHashtagSearch: (query, {limit = 20}) =>
                _searchLocalHashtags(ref, query, limit: limit),
          ),
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            SearchResultsAppBar(initialQuery: initialQuery ?? ''),
            const Expanded(child: SearchResultsView()),
          ],
        ),
      ),
    );
  }
}
