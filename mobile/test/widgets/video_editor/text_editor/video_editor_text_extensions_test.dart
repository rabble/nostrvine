// ABOUTME: Unit tests for text editor extensions.
// ABOUTME: Verifies icon mapping for text alignment and background modes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_extensions.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  group('TextEditorTextAlign', () {
    test('maps text alignment to expected icon', () {
      expect(TextAlign.left.icon, equals(DivineIconName.textAlignLeft));
      expect(TextAlign.start.icon, equals(DivineIconName.textAlignLeft));
      expect(TextAlign.right.icon, equals(DivineIconName.textAlignRight));
      expect(TextAlign.end.icon, equals(DivineIconName.textAlignRight));
      expect(TextAlign.center.icon, equals(DivineIconName.textAlignCenter));
      expect(TextAlign.justify.icon, equals(DivineIconName.textAlignCenter));
    });
  });

  group('TextEditorBackgroundMode', () {
    test('maps background mode to expected icon', () {
      expect(
        LayerBackgroundMode.onlyColor.icon,
        equals(DivineIconName.textBgNone),
      );
      expect(
        LayerBackgroundMode.backgroundAndColor.icon,
        equals(DivineIconName.textBgFill),
      );
      expect(
        LayerBackgroundMode.background.icon,
        equals(DivineIconName.textBgFill),
      );
      expect(
        LayerBackgroundMode.backgroundAndColorWithOpacity.icon,
        equals(DivineIconName.textBgTransparent),
      );
    });
  });
}
