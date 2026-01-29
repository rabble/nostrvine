// ABOUTME: Top toolbar for the video editor with navigation and history controls.
// ABOUTME: Contains close, undo, redo, and done buttons with BLoC integration.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Top action bar for the video editor.
///
/// Displays close, undo, redo, and done buttons. Uses [BlocSelector] to
/// reactively enable/disable undo and redo based on editor state.
class VideoEditorMainTopBar extends StatelessWidget {
  const VideoEditorMainTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child:
              BlocSelector<
                VideoEditorMainBloc,
                VideoEditorMainState,
                ({bool canUndo, bool canRedo})
              >(
                selector: (state) =>
                    (canUndo: state.canUndo, canRedo: state.canRedo),
                builder: (context, state) {
                  final scope = VideoEditorScope.of(context);

                  return Row(
                    spacing: 8,
                    children: [
                      _IconButton(
                        semanticsLabel: 'Close',
                        iconPath: 'assets/icon/CaretLeft.svg',
                        onTap: () {
                          final bloc = context.read<VideoEditorMainBloc>();
                          if (bloc.state.isSubEditorOpen) {
                            scope.editor?.closeSubEditor();
                          } else {
                            context.pop();
                          }
                        },
                      ),
                      const Spacer(),
                      _IconButton(
                        semanticsLabel: 'Undo',
                        iconPath: 'assets/icon/arrow_arc_left.svg',
                        onTap: state.canUndo
                            ? () => scope.editor?.undoAction()
                            : null,
                      ),
                      _IconButton(
                        semanticsLabel: 'Redo',
                        iconPath: 'assets/icon/arrow_arc_right.svg',
                        onTap: state.canRedo
                            ? () => scope.editor?.redoAction()
                            : null,
                      ),
                      const Spacer(),
                      // TODO(@hm21): replace with done button.
                      _IconButton(
                        semanticsLabel: 'Done',
                        iconPath: 'assets/icon/Check.svg',
                        onTap: () => scope.editor?.doneEditing(),
                      ),
                    ],
                  );
                },
              ),
        ),
      ),
    );
  }
}

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
