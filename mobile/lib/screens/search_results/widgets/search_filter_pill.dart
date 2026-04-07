import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/search_results_filter/search_results_filter.dart';
import 'package:openvine/screens/search_results/widgets/search_filter_sheet.dart';

/// Green pill button that shows the active search filter label.
///
/// Tapping it opens [SearchFilterSheet] so the user can pick a different
/// category.
class SearchFilterPill extends StatelessWidget {
  const SearchFilterPill({super.key});

  @override
  Widget build(BuildContext context) {
    final filter = context.select(
      (SearchResultsFilterCubit cubit) => cubit.state,
    );

    return Semantics(
      label: 'Filter: ${filter.label}',
      button: true,
      child: GestureDetector(
        onTap: () => SearchFilterSheet.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: VineTheme.vineGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Text(
                filter.label,
                style: VineTheme.titleSmallFont(color: VineTheme.onPrimary),
              ),
              const DivineIcon(
                icon: DivineIconName.caretDown,
                color: VineTheme.onPrimary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
