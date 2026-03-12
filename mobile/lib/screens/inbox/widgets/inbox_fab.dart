// ABOUTME: Floating action button for composing a new DM.
// ABOUTME: Green circular FAB with + icon, matching Figma design.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Green FAB for starting a new conversation.
///
/// 56x56 circle with `primary` background and a `+` icon.
/// Positioned by the parent layout (typically bottom-right).
class InboxFab extends StatelessWidget {
  const InboxFab({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        color: VineTheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: VineTheme.innerShadow,
                  blurRadius: 1,
                  offset: Offset(1, 1),
                ),
                BoxShadow(
                  color: VineTheme.innerShadow,
                  blurRadius: 0.6,
                  offset: Offset(0.4, 0.4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.add,
                size: 32,
                color: VineTheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
