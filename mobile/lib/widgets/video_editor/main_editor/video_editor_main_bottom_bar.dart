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
                spacing: 12,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                  _ActionButton(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    label: 'Stickers',
                    icon: .sticker,
                    onTap: scope.onAddStickers,
                  ),
                  _ActionButton(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    label: 'Effects',
                    icon: .fadersHorizontal,
                    onTap: () => scope.editor?.openFilterEditor(),
                  ),
                  _ActionButton(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    label: 'Music',
                    icon: .musicNotesSimple,
                    // TODO(@hm21): Implement music editor
                    onTap: () {},
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
      spacing: 4,
      children: [
        Semantics(
          label: label,
          button: true,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF032017),
                border: .all(width: 2, color: const Color(0xFF0E2B21)),
                borderRadius: .circular(20),
              ),
              child: DivineIcon(
                icon: icon,
                size: 24,
                color: VineTheme.whiteText,
              ),
            ),
          ),
        ),
        Text(
          label,
          style: VineTheme.bodyFont(
            fontSize: 12,
            height: 1.33,
            letterSpacing: 0.4,
          ),
          textAlign: .center,
        ),
      ],
    );
  }
}
