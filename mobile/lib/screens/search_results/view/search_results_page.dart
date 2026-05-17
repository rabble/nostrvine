import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/search_results/view/search_results_view.dart';
import 'package:openvine/screens/search_results/widgets/search_results_app_bar.dart';

/// Page that creates and wires the search BLoCs, then renders
/// [SearchResultsView].
class SearchResultsPage extends ConsumerWidget {
  const SearchResultsPage({
    this.initialQuery,
    this.requestFocusOnMount = false,
    super.key,
  });

  /// Optional pre-filled search query from the route.
  final String? initialQuery;

  /// Whether the search field should claim keyboard focus on first paint.
  final bool requestFocusOnMount;

  /// Base path prefix (used for route matching and normalization skips).
  static const pathPrefix = '/search-results';

  /// Route path pattern for GoRouter.
  static const path = '$pathPrefix/:query';

  /// Query parameter used to opt a prefilled route into mount focus.
  static const requestFocusQueryParameter = 'focus';

  /// Build a path with the given query and explicit mount-focus intent.
  static String pathForQuery(
    String query, {
    required bool requestFocusOnMount,
  }) {
    final encodedQuery = Uri.encodeComponent(query);
    if (!requestFocusOnMount) return '$pathPrefix/$encodedQuery';
    return '$pathPrefix/$encodedQuery?$requestFocusQueryParameter=1';
  }

  /// Returns whether a routed prefilled search should claim keyboard focus.
  static bool requestFocusOnMountForRoute(Uri uri) =>
      uri.queryParameters[requestFocusQueryParameter] == '1';

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
        BlocProvider(create: (_) => SearchResultsFilterCubit()),
        BlocProvider(
          create: (_) => HashtagSearchBloc(
            hashtagRepository: ref.read(hashtagRepositoryProvider),
          ),
        ),
        BlocProvider(
          create: (_) => ListSearchBloc(
            curatedListRepository: ref.read(curatedListRepositoryProvider),
            peopleListsRepository: ref.read(peopleListsRepositoryProvider),
            peopleListSearchEnabled: ref.read(
              isFeatureEnabledProvider(FeatureFlag.profileListFeatures),
            ),
          ),
        ),
      ],
      child: Scaffold(
        // bg/surface — matches SearchResultsView's body background so the
        // app bar area (which doesn't paint its own background) doesn't
        // show through to the root scaffold's darker default.
        backgroundColor: VineTheme.surfaceBackground,
        body: _SearchResultsBody(
          initialQuery: initialQuery ?? '',
          requestFocusOnMount: requestFocusOnMount,
        ),
      ),
    );
  }
}

/// Wires the app bar and body together, owning the search field's
/// [TextEditingController] so both children read the same live value.
///
/// The controller is hoisted here (rather than created inside the app bar)
/// so [SearchResultsView] can drive its idle-placeholder decision from the
/// user's current input. Using the live text — not the route arg —
/// correctly returns the view to the idle placeholder when the user clears
/// or shortens a prefilled query after landing on /search-results/:query.
class _SearchResultsBody extends StatefulWidget {
  const _SearchResultsBody({
    required this.initialQuery,
    required this.requestFocusOnMount,
  });

  final String initialQuery;
  final bool requestFocusOnMount;

  @override
  State<_SearchResultsBody> createState() => _SearchResultsBodyState();
}

class _SearchResultsBodyState extends State<_SearchResultsBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchResultsAppBar(
          controller: _controller,
          initialQuery: widget.initialQuery,
          requestFocusOnMount: widget.requestFocusOnMount,
        ),
        Expanded(child: SearchResultsView(controller: _controller)),
      ],
    );
  }
}
