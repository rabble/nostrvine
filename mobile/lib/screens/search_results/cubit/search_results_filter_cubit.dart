import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/screens/search_results/view/search_results_view.dart';

/// Manages the active [SearchResultsFilter] for the search results screen.
class SearchResultsFilterCubit extends Cubit<SearchResultsFilter> {
  SearchResultsFilterCubit() : super(SearchResultsFilter.all);

  /// Sets the filter to the given [filter].
  void setFilter(SearchResultsFilter filter) => emit(filter);
}
