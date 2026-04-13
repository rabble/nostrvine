// ABOUTME: Extensions for text editor types to provide icons and accessibility names.
// ABOUTME: Used by the text editor style bar and potentially other text editor widgets.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/painting.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Extension on [TextFont] for text editor UI purposes.
extension TextEditorFont on TextFont {
  /// Returns the cleaned display name of this font.
  ///
  /// Removes common suffixes like "_regular" and converts underscores to spaces.
  String get displayName {
    final fontFamily = this().fontFamily;
    if (fontFamily == null) return 'Unknown';
    return fontFamily
        .replaceAll(RegExp(r'_regular$', caseSensitive: false), '')
        .replaceAll('_', ' ');
  }
}

/// Extension on [TextAlign] for text editor UI purposes.
extension TextEditorTextAlign on TextAlign {
  /// Returns the icon asset path for this alignment.
  DivineIconName get icon => switch (this) {
    TextAlign.left || TextAlign.start => .textAlignLeft,
    TextAlign.right || TextAlign.end => .textAlignRight,
    _ => .textAlignCenter,
  };

  /// Returns the localized accessibility name for this alignment.
  String localizedAccessibilityName(AppLocalizations l10n) => switch (this) {
    TextAlign.left || TextAlign.start => l10n.textAlignLeft,
    TextAlign.right || TextAlign.end => l10n.textAlignRight,
    _ => l10n.textAlignCenter,
  };
}

/// Extension on [LayerBackgroundMode] for text editor UI purposes.
extension TextEditorBackgroundMode on LayerBackgroundMode {
  /// Returns the icon asset path for this background mode.
  DivineIconName get icon => switch (this) {
    LayerBackgroundMode.onlyColor => .textBgNone,
    LayerBackgroundMode.backgroundAndColor => .textBgFill,
    LayerBackgroundMode.background => .textBgFill,
    LayerBackgroundMode.backgroundAndColorWithOpacity => .textBgTransparent,
  };

  /// Returns the localized accessibility name for this background mode.
  String localizedAccessibilityName(AppLocalizations l10n) => switch (this) {
    LayerBackgroundMode.onlyColor => l10n.textBackgroundNone,
    LayerBackgroundMode.backgroundAndColor => l10n.textBackgroundSolid,
    LayerBackgroundMode.background => l10n.textBackgroundHighlight,
    LayerBackgroundMode.backgroundAndColorWithOpacity =>
      l10n.textBackgroundTransparent,
  };
}
