// ABOUTME: Empty state widget for the inbox Messages tab.
// ABOUTME: Shows centered "No messages yet" with encouraging subtext.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Empty state shown when there are no DM conversations.
///
/// Displays "No messages yet" in bold and "That + button won't bite."
/// as encouraging subtext, matching the Figma design.
class InboxEmptyState extends StatelessWidget {
  const InboxEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Text(
              'No messages yet',
              style: VineTheme.titleMediumFont(color: VineTheme.onSurfaceMuted),
              textAlign: TextAlign.center,
            ),
            Text(
              "That + button won't bite.",
              style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
