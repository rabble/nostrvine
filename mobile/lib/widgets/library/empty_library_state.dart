// ABOUTME: Reusable empty state widget for library tabs
// ABOUTME: Shows icon, title, subtitle, and optional action button

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/video_recorder_screen.dart';

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
      child: Column(
        mainAxisAlignment: .center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VineTheme.cardBackground,
              border: .all(color: VineTheme.outlineDisabled, width: 2),
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
          Text(
            title,
            style: VineTheme.headlineSmallFont(),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: VineTheme.bodyLargeFont(color: VineTheme.secondaryText),
            textAlign: .center,
          ),
          if (showRecordButton) ...[
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push(VideoRecorderScreen.path),
              icon: const DivineIcon(
                icon: DivineIconName.videoCamera,
                size: 18,
              ),
              // TODO(l10n): Replace with context.l10n when localization
              // is added.
              label: Text(
                'Record a Video',
                style: VineTheme.labelLargeFont(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.whiteText,
                padding: const .symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: .circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
