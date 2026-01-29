// ABOUTME: Bottom toolbar for the video editor with sub-editor buttons.
// ABOUTME: Provides access to text, draw, stickers, effects, and music editors.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
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

    return Padding(
      padding: const .fromLTRB(16, 0, 16, 4),
      child: Row(
        mainAxisAlignment: .spaceBetween,
        crossAxisAlignment: .end,
        children: [
          _ActionButton(
            // TODO(l10n): Replace with context.l10n when localization is added.
            label: 'Text',
            iconPath: 'assets/icon/text.svg',
            onTap: () => scope.editor?.openTextEditor(),
          ),
          _ActionButton(
            // TODO(l10n): Replace with context.l10n when localization is added.
            label: 'Draw',
            iconPath: 'assets/icon/draw.svg',
            onTap: () => scope.editor?.openPaintEditor(),
          ),
          _ActionButton(
            // TODO(l10n): Replace with context.l10n when localization is added.
            label: 'Stickers',
            iconPath: 'assets/icon/sticker.svg',
            onTap: scope.onAddStickers,
          ),
          _ActionButton(
            // TODO(l10n): Replace with context.l10n when localization is added.
            label: 'Effects',
            iconPath: 'assets/icon/tune.svg',
            onTap: () => scope.editor?.openFilterEditor(),
          ),
          _ActionButton(
            // TODO(l10n): Replace with context.l10n when localization is added.
            label: 'Music',
            iconPath: 'assets/icon/music.svg',
            // TODO(@hm21): Implement music editor
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

/// A styled action button with icon and label for the bottom bar.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.iconPath,
    required this.onTap,
  });

  /// The text label displayed below the icon.
  final String label;

  /// Path to the SVG icon asset.
  final String iconPath;

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
              child: SizedBox(
                height: 24,
                width: 24,
                child: SvgPicture.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
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
