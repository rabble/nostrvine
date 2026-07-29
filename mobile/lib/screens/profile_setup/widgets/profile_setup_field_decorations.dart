import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Shared underline border for the profile-setup form fields.
UnderlineInputBorder profileFieldBorderOf(BuildContext context) {
  final colors = context.vineColors;
  return UnderlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(
      color: colors.isLight ? colors.outlineMuted : VineTheme.neutral10,
    ),
  );
}

/// Shared hint text style for the profile-setup form fields.
TextStyle profileFieldHintStyleOf(BuildContext context) =>
    TextStyle(color: context.vineColors.mutedText);
