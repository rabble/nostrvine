// ABOUTME: Reusable section wrapper for the metadata expanded sheet.
// ABOUTME: Renders a labeled section with bottom divider matching Figma spec.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A labeled section in the metadata expanded sheet.
///
/// Each section has:
/// - A bottom border in [VineTheme.outlineDisabled]
/// - 16px padding on all sides
/// - A small label in [VineTheme.onSurfaceVariant]
/// - 16px gap between label and content
///
/// Sections conditionally render: pass `null` to [child] or wrap the
/// entire widget in a conditional check to hide sections with no data.
class MetadataSection extends StatelessWidget {
  const MetadataSection({required this.label, required this.child, super.key});

  /// Section header label (e.g. "Creator", "Tags", "Collaborators").
  final String label;

  /// Section content widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VineTheme.outlineDisabled)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Text(
              label,
              style: VineTheme.labelSmallFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
