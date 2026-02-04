// ABOUTME: Top overlay controls for the draw editor screen.
// ABOUTME: Displays close, undo, redo, and done buttons with accessibility.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Top overlay controls for the draw editor screen.
///
/// Displays close, undo, redo, and done buttons with proper accessibility.
class VideoEditorDrawOverlayControls extends StatelessWidget {
  const VideoEditorDrawOverlayControls({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child:
            BlocSelector<
              VideoEditorDrawBloc,
              VideoEditorDrawState,
              ({bool canUndo, bool canRedo})
            >(
              selector: (state) =>
                  (canUndo: state.canUndo, canRedo: state.canRedo),
              builder: (context, state) {
                return Row(
                  spacing: 8,
                  children: [
                    _IconButton(
                      // TODO(l10n): Replace with context.l10n when localization is added.
                      semanticsLabel: 'Close',
                      iconPath: 'assets/icon/CaretLeft.svg',
                      onTap: () => scope.editor?.closeSubEditor(),
                    ),
                    const Spacer(),
                    _IconButton(
                      // TODO(l10n): Replace with context.l10n when localization is added.
                      semanticsLabel: 'Undo',
                      iconPath: 'assets/icon/arrow_arc_left.svg',
                      onTap: state.canUndo
                          ? () => scope.paintEditor?.undoAction()
                          : null,
                    ),
                    _IconButton(
                      // TODO(l10n): Replace with context.l10n when localization is added.
                      semanticsLabel: 'Redo',
                      iconPath: 'assets/icon/arrow_arc_right.svg',
                      onTap: state.canRedo
                          ? () => scope.paintEditor?.redoAction()
                          : null,
                    ),
                    const Spacer(),
                    // TODO(@hm21): replace with done button.
                    _DoneButton(onTap: () => scope.paintEditor?.done()),
                  ],
                );
              },
            ),
      ),
    );
  }
}

// TODO(@hm21): Once the design decision has been made regarding what the
// buttons will look like, create them in the divine_ui package and reuse them.

/// A styled icon button for the top bar with accessibility support.
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.semanticsLabel,
    required this.iconPath,
    required this.onTap,
  });

  /// Accessibility label for screen readers.
  final String semanticsLabel;

  /// Path to the SVG icon asset.
  final String iconPath;

  /// Callback when tapped, or `null` to disable the button.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: isEnabled,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.32,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const .all(8),
            decoration: BoxDecoration(
              color: const Color(0x25000000),
              borderRadius: .circular(16),
            ),
            child: SizedBox(
              height: 24,
              width: 24,
              child: SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
                colorFilter: const .mode(Colors.white, .srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Done button with white background.
class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Done',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const .symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: .circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(1, 1),
                blurRadius: 1,
              ),
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(0.4, 0.4),
                blurRadius: 0.6,
              ),
            ],
          ),
          child: Text(
            'Done',
            style: VineTheme.titleMediumFont(color: const Color(0xFF00452D)),
          ),
        ),
      ),
    );
  }
}
