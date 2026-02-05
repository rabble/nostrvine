// ABOUTME: Extensions for text editor types to provide icons and accessibility names.
// ABOUTME: Used by the text editor style bar and potentially other text editor widgets.

import 'package:flutter/painting.dart';
import 'package:openvine/constants/video_editor_constants.dart';
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
  String get icon => switch (this) {
    TextAlign.left || TextAlign.start => 'assets/icon/text_align_left.svg',
    TextAlign.right || TextAlign.end => 'assets/icon/text_align_right.svg',
    _ => 'assets/icon/text_align_center.svg',
  };

  /// Returns the accessibility name for this alignment.
  // TODO(l10n): Replace with localized strings when localization is added.
  String get accessibilityName => switch (this) {
    TextAlign.left || TextAlign.start => 'Left',
    TextAlign.right || TextAlign.end => 'Right',
    _ => 'Center',
  };
}

/// Extension on [LayerBackgroundMode] for text editor UI purposes.
extension TextEditorBackgroundMode on LayerBackgroundMode {
  /// Returns the icon asset path for this background mode.
  String get icon => switch (this) {
    LayerBackgroundMode.onlyColor => 'assets/icon/square.svg',
    LayerBackgroundMode.backgroundAndColor => 'assets/icon/square_fill.svg',
    LayerBackgroundMode.background => 'assets/icon/square_fill.svg',
    LayerBackgroundMode.backgroundAndColorWithOpacity =>
      'assets/icon/square_duo.svg',
  };

  /// Returns the accessibility name for this background mode.
  // TODO(l10n): Replace with localized strings when localization is added.
  String get accessibilityName => switch (this) {
    LayerBackgroundMode.onlyColor => 'None',
    LayerBackgroundMode.backgroundAndColor => 'Solid',
    LayerBackgroundMode.background => 'Highlight',
    LayerBackgroundMode.backgroundAndColorWithOpacity => 'Transparent',
  };
}
