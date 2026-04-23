// ABOUTME: Shared error state widget for profile tab grids
// ABOUTME: Eliminates duplication across videos, liked, reposts, collabs,
// ABOUTME: and comments grids

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Reusable error indicator displayed inside a profile tab when loading
/// fails.
///
/// Wraps content in a [CustomScrollView] with [SliverFillRemaining] so it
/// participates correctly in the [NestedScrollView] scroll physics.
class ProfileTabErrorState extends StatelessWidget {
  const ProfileTabErrorState({required this.message, super.key});

  /// Error text shown to the user (e.g. "Error loading liked videos").
  final String message;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    physics: const ClampingScrollPhysics(),
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const .symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: .center,
              mainAxisSize: .min,
              spacing: 16,
              children: [
                const DivineIcon(
                  icon: .warningCircle,
                  color: VineTheme.secondaryText,
                  size: 40,
                ),
                Text(
                  message,
                  textAlign: .center,
                  style: VineTheme.bodyMediumFont(),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
