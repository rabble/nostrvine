// ABOUTME: Reusable empty state widget for library tabs
// ABOUTME: Shows icon, title, subtitle, and optional action button

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/camera_permission_check.dart';

/// Empty state widget for library tabs (clips, drafts).
class EmptyLibraryState extends StatelessWidget {
  /// Creates an empty library state widget.
  const EmptyLibraryState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showRecordButton = true,
    super.key,
  });

  /// Icon to display in the center circle.
  final DivineIconName icon;

  /// Title text (e.g., "No Clips Yet").
  final String title;

  /// Subtitle text describing what will appear here.
  final String subtitle;

  /// Whether to show the "Record a Video" button.
  final bool showRecordButton;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: .center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: VineTheme.cardBackground,
              ),
              child: Center(
                child: DivineIcon(
                  icon: icon,
                  size: 48,
                  color: VineTheme.secondaryText,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(title, style: VineTheme.headlineSmallFont()),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: VineTheme.bodyLargeFont(color: VineTheme.secondaryText),
              textAlign: .center,
            ),
            if (showRecordButton) ...[
              const SizedBox(height: 32),
              DivineButton(
                label: context.l10n.libraryRecordVideo,
                leadingIcon: .videoCamera,
                type: .secondary,
                onPressed: () => context.pushToCameraWithPermission(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
