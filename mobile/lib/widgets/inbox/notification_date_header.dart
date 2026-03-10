// ABOUTME: Date section header for the notification/inbox list.
// ABOUTME: Displays a label like "Today", "Yesterday", or a day name with a
// ABOUTME: divider underneath.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A date section header for the notification list.
///
/// Displays a label (e.g. "Today", "Yesterday", "Tuesday") followed by a thin
/// divider. The first header in a list should set [isFirst] to `true` to use
/// reduced top padding.
class NotificationDateHeader extends StatelessWidget {
  /// Creates a [NotificationDateHeader].
  const NotificationDateHeader({
    required this.label,
    this.isFirst = false,
    super.key,
  });

  /// The date group label (e.g. "Today", "Yesterday", "Tuesday").
  final String label;

  /// Whether this is the first header in the list.
  ///
  /// When `true`, uses 20px top padding; otherwise 24px.
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: isFirst ? 20 : 24,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          child: Text(
            label,
            style: VineTheme.labelLargeFont(color: VineTheme.onSurfaceMuted),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: VineTheme.outlineMuted),
      ],
    );
  }
}
