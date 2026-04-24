import 'package:flutter_bloc/flutter_bloc.dart';

/// Filter options for search results.
///
/// Each value corresponds to a content category shown in the search results
/// screen. [all] shows preview sections for every category; the rest show
/// a single category in full.
///
/// Localized labels: `SearchResultsFilterL10n.categoryLabel` in
/// `lib/l10n/search_results_filter_l10n.dart`.
enum SearchResultsFilter {
  all,
  people,
  lists,
  tags,
  videos,
}

/// Cubit that holds the active [SearchResultsFilter].
///
/// Provided at the [SearchResultsPage] level so all child widgets can read
/// and react to filter changes.
class SearchResultsFilterCubit extends Cubit<SearchResultsFilter> {
  SearchResultsFilterCubit({
    SearchResultsFilter initial = SearchResultsFilter.all,
  }) : super(initial);

  /// Update the active filter.
  void filterChanged(SearchResultsFilter filter) => emit(filter);
}
