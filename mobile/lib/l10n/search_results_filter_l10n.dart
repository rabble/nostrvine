import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

/// Localized titles for [SearchResultsFilter] (pill, bottom sheet, section headers).
extension SearchResultsFilterL10n on SearchResultsFilter {
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
