import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/search_results_filter_l10n.dart';

/// Shows the search-filter selection bottom sheet.
///
/// Uses [VineBottomSheetSelectionMenu] to present filter options and updates
/// the [SearchResultsFilterCubit] when the user picks one.
class SearchFilterSheet {
  static Future<void> show(BuildContext context) async {
    final cubit = context.read<SearchResultsFilterCubit>();
    final l10n = context.l10n;

    final selected = await VineBottomSheetSelectionMenu.show(
      context: context,
      selectedValue: cubit.state.name,
      options: [
        for (final filter in SearchResultsFilter.values)
          VineBottomSheetSelectionOptionData(
            label: filter.categoryLabel(l10n),
            value: filter.name,
          ),
      ],
    );

    if (selected == null) return;

    final filter = SearchResultsFilter.values.byName(selected);
    cubit.filterChanged(filter);
  }
}
