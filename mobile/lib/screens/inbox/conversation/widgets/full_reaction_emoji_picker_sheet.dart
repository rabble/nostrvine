// ABOUTME: Full emoji picker bottom sheet for DM custom reactions. Wraps
// ABOUTME: pro_image_editor's EmojiEditor in a Divine dark-styled sheet.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Bottom sheet that lets the user pick any emoji as a DM reaction.
///
/// Wraps [EmojiEditor] from `pro_image_editor` — already a direct
/// dependency for the video editor — so the full emoji set is available
/// beyond the six quick reactions, without adding a new picker package.
/// The picked emoji flows through the same [ConversationReactionToggled]
/// path as a quick reaction.
class FullReactionEmojiPickerSheet {
  /// Visible height of the picker body, excluding the keyboard inset.
  static const double _bodyHeight = 320;

  /// Dark-mode editor configuration. Matches the picker grid background to
  /// the surrounding sheet so the surface reads as a single dark panel.
  static const _editorConfigs = ProImageEditorConfigs(
    emojiEditor: EmojiEditorConfigs(
      style: EmojiEditorStyle(
        backgroundColor: VineTheme.surfaceBackground,
      ),
    ),
  );

  /// Shows the picker and resolves to the selected emoji, or `null` if the
  /// sheet was dismissed without a choice.
  static Future<String?> show({required BuildContext context}) async {
    final layer = await showModalBottomSheet<EmojiLayer>(
      context: context,
      backgroundColor: VineTheme.surfaceBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(VineTheme.bottomSheetBorderRadius),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  _bodyHeight + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: const EmojiEditor(configs: _editorConfigs),
          ),
        );
      },
    );
    return layer?.emoji;
  }
}
