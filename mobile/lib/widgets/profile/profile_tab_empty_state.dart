// ABOUTME: Shared empty state widget for profile tab grids
// ABOUTME: Eliminates duplication across videos, liked, reposts, collabs,
// ABOUTME: and comments grids

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Reusable empty state displayed inside a profile tab when there is no
/// content to show.
///
/// Wraps content in a [CustomScrollView] with [SliverFillRemaining] so it
/// participates correctly in the [NestedScrollView] scroll physics.
class ProfileTabEmptyState extends StatelessWidget {
  const ProfileTabEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = VineTheme.lightText,
    this.subtitleColor = VineTheme.lightText,
    this.onRefresh,
    super.key,
  });

  /// The large icon displayed above the title.
  final DivineIconName icon;

  /// Color of the [icon]. Defaults to [VineTheme.lightText].
  final Color iconColor;

  /// Heading text (e.g. "No Videos Yet").
  final String title;

  /// Descriptive text shown below the title.
  final String subtitle;

  /// Color of the [subtitle]. Defaults to [VineTheme.lightText].
  final Color subtitleColor;

  /// Optional callback shown as a refresh button below the subtitle.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const .symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: .center,
              mainAxisSize: .min,
              children: [
                DivineIcon(icon: icon, color: iconColor, size: 40),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: .center,
                  style: VineTheme.titleMediumFont(),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: .center,
                  style: VineTheme.bodyMediumFont(color: subtitleColor),
                ),
                if (onRefresh != null) ...[
                  const SizedBox(height: 32),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const DivineIcon(
                      icon: DivineIconName.arrowClockwise,
                      color: VineTheme.primary,
                      size: 28,
                    ),
                    tooltip: 'Refresh',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
