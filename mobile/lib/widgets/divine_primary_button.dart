// ABOUTME: Shared green primary action button for auth screens
// ABOUTME: Matches Figma design with vineGreen background, 20px radius, loading state
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=5014-37147

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Green filled primary action button used across authentication screens.
///
/// Pass [onPressed] as `null` to disable the button without showing a spinner.
/// Set [isLoading] to `true` to show a spinner and disable the button.
class DivinePrimaryButton extends StatelessWidget {
  const DivinePrimaryButton({
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
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.vineGreen,
            foregroundColor: VineTheme.backgroundColor,
            disabledBackgroundColor: VineTheme.vineGreen.withValues(alpha: 0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: VineTheme.backgroundColor,
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
