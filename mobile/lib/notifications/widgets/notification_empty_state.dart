// ABOUTME: Empty state widget shown when there are no notifications.
// ABOUTME: Displays a centered icon, title, and descriptive message.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Centered empty state for the notifications list.
///
/// Shown when the user has no notifications yet.
class NotificationEmptyState extends StatelessWidget {
  /// Creates a notification empty state widget.
  const NotificationEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DivineIcon(
              icon: DivineIconName.bellSimple,
              size: 48,
              color: VineTheme.lightText,
            ),
            const SizedBox(height: 16),
            Text('No activity yet', style: VineTheme.titleMediumFont()),
            const SizedBox(height: 8),
            Text(
              "When people interact with your content, you'll see it here",
              style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
