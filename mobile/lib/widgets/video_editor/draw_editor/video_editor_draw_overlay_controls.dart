// ABOUTME: Top overlay controls for the draw editor screen.
// ABOUTME: Displays close, undo, redo, and done buttons with accessibility.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
                    DivineIconButton(
                      // TODO(l10n): Replace with context.l10n when localization is added.
                      semanticLabel: 'Close',
                      icon: .x,
                      type: .ghostSecondary,
                      onPressed: () => scope.editor?.closeSubEditor(),
                    ),
                    const Spacer(),
                    DivineIconButton(
                      icon: .arrowArcLeft,
                      // TODO(l10n): Replace with context.l10n when localization is added.
                      semanticLabel: 'Undo',
                      size: .small,
                      type: .ghostSecondary,
                      onPressed: state.canUndo
                          ? () => scope.paintEditor?.undoAction()
                          : null,
                    ),
                    DivineIconButton(
                      icon: .arrowArcRight,
                      // TODO(l10n): Replace with context.l10n when localization is added.
                      semanticLabel: 'Redo',
                      size: .small,
                      type: .ghostSecondary,
                      onPressed: state.canRedo
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
