import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/screens/search_results/widgets/widgets.dart';
import 'package:openvine/widgets/user_search_view.dart';

/// Filter for the search results content.
enum SearchResultsFilter {
  /// Show all sections (People, Tags, Videos).
  all('All'),

  /// Show only the full paginated people list.
  people('People')
  ;

  const SearchResultsFilter(this.label);

  /// Display label for the filter chip.
  final String label;
}

class SearchResultsView extends StatelessWidget {
  /// Use [SearchResultsPage] to ensure BLoC providers are wired.
  const SearchResultsView({
    required this.filter,
    required this.onFilterChanged,
    super.key,
  });

  /// The currently active filter.
  final SearchResultsFilter filter;

  /// Called when the user changes the filter.
  final ValueChanged<SearchResultsFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: switch (filter) {
        SearchResultsFilter.all => _AllSectionsView(
          onSeeAllPeople: () => onFilterChanged(SearchResultsFilter.people),
        ),
        SearchResultsFilter.people => const UserSearchView(),
      },
    );
  }
}

class _AllSectionsView extends StatelessWidget {
  const _AllSectionsView({required this.onSeeAllPeople});

  final VoidCallback onSeeAllPeople;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        PeopleSection(onSeeAll: onSeeAllPeople),
        const TagsSection(),
        const VideosSection(),
      ],
    );
  }
}
