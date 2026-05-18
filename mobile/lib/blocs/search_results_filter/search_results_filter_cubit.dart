import 'package:flutter_bloc/flutter_bloc.dart';

/// Filter options for search results.
///
/// Each value corresponds to a content category shown in the search results
/// screen. [all] shows preview sections for every category; the rest show
/// a single category in full.
enum SearchResultsFilter {
  all('All'),
  people('People'),

  lists('Lists'),
  tags('Tags'),
  videos('Videos')
  ;

  const SearchResultsFilter(this.label);

  /// Human-readable display label used in the filter pill and bottom sheet.
  final String label;
}

/// Cubit that holds the active [SearchResultsFilter].
///
/// Provided at the [SearchResultsPage] level so all child widgets can read
/// and react to filter changes.
class SearchResultsFilterCubit extends Cubit<SearchResultsFilter> {
  SearchResultsFilterCubit() : super(SearchResultsFilter.all);

  /// Update the active filter.
  void filterChanged(SearchResultsFilter filter) => emit(filter);
}
