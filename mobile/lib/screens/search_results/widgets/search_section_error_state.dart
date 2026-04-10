import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Shared error state for search result sections.
///
/// Displays a warning icon, "Something went wrong" message, and a
/// "Try again" button that calls [onRetry].
class SearchSectionErrorState extends StatelessWidget {
  const SearchSectionErrorState({required this.onRetry, super.key});

  /// Called when the user taps "Try again".
  final VoidCallback onRetry;

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
              icon: DivineIconName.warningCircle,
              color: VineTheme.secondaryText,
              size: 48,
            ),
            Text('Something went wrong', style: VineTheme.titleSmallFont()),
            DivineButton(
              type: DivineButtonType.secondary,
              size: DivineButtonSize.small,
              label: 'Try again',
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
