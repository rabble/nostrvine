// ABOUTME: Bottom toolbar for the video editor with sub-editor buttons.
// ABOUTME: Provides access to text, draw, stickers, effects, and music editors.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Bottom action bar for the video editor.
///
/// Displays buttons to open sub-editors (text, draw, stickers, effects, music)
/// and dispatches [VideoEditorMainOpenSubEditor] events to the BLoC.
class VideoEditorMainBottomBar extends StatelessWidget {
  const VideoEditorMainBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);

    return SizedBox(
      height: VideoEditorConstants.bottomBarHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 32),
              child: Row(
                spacing: 32,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ActionButton(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    label: 'Clips',
                    icon: .images,
                    onTap: scope.onOpenClipsEditor,
                  ),
                  _ActionButton(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    label: 'Text',
                    icon: .textAa,
                    onTap: () => scope.editor?.openTextEditor(),
                  ),
                  _ActionButton(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    label: 'Draw',
                    icon: .scribble,
                    onTap: () => scope.editor?.openPaintEditor(),
                  ),
                  /* TODO(hm21): uncomment stickers once we have a license for them
                  _ActionButton(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    label: 'Stickers',
                    icon: .sticker,
                    onTap: scope.onAddStickers,
                  ),*/
                  _ActionButton(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    label: 'Volume',
                    icon: .speakerHigh,
                    onTap: scope.onAdjustVolume,
                  ),
                  _ActionButton(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    label: 'Effects',
                    icon: .fadersHorizontal,
                    onTap: () => scope.editor?.openFilterEditor(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A styled action button with icon and label for the bottom bar.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  /// The text label displayed below the icon.
  final String label;

  /// The icon displayed above of the text.
  final DivineIconName icon;

  /// Callback when the button is tapped.
  final VoidCallback onTap;

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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VineTheme.surfaceContainer,
                border: .all(width: 2, color: VineTheme.outlineMuted),
                borderRadius: .circular(16),
              ),
              child: DivineIcon(icon: icon, color: VineTheme.primary),
            ),
          ),
        ),
        Text(
          label,
          style: VineTheme.bodySmallFont(),
          textAlign: .center,
        ),
      ],
    );
  }
}
