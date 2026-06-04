import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

/// Shared empty-results state for search result sections.
///
/// Displays a search icon, a "No results found" message including the
/// [query], and a suggestion to try a different term.
class SearchSectionEmptyState extends StatelessWidget {
  const SearchSectionEmptyState({required this.query, super.key});

  /// The query that returned no results.
  final String query;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            const DivineIcon(
              icon: DivineIconName.search,
              color: VineTheme.secondaryText,
              size: 48,
            ),
            Text(
              context.l10n.searchNoResultsFound(query),
              style: VineTheme.titleSmallFont(),
              textAlign: TextAlign.center,
            ),
            Text(
              context.l10n.soundsNoSoundsFoundDescription,
              style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
