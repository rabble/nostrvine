import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/search_results/widgets/widgets.dart';

class SearchResultsView extends StatelessWidget {
  /// Use [SearchResultsPage] to ensure BLoC providers are wired.
  const SearchResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    // All search BLoCs are driven from the same [SearchResultsAppBar] query
    // dispatcher, so any one of them reflects whether the user has entered a
    // searchable query yet. Reading [VideoSearchBloc] is enough to short
    // circuit every filter into the shared idle placeholder.
    final isIdle = context.select(
      (VideoSearchBloc bloc) => bloc.state.status == VideoSearchStatus.initial,
    );

    if (isIdle) {
      return ColoredBox(
        color: VineTheme.backgroundColor,
        child: CustomScrollView(
          slivers: [
            SearchSectionInitialState(
              title: context.l10n.searchEnterQuery,
              subtitle: context.l10n.searchDiscoverSomethingInteresting,
            ),
            const SliverBottomSafeArea(),
          ],
        ),
      );
    }

    final filter = context.select(
      (SearchResultsFilterCubit cubit) => cubit.state,
    );

    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: switch (filter) {
        SearchResultsFilter.all => CustomScrollView(
          // Reset scroll position when filter changes.
          key: ValueKey(filter),
          slivers: [
            PeopleSection(
              onSeeAll: () => context
                  .read<SearchResultsFilterCubit>()
                  .filterChanged(.people),
            ),
            ListsSection(
              onSeeAll: () => context
                  .read<SearchResultsFilterCubit>()
                  .filterChanged(.lists),
            ),
            TagsSection(
              onSeeAll: () =>
                  context.read<SearchResultsFilterCubit>().filterChanged(.tags),
            ),
            VideosSection(
              onSeeAll: () => context
                  .read<SearchResultsFilterCubit>()
                  .filterChanged(.videos),
            ),
            const SliverBottomSafeArea(),
          ],
        ),
        SearchResultsFilter.people => const CustomScrollView(
          slivers: [PeopleSection(showAll: true), SliverBottomSafeArea()],
        ),
        SearchResultsFilter.tags => const CustomScrollView(
          slivers: [TagsSection(showAll: true), SliverBottomSafeArea()],
        ),
        SearchResultsFilter.lists => const CustomScrollView(
          slivers: [ListsSection(showAll: true), SliverBottomSafeArea()],
        ),
        SearchResultsFilter.videos => const CustomScrollView(
          slivers: [VideosSection(showAll: true), SliverBottomSafeArea()],
        ),
      },
    );
  }
}
