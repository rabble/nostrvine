// ABOUTME: Bottom sheet with sub-editor actions for the video editor.
// ABOUTME: Opened via FAB, provides access to text, draw, effects, and more.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Bottom sheet that shows video editor sub-editor actions.
///
/// Uses [DivineIconButton] for each action and closes the sheet after
/// an action is selected.
class VideoEditorMainActionsSheet extends StatelessWidget {
  const VideoEditorMainActionsSheet({
    required this.scope,
    super.key,
  });

  /// The editor scope captured before opening the sheet.
  final VideoEditorScope scope;

  /// Opens the actions bottom sheet.
  static Future<void> show(BuildContext context) {
    final scope = VideoEditorScope.of(context);
    return VineBottomSheet.show(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      // TODO(l10n): Replace with context.l10n when localization is added.
      contentTitle: 'Add',
      children: [VideoEditorMainActionsSheet(scope: scope)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          // TODO(l10n): Replace with context.l10n when localization is added.
          DivineIconButton(
            icon: .images,
            semanticLabel: 'Clips',
            onPressed: () {
              Navigator.pop(context);
              scope.onOpenClipsEditor();
            },
          ),
          // TODO(l10n): Replace with context.l10n when localization is added.
          DivineIconButton(
            icon: .textAa,
            semanticLabel: 'Text',
            onPressed: () {
              Navigator.pop(context);
              scope.editor?.openTextEditor();
            },
          ),
          // TODO(l10n): Replace with context.l10n when localization is added.
          DivineIconButton(
            icon: .scribble,
            semanticLabel: 'Draw',
            onPressed: () {
              Navigator.pop(context);
              scope.editor?.openPaintEditor();
            },
          ),
          /* TODO(hm21): uncomment stickers once we have a license for them
          DivineIconButton(
            icon: .sticker,
            semanticLabel: 'Stickers',
            onPressed: () {
              Navigator.pop(context);
              scope.onAddStickers();
            },
          ),*/
          // TODO(l10n): Replace with context.l10n when localization is added.
          DivineIconButton(
            icon: .speakerHigh,
            semanticLabel: 'Volume',
            onPressed: () {
              Navigator.pop(context);
              scope.onAdjustVolume();
            },
          ),
          // TODO(l10n): Replace with context.l10n when localization is added.
          DivineIconButton(
            icon: .fadersHorizontal,
            semanticLabel: 'Effects',
            onPressed: () {
              Navigator.pop(context);
              scope.editor?.openFilterEditor();
            },
          ),
        ],
      ),
    );
  }
}
