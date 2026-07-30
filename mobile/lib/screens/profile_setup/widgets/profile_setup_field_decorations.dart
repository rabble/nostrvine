import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Shared underline border for the profile-setup form fields.
/// The fields carry no fill, so the underline sits straight on the screen's
/// `surfaceContainerHigh` background. `outlineMuted` there is #DCE7E2 on
/// #E7E4E1 — 1.00:1, an underline with no edge at all — where the dark value
/// keeps 1.18:1. `outline` restores it.
UnderlineInputBorder profileFieldBorderOf(BuildContext context) {
  final colors = context.vineColors;
  return UnderlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(
      color: colors.isLight ? colors.outline : VineTheme.neutral10,
    ),
  );
}

/// Shared hint text style for the profile-setup form fields.
TextStyle profileFieldHintStyleOf(BuildContext context) =>
    TextStyle(color: context.vineColors.mutedText);
