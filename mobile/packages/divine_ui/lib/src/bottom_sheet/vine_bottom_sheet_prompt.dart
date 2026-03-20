// ABOUTME: Prompt-style bottom sheet with sticker illustration, text, and
// ABOUTME: action buttons. Used for permissions, onboarding, and confirmations.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A prompt-style bottom sheet with a centered sticker illustration, title,
/// subtitle, and up to three optional action buttons
/// (primary, secondary, tertiary).
///
/// Use for permission prompts, onboarding steps, confirmations, or any
/// full-width sheet that follows the "illustration + text + actions" pattern.
///
/// Each button pair (text + callback) must be provided together or both null.
///
/// Can be used as a widget directly (e.g., inside an [Align]) or shown as
/// a modal via [VineBottomSheetPrompt.show].
///
/// Example — as a widget:
/// ```dart
/// VineBottomSheetPrompt(
///   sticker: DivineStickerName.skeletonKey,
///   title: 'Allow camera & microphone access',
///   subtitle: 'This allows you to capture and edit videos.',
///   primaryButtonText: 'Continue',
///   onPrimaryPressed: () => requestPermission(),
///   secondaryButtonText: 'Not now',
///   onSecondaryPressed: () => Navigator.pop(context),
/// )
/// ```
///
/// Example — as a modal:
/// ```dart
/// await VineBottomSheetPrompt.show(
///   context: context,
///   sticker: DivineStickerName.alert,
///   title: 'Something went wrong',
///   subtitle: 'Please try again.',
///   primaryButtonText: 'Retry',
///   onPrimaryPressed: () => retry(),
/// );
/// ```
class VineBottomSheetPrompt extends StatelessWidget {
  /// Creates a [VineBottomSheetPrompt].
  const VineBottomSheetPrompt({
    required this.sticker,
    required this.title,
    required this.subtitle,
    this.additionalText,
    this.primaryButtonText,
    this.onPrimaryPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
    this.tertiaryButtonText,
    this.onTertiaryPressed,
    super.key,
  }) : assert(
         (primaryButtonText == null) == (onPrimaryPressed == null),
         'primaryButtonText and onPrimaryPressed must both be provided '
         'or both be null',
       ),
       assert(
         (secondaryButtonText == null) == (onSecondaryPressed == null),
         'secondaryButtonText and onSecondaryPressed must both be provided '
         'or both be null',
       ),
       assert(
         (tertiaryButtonText == null) == (onTertiaryPressed == null),
         'tertiaryButtonText and onTertiaryPressed must both be provided '
         'or both be null',
       );

  /// The sticker illustration displayed at the top.
  final DivineStickerName sticker;

  /// The headline text below the sticker.
  final String title;

  /// The descriptive text below the title.
  final String subtitle;

  /// Optional additional text shown below the subtitle.
  final String? additionalText;

  /// Optional label for a tertiary text-link button below the secondary button.
  final String? tertiaryButtonText;

  /// Callback for the tertiary text-link button.
  final VoidCallback? onTertiaryPressed;

  /// Optional label for the primary action button.
  final String? primaryButtonText;

  /// Callback for the primary action button.
  final VoidCallback? onPrimaryPressed;

  /// Optional label for the secondary action button.
  final String? secondaryButtonText;

  /// Callback for the secondary action button.
  final VoidCallback? onSecondaryPressed;

  /// Shows the prompt sheet as a fixed modal bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required DivineStickerName sticker,
    required String title,
    required String subtitle,
    String? additionalText,
    String? primaryButtonText,
    VoidCallback? onPrimaryPressed,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
    String? tertiaryButtonText,
    VoidCallback? onTertiaryPressed,
    bool isDismissible = true,
  }) {
    return VineBottomSheet.show<T>(
      context: context,
      scrollable: false,
      showHeaderDivider: false,
      isDismissible: isDismissible,
      body: VineBottomSheetPrompt(
        sticker: sticker,
        title: title,
        subtitle: subtitle,
        additionalText: additionalText,
        primaryButtonText: primaryButtonText,
        onPrimaryPressed: onPrimaryPressed,
        secondaryButtonText: secondaryButtonText,
        onSecondaryPressed: onSecondaryPressed,
        tertiaryButtonText: tertiaryButtonText,
        onTertiaryPressed: onTertiaryPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: .fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: .min,
        children: [
          // Illustration
          DivineSticker(sticker: sticker),

          const SizedBox(height: 32),

          // Title
          Text(title, style: VineTheme.headlineSmallFont(), textAlign: .center),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            subtitle,
            style: VineTheme.bodyLargeFont(
              color: VineTheme.onSurfaceVariant,
            ),
            textAlign: .center,
          ),

          // Optional additional text
          if (additionalText != null)
            Padding(
              padding: const .only(top: 8),
              child: Text(
                additionalText!,
                style: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceVariant,
                ),
                textAlign: .center,
              ),
            ),

          const SizedBox(height: 32),

          // Primary action
          if (primaryButtonText != null)
            DivineButton(
              label: primaryButtonText!,
              onPressed: onPrimaryPressed,
              expanded: true,
            ),

          // Secondary action
          if (secondaryButtonText != null)
            Padding(
              padding: EdgeInsets.only(
                top: primaryButtonText != null ? 16 : 0,
              ),
              child: DivineButton(
                label: secondaryButtonText!,
                onPressed: onSecondaryPressed,
                type: DivineButtonType.secondary,
                expanded: true,
              ),
            ),

          // Optional tertiary text-link action
          if (tertiaryButtonText != null)
            Padding(
              padding: EdgeInsets.only(
                top: primaryButtonText != null || secondaryButtonText != null
                    ? 16
                    : 0,
              ),
              child: DivineButton(
                label: tertiaryButtonText!,
                onPressed: onTertiaryPressed,
                type: DivineButtonType.link,
                expanded: true,
              ),
            ),
        ],
      ),
    );
  }
}
