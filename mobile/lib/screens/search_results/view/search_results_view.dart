import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/screens/search_results/widgets/widgets.dart';

class SearchResultsView extends StatelessWidget {
  /// Use [SearchResultsPage] to ensure BLoC providers are wired.
  const SearchResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    final filter = context.select(
      (SearchResultsFilterCubit cubit) => cubit.state,
    );

    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: CustomScrollView(
        // Reset scroll position when filter changes.
        key: ValueKey(filter),
        slivers: switch (filter) {
          SearchResultsFilter.all => [
            PeopleSection(
              onSeeAll: () => context
                  .read<SearchResultsFilterCubit>()
                  .filterChanged(SearchResultsFilter.people),
            ),
            TagsSection(
              onSeeAll: () => context
                  .read<SearchResultsFilterCubit>()
                  .filterChanged(SearchResultsFilter.tags),
            ),
            VideosSection(
              onSeeAll: () => context
                  .read<SearchResultsFilterCubit>()
                  .filterChanged(SearchResultsFilter.videos),
            ),
          ],
          SearchResultsFilter.people => const [PeopleSection(showAll: true)],
          SearchResultsFilter.tags => const [TagsSection(showAll: true)],
          SearchResultsFilter.videos => const [VideosSection(showAll: true)],
        },
      ),
    );
  }
}
