// ABOUTME: Top overlay actions for the video editor with close and done buttons.
// ABOUTME: Hides when the music sub-editor is open.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';

/// Top action bar for the video editor.
///
/// Displays close, undo, redo, audio, and done buttons. Uses [BlocSelector] to
/// reactively enable/disable undo and redo based on editor state.
class VideoEditorMainOverlayActions extends StatelessWidget {
  const VideoEditorMainOverlayActions({super.key});

  @override
  Widget build(BuildContext context) {
    final isHidden = context.select(
      (VideoEditorMainBloc b) => b.state.openSubEditor == .music,
    );

    return IgnorePointer(
      ignoring: isHidden,
      child: AnimatedOpacity(
        opacity: isHidden ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: const Stack(
          fit: .expand,
          children: [
            Align(alignment: .topCenter, child: _TopActions()),
            Align(alignment: .bottomCenter, child: _BottomActions()),
          ],
        ),
      ),
    );
  }
}

/// Top row actions: close, audio chip, and done buttons.
class _TopActions extends StatelessWidget {
  const _TopActions();

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);

    return VideoEditorToolbar(
      closeIcon: .caretLeft,
      doneIcon: .caretRight,
      onClose: () {
        final bloc = context.read<VideoEditorMainBloc>();
        if (bloc.state.isSubEditorOpen) {
          scope.editor?.closeSubEditor();
        } else {
          // If came from library, go to recorder (not in stack)
          // Otherwise pop back to recorder
          context.pop();
        }
      },
      onDone: () => scope.editor?.doneEditing(),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    final isTimelineHiddenByUser = context.select(
      (VideoEditorMainBloc b) => b.state.isTimelineHiddenByUser,
    );

    return Semantics(
      label: isTimelineHiddenByUser ? 'Show timeline' : 'Hide timeline',
      button: true,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 240),
        padding: .only(
          bottom: isTimelineHiddenByUser
              ? MediaQuery.viewPaddingOf(context).bottom + 12
              : 8,
        ),
        child: DivineIconButton(
          icon: isTimelineHiddenByUser ? .caretUp : .caretDown,
          onPressed: () => context.read<VideoEditorMainBloc>().add(
            const VideoEditorTimelineVisibilityToggled(),
          ),
          size: .small,
          type: .ghostSecondary,
        ),
      ),
    );
  }
}
