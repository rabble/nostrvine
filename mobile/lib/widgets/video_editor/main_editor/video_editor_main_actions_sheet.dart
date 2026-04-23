// ABOUTME: Bottom sheet with sub-editor actions for the video editor.
// ABOUTME: Opened via FAB, provides access to text, draw, effects, and more.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
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
      title: Text(context.l10n.videoEditorAddTitle),
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
          Row(
            spacing: 16,
            mainAxisAlignment: .spaceAround,
            children: [
              Expanded(
                child: _ItemButton(
                  icon: .images,
                  label: context.l10n.videoEditorClipsLabel,
                  semanticLabel: context.l10n.videoEditorOpenClipsSemanticLabel,
                  onTap: () {
                    Navigator.pop(context);
                    scope.onOpenClipsEditor();
                  },
                ),
              ),
              Expanded(
                child: _ItemButton(
                  icon: .waveform,
                  label: context.l10n.videoEditorAudioLabel,
                  semanticLabel: context.l10n.videoEditorOpenAudioSemanticLabel,
                  onTap: () {
                    Navigator.pop(context);
                    scope.onOpenMusicLibrary();
                  },
                ),
              ),
              Expanded(
                child: _ItemButton(
                  icon: .textAa,
                  label: context.l10n.videoEditorTextLabel,
                  semanticLabel: context.l10n.videoEditorOpenTextSemanticLabel,
                  onTap: () {
                    Navigator.pop(context);
                    scope.editor?.openTextEditor();
                  },
                ),
              ),
              Expanded(
                child: _ItemButton(
                  icon: .scribble,
                  label: context.l10n.videoEditorDrawLabel,
                  semanticLabel: context.l10n.videoEditorOpenDrawSemanticLabel,
                  onTap: () {
                    Navigator.pop(context);
                    scope.editor?.openPaintEditor();
                  },
                ),
              ),
              Expanded(
                child: _ItemButton(
                  icon: .fadersHorizontal,
                  label: context.l10n.videoEditorEffectsLabel,
                  semanticLabel:
                      context.l10n.videoEditorOpenEffectsSemanticLabel,
                  onTap: () {
                    Navigator.pop(context);
                    scope.editor?.openFilterEditor();
                  },
                ),
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
    required this.semanticLabel,
  });

  final VoidCallback onTap;
  final DivineIconName icon;
  final String label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      spacing: 8,
      children: [
        Semantics(
          label: semanticLabel,
          button: true,
          child: GestureDetector(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
                maxWidth: 72,
                maxHeight: 72,
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
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
