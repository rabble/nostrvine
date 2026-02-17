// ABOUTME: Stats row widget for profile page showing loops and likes counts
// ABOUTME: Displays animated stat values with loading states

import 'package:flutter/material.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/string_utils.dart';

/// Individual stat column widget for videos/followers/following counts
class ProfileStatColumn extends StatelessWidget {
  const ProfileStatColumn({
    required this.count,
    required this.label,
    required this.isLoading,
    this.onTap,
    super.key,
  });

  final int? count;
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isLoading
              ? Text(
                  '—',
                  style: VineTheme.titleMediumFont(
                    color: VineTheme.onSurfaceMuted,
                  ),
                )
              : Text(
                  count != null ? StringUtils.formatCompactNumber(count!) : '—',
                  style: VineTheme.titleMediumFont(),
                ),
        ),
        const SizedBox(height: 4),
        Text(label, style: VineTheme.bodyMediumFont()),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: column,
        ),
      );
    }

    return column;
  }
}
