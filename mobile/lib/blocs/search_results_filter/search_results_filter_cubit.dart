import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

/// Filter options for search results.
///
/// Each value corresponds to a content category shown in the search results
/// screen. [all] shows preview sections for every category; the rest show
/// a single category in full.
enum SearchResultsFilter {
  all,
  people,
  lists,
  tags,
  videos
  ;

  /// Localized title for the filter pill, bottom sheet, and section headers.
  String categoryLabel(AppLocalizations l10n) {
    return switch (this) {
      SearchResultsFilter.all => l10n.searchResultsCategoryAll,
      SearchResultsFilter.people => l10n.searchResultsCategoryPeople,
      SearchResultsFilter.lists => l10n.searchResultsCategoryLists,
      SearchResultsFilter.tags => l10n.searchResultsCategoryTags,
      SearchResultsFilter.videos => l10n.searchResultsCategoryVideos,
    };
  }
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
