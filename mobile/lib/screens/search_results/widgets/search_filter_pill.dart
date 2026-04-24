import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/search_results_filter_l10n.dart';
import 'package:openvine/screens/search_results/widgets/search_filter_sheet.dart';

/// Green pill button that shows the active search filter label.
///
/// Tapping it opens [SearchFilterSheet] so the user can pick a different
/// category.
class SearchFilterPill extends StatelessWidget {
  const SearchFilterPill({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filter = context.select(
      (SearchResultsFilterCubit cubit) => cubit.state,
    );
    final label = filter.categoryLabel(l10n);

    return Semantics(
      label: l10n.searchResultsFilterSemantic(label),
      button: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: GestureDetector(
          onTap: () => SearchFilterSheet.show(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: VineTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: VineTheme.titleSmallFont(color: VineTheme.vineGreen),
            ),
          ),
        ),
      ),
    );
  }
}
