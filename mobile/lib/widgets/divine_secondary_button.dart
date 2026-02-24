// ABOUTME: Shared outlined secondary action button for auth screens
// ABOUTME: Matches Figma design with surfaceContainer bg, outlineMuted border
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=5014-37148

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Outlined secondary action button used across authentication screens.
///
/// Pass [onPressed] as `null` to disable the button.
/// Set [isLoading] to `true` to show a spinner and disable the button.
class DivineSecondaryButton extends StatelessWidget {
  const DivineSecondaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 0.6,
              offset: Offset(0.4, 0.4),
            ),
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 1,
              offset: Offset(1, 1),
            ),
          ],
        ),
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: VineTheme.vineGreen,
            backgroundColor: VineTheme.surfaceContainer,
            side: const BorderSide(color: VineTheme.outlineMuted, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: VineTheme.vineGreen,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontFamily: VineTheme.fontFamilyBricolage,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.15,
                  ),
                ),
        ),
      ),
    );
  }
}
