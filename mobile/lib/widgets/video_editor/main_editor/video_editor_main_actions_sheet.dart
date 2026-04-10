// ABOUTME: Bottom sheet with sub-editor actions for the video editor.
// ABOUTME: Opened via FAB, provides access to text, draw, effects, and more.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Bottom sheet that shows video editor sub-editor actions.
///
/// Uses [_ItemButton] for each action and closes the sheet after
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
      title: const Text('Add'),
      children: [VideoEditorMainActionsSheet(scope: scope)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .all(16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Wrap(
            alignment: .spaceEvenly,
            spacing: 24,
            runSpacing: 24,
            children: [
              // TODO(l10n): Replace with context.l10n when localization is added.
              _ItemButton(
                icon: .images,
                label: 'Clips',
                onTap: () {
                  Navigator.pop(context);
                  scope.onOpenClipsEditor();
                },
              ),
              // TODO(l10n): Replace with context.l10n when localization is added.
              _ItemButton(
                icon: .waveform,
                label: 'Audio',
                onTap: () {
                  Navigator.pop(context);
                  scope.onOpenMusicLibrary();
                },
              ),
              // TODO(l10n): Replace with context.l10n when localization is added.
              _ItemButton(
                icon: .textAa,
                label: 'Text',
                onTap: () {
                  Navigator.pop(context);
                  scope.editor?.openTextEditor();
                },
              ),
              // TODO(l10n): Replace with context.l10n when localization is added.
              _ItemButton(
                icon: .scribble,
                label: 'Draw',
                onTap: () {
                  Navigator.pop(context);
                  scope.editor?.openPaintEditor();
                },
              ),
              // TODO(l10n): Replace with context.l10n when localization is added.
              _ItemButton(
                icon: .fadersHorizontal,
                label: 'Effects',
                onTap: () {
                  Navigator.pop(context);
                  scope.editor?.openFilterEditor();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemButton extends StatelessWidget {
  const _ItemButton({
    required this.onTap,
    required this.icon,
    required this.label,
  });

  final VoidCallback onTap;
  final DivineIconName icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      spacing: 8,
      children: [
        Semantics(
          label: label,
          button: true,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 72,
              height: 72,
              padding: const .all(12),
              decoration: ShapeDecoration(
                color: VineTheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(
                    width: 2,
                    color: VineTheme.outlineMuted,
                  ),
                  borderRadius: .circular(24),
                ),
              ),
              child: Center(
                child: DivineIcon(
                  icon: icon,
                  color: VineTheme.primary,
                ),
              ),
            ),
          ),
        ),
        Semantics(
          excludeSemantics: true,
          child: Text(
            label,
            textAlign: .center,
            style: VineTheme.bodySmallFont(),
          ),
        ),
      ],
    );
  }
}
