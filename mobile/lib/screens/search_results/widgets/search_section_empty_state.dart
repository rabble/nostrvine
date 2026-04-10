import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

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
              'No results found for "$query"',
              style: VineTheme.titleSmallFont(),
              textAlign: TextAlign.center,
            ),
            Text(
              'Try a different search term',
              style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
